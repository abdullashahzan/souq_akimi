/**
 * Security-rules tests for the cash-on-delivery order flow.
 *
 * The project is on Firebase's Spark (free) plan, which cannot deploy Cloud
 * Functions, so `firestore.rules` is the trust layer: every test below mirrors
 * a write the Flutter client actually performs (`OrderRepository`) and checks
 * that the rules let the honest path through and refuse the dishonest one.
 *
 * Run with:  npm test   (from this directory)
 * which wraps `firebase emulators:exec --only firestore "node --test"`.
 */
import assert from 'node:assert/strict';
import { after, before, beforeEach, describe, it } from 'node:test';
import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';

// Must be plain ESM imports: the harness resolves to its `dist/esm` build,
// which loads `firebase/compat/*` through the `import` condition. Requiring
// the CJS copy instead would hand out a second set of sentinel classes
// (serverTimestamp/increment) that the harness's Firestore rejects.
import firebase from 'firebase/compat/app';
import 'firebase/compat/firestore';

const { FieldValue } = firebase.firestore;

const HERE = dirname(fileURLToPath(import.meta.url));

let env;

/** One Firestore per actor, built once — each context gets its own app. */
let buyerDb;
let seller1Db;
let seller2Db;
let strangerDb;
let anonDb;

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'souqakimi',
    firestore: {
      rules: readFileSync(join(HERE, '..', 'firestore.rules'), 'utf8'),
    },
  });
  buyerDb = env.authenticatedContext('buyer1').firestore();
  seller1Db = env.authenticatedContext('seller1').firestore();
  seller2Db = env.authenticatedContext('seller2').firestore();
  strangerDb = env.authenticatedContext('stranger1').firestore();
  anonDb = env.unauthenticatedContext().firestore();
});

after(async () => {
  await env.cleanup();
});

beforeEach(async () => {
  await env.clearFirestore();
  // The bypass context is destroyed when this callback returns, so fixtures
  // are seeded strictly inside it (assertions use ordinary actors instead).
  await env.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await db.collection('products').doc('lamp').set({
      sellerId: 'seller1',
      sellerUsername: 'seller_one',
      name: 'Desk Lamp',
      description: 'Bright lamp',
      tags: ['lamp'],
      price: 10,
      condition: 'used',
      stock: 5,
      isActive: true,
      images: [],
      coverImage: '',
      viewsCount: 0,
      soldCount: 0,
      searchText: 'desk lamp',
      searchTokens: ['desk', 'lamp'],
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });
    await db.collection('products').doc('kettle').set({
      sellerId: 'seller2',
      sellerUsername: 'seller_two',
      name: 'Kettle',
      description: 'Fast kettle',
      tags: ['kettle'],
      price: 12.5,
      condition: 'new',
      stock: 2,
      isActive: true,
      images: [],
      coverImage: '',
      viewsCount: 0,
      soldCount: 0,
      searchText: 'kettle',
      searchTokens: ['kettle'],
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });
    await db.collection('users').doc('seller1').set({ username: 'seller_one' });
    await db.collection('users').doc('seller2').set({ username: 'seller_two' });
    await db.collection('users').doc('buyer1').set({ username: 'buyer_one' });
  });
});

// --- actors -----------------------------------------------------------------

const buyer = () => buyerDb;
const seller1 = () => seller1Db;
const seller2 = () => seller2Db;
const stranger = () => strangerDb;
const anon = () => anonDb;

// --- helpers (these mirror OrderRepository, field for field) ----------------

/** Places an order exactly as the app does: order + delivery + secret + stock
 *  + the seller's notification, all in ONE transaction. */
async function placeOrder(
  db,
  {
    orderNumber,
    productId = 'lamp',
    quantity = 1,
    code = '123456',
    omitStockWrite = false,
    stockDelta = undefined,
    overrides = {},
    notify = true,
  },
) {
  const deliveryId = `d-${orderNumber}`;
  await db.runTransaction(async (tx) => {
    const productRef = db.collection('products').doc(productId);
    const productSnap = await tx.get(productRef);
    if (!productSnap.exists) throw new Error('missing fixture product');
    const product = productSnap.data();

    const lineTotal = Math.round(product.price * quantity * 100) / 100;
    const orderRef = db.collection('orders').doc(orderNumber);

    tx.set(orderRef, {
      orderNumber,
      userId: 'buyer1',
      fullName: 'Buyer One',
      email: 'buyer@example.com',
      phone: '+10000000001',
      building: 'Br 1',
      roomNumber: '214',
      deliveryNotes: '',
      total: lineTotal,
      status: 'pending',
      items: [
        {
          productId,
          sellerId: product.sellerId,
          sellerUsername: product.sellerUsername,
          productName: product.name,
          quantity,
          price: product.price,
          lineTotal,
        },
      ],
      sellerIds: [product.sellerId],
      createdAt: FieldValue.serverTimestamp(),
      ...overrides,
    });

    const deliveryRef = orderRef.collection('deliveries').doc(deliveryId);
    tx.set(deliveryRef, {
      id: deliveryId,
      sellerId: product.sellerId,
      sellerUsername: product.sellerUsername,
      amount: lineTotal,
      status: 'ready',
      otpAttempts: 0,
      createdAt: FieldValue.serverTimestamp(),
    });

    // The document the seller is never allowed to open.
    tx.set(orderRef.collection('deliverySecrets').doc(deliveryId), {
      deliveryId,
      code,
      createdAt: FieldValue.serverTimestamp(),
    });

    if (notify) {
      const inboxRef = db
        .collection('users')
        .doc(product.sellerId)
        .collection('notifications')
        .doc(`n-${orderNumber}`);
      tx.set(inboxRef, {
        id: `n-${orderNumber}`,
        userId: product.sellerId,
        actorId: 'buyer1',
        actorUsername: 'Buyer One',
        type: 'new_sale',
        title: `New order #${orderNumber}`,
        body: 'Buyer One ordered 1 × Desk Lamp.',
        orderNumber,
        read: false,
        createdAt: FieldValue.serverTimestamp(),
      });
    }

    if (!omitStockWrite) {
      tx.update(productRef, {
        stock: FieldValue.increment(stockDelta ?? -quantity),
        soldCount: FieldValue.increment(quantity),
        updatedAt: FieldValue.serverTimestamp(),
      });
    }
  });
  return deliveryId;
}

/** Seller completes the delivery with the buyer's code, in one transaction
 *  with the order summary update — as `releaseDelivery` does. */
async function capture(db, { orderNumber, deliveryId, code, extra = {} }) {
  const orderRef = db.collection('orders').doc(orderNumber);
  const ids = (await orderRef.collection('deliveries').get()).docs.map(
    (d) => d.id,
  );

  await db.runTransaction(async (tx) => {
    const orderSnap = await tx.get(orderRef);
    const deliveries = [];
    for (const id of ids) {
      const snap = await tx.get(orderRef.collection('deliveries').doc(id));
      if (snap.exists) deliveries.push({ id, ...snap.data() });
    }
    assert.ok(orderSnap.exists);
    const status = deliveries.every((d) =>
      (d.id === deliveryId ? 'delivered' : d.status) === 'delivered',
    )
      ? 'delivered'
      : 'pending';

    tx.update(orderRef.collection('deliveries').doc(deliveryId), {
      status: 'delivered',
      otpEntered: code,
      deliveredAt: FieldValue.serverTimestamp(),
      ...extra,
    });
    tx.update(orderRef, { status });
  });
}

/** Buyer cancels the whole order: legs cancelled, stock restored. */
async function cancel(
  db,
  { orderNumber, productId = 'lamp', quantity = 1 },
) {
  const orderRef = db.collection('orders').doc(orderNumber);
  const ids = (await orderRef.collection('deliveries').get()).docs.map(
    (d) => d.id,
  );

  await db.runTransaction(async (tx) => {
    await tx.get(orderRef);
    const productRef = db.collection('products').doc(productId);
    const productSnap = await tx.get(productRef);
    for (const id of ids) {
      tx.update(orderRef.collection('deliveries').doc(id), {
        status: 'cancelled',
      });
    }
    if (productSnap.exists) {
      tx.update(productRef, {
        stock: FieldValue.increment(quantity),
        updatedAt: FieldValue.serverTimestamp(),
      });
    }
    tx.update(orderRef, { status: 'cancelled' });
  });
}

const productData = async (productId) => {
  const snap = await buyerDb.collection('products').doc(productId).get();
  return snap.exists ? snap.data() : undefined;
};

const stockOf = async (productId) => (await productData(productId))?.stock;
const soldOf = async (productId) => (await productData(productId))?.soldCount;

const orderOf = async (orderNumber) =>
  (await buyerDb.collection('orders').doc(orderNumber).get()).data();

// --- placeOrder -------------------------------------------------------------

describe('placeOrder (order + delivery + secret + stock in one transaction)', () => {
  it('commits the whole cash-on-delivery order', async () => {
    const deliveryId = await placeOrder(buyer(), { orderNumber: 'SQ-T00001' });

    const order = await orderOf('SQ-T00001');
    assert.equal(order.status, 'pending');
    assert.equal(order.total, 10);
    assert.equal(order.sellerIds[0], 'seller1');

    assert.equal(await stockOf('lamp'), 4);
    assert.equal(await soldOf('lamp'), 1);

    const secret = await buyer()
      .collection('orders')
      .doc('SQ-T00001')
      .collection('deliverySecrets')
      .doc(deliveryId)
      .get();
    assert.equal(secret.data().code, '123456');

    const delivery = await buyer()
      .collection('orders')
      .doc('SQ-T00001')
      .collection('deliveries')
      .doc(deliveryId)
      .get();
    assert.equal(delivery.data().status, 'ready');
    assert.equal(delivery.data().otpAttempts, 0);
  });

  it('notifies the seller in the same transaction', async () => {
    await placeOrder(buyer(), { orderNumber: 'SQ-T00002' });
    const inbox = await seller1()
      .collection('users')
      .doc('seller1')
      .collection('notifications')
      .get();
    assert.equal(inbox.size, 1);
    const item = inbox.docs[0].data();
    assert.equal(item.type, 'new_sale');
    assert.equal(item.orderNumber, 'SQ-T00002');
    assert.equal(item.read, false);
  });

  it('refuses an order that does not move stock', async () => {
    await assertFails(
      placeOrder(buyer(), { orderNumber: 'SQ-T00003', omitStockWrite: true }),
    );
    assert.equal(await stockOf('lamp'), 5);
  });

  it('refuses an order whose stock did not move by the quantity', async () => {
    await assertFails(
      placeOrder(buyer(), { orderNumber: 'SQ-T00004', stockDelta: 0 }),
    );
  });

  it('refuses an order placed for somebody else', async () => {
    await assertFails(
      placeOrder(buyer(), {
        orderNumber: 'SQ-T00005',
        overrides: { userId: 'seller1' },
      }),
    );
  });

  it('refuses a total that does not match the line total', async () => {
    await assertFails(
      placeOrder(buyer(), {
        orderNumber: 'SQ-T00006',
        overrides: { total: 1 },
      }),
    );
  });

  it('refuses a seller notification written outside the order transaction', async () => {
    await placeOrder(buyer(), { orderNumber: 'SQ-T00007', notify: false });
    await assertFails(
      buyer()
        .collection('users')
        .doc('seller1')
        .collection('notifications')
        .doc('late')
        .set({
          id: 'late',
          userId: 'seller1',
          actorId: 'buyer1',
          actorUsername: 'Buyer One',
          type: 'new_sale',
          title: 'Late notification',
          body: 'Too late',
          orderNumber: 'SQ-T00007',
          read: false,
          createdAt: FieldValue.serverTimestamp(),
        }),
    );
  });

  it('refuses an anonymous checkout', async () => {
    await assertFails(
      anon().collection('orders').doc('SQ-T00008').set({
        orderNumber: 'SQ-T00008',
        userId: 'buyer1',
        fullName: 'Buyer One',
        email: 'buyer@example.com',
        phone: '+10000000001',
        building: 'Br 1',
        roomNumber: '214',
        deliveryNotes: '',
        total: 10,
        status: 'pending',
        items: [],
        sellerIds: ['seller1'],
        createdAt: FieldValue.serverTimestamp(),
      }),
    );
  });
});

// --- hand-over code ---------------------------------------------------------

describe('hand-over code', () => {
  it('lets the buyer read the secret, but never the seller', async () => {
    const deliveryId = await placeOrder(buyer(), { orderNumber: 'SQ-T00010' });
    const path = buyer()
      .collection('orders')
      .doc('SQ-T00010')
      .collection('deliverySecrets')
      .doc(deliveryId);
    await assertSucceeds(path.get());
    await assertFails(
      seller1()
        .collection('orders')
        .doc('SQ-T00010')
        .collection('deliverySecrets')
        .doc(deliveryId)
        .get(),
    );
  });

  it('completes the delivery when the seller types the right code', async () => {
    const deliveryId = await placeOrder(buyer(), { orderNumber: 'SQ-T00011' });
    await assertSucceeds(
      capture(seller1(), {
        orderNumber: 'SQ-T00011',
        deliveryId,
        code: '123456',
      }),
    );
    const delivery = await seller1()
      .collection('orders')
      .doc('SQ-T00011')
      .collection('deliveries')
      .doc(deliveryId)
      .get();
    assert.equal(delivery.data().status, 'delivered');
    assert.equal((await orderOf('SQ-T00011')).status, 'delivered');
  });

  it('refuses a wrong code and leaves the delivery open', async () => {
    const deliveryId = await placeOrder(buyer(), { orderNumber: 'SQ-T00012' });
    await assertFails(
      capture(seller1(), {
        orderNumber: 'SQ-T00012',
        deliveryId,
        code: '000000',
      }),
    );
    const delivery = await seller1()
      .collection('orders')
      .doc('SQ-T00012')
      .collection('deliveries')
      .doc(deliveryId)
      .get();
    assert.equal(delivery.data().status, 'ready');
    assert.equal((await orderOf('SQ-T00012')).status, 'pending');
  });

  it('refuses a seller completing another seller’s delivery', async () => {
    const deliveryId = await placeOrder(buyer(), { orderNumber: 'SQ-T00013' });
    await assertFails(
      capture(seller2(), {
        orderNumber: 'SQ-T00013',
        deliveryId,
        code: '123456',
      }),
    );
  });

  it('refuses the buyer completing their own delivery', async () => {
    const deliveryId = await placeOrder(buyer(), { orderNumber: 'SQ-T00014' });
    await assertFails(
      capture(buyer(), {
        orderNumber: 'SQ-T00014',
        deliveryId,
        code: '123456',
      }),
    );
  });

  it('counts wrong guesses up to five, then locks the seller out', async () => {
    const deliveryId = await placeOrder(buyer(), { orderNumber: 'SQ-T00015' });
    const ref = seller1()
      .collection('orders')
      .doc('SQ-T00015')
      .collection('deliveries')
      .doc(deliveryId);

    for (let i = 1; i <= 5; i++) {
      await assertSucceeds(ref.update({ otpAttempts: i }));
    }
    await assertFails(ref.update({ otpAttempts: 6 }));
    await assertFails(
      capture(seller1(), {
        orderNumber: 'SQ-T00015',
        deliveryId,
        code: '123456',
      }),
    );
  });

  it('lets the buyer reset the attempts and rotate the code', async () => {
    const deliveryId = await placeOrder(buyer(), { orderNumber: 'SQ-T00016' });
    const deliveryRef = seller1()
      .collection('orders')
      .doc('SQ-T00016')
      .collection('deliveries')
      .doc(deliveryId);
    // Five misses, one increment at a time (the rules refuse a jump).
    for (let i = 1; i <= 5; i++) {
      await assertSucceeds(deliveryRef.update({ otpAttempts: i }));
    }

    const buyerDeliveryRef = buyer()
      .collection('orders')
      .doc('SQ-T00016')
      .collection('deliveries')
      .doc(deliveryId);
    const secretRef = buyer()
      .collection('orders')
      .doc('SQ-T00016')
      .collection('deliverySecrets')
      .doc(deliveryId);

    // What `rotateDeliveryCode` does: fresh code + reset the counter, in one
    // transaction, both owned by the buyer.
    await assertSucceeds(
      buyer().runTransaction(async (tx) => {
        await tx.get(buyer().collection('orders').doc('SQ-T00016'));
        await tx.get(buyerDeliveryRef);
        tx.update(secretRef, { code: '654321' });
        tx.update(buyerDeliveryRef, { otpAttempts: 0 });
      }),
    );

    await assertFails(
      capture(seller1(), {
        orderNumber: 'SQ-T00016',
        deliveryId,
        code: '123456',
      }),
    );
    await assertSucceeds(
      capture(seller1(), {
        orderNumber: 'SQ-T00016',
        deliveryId,
        code: '654321',
      }),
    );
  });

  it('refuses a stranger resetting the attempts', async () => {
    const deliveryId = await placeOrder(buyer(), { orderNumber: 'SQ-T00017' });
    await assertFails(
      stranger()
        .collection('orders')
        .doc('SQ-T00017')
        .collection('deliveries')
        .doc(deliveryId)
        .update({ otpAttempts: 0 }),
    );
  });
});

// --- cancellation -----------------------------------------------------------

describe('cancelling an order', () => {
  it('lets the buyer cancel and restocks every line', async () => {
    await placeOrder(buyer(), { orderNumber: 'SQ-T00020', quantity: 2 });
    assert.equal(await stockOf('lamp'), 3);

    await assertSucceeds(
      cancel(buyer(), { orderNumber: 'SQ-T00020', quantity: 2 }),
    );

    assert.equal(await stockOf('lamp'), 5);
    assert.equal((await orderOf('SQ-T00020')).status, 'cancelled');
    const legs = await buyer()
      .collection('orders')
      .doc('SQ-T00020')
      .collection('deliveries')
      .get();
    assert.equal(legs.docs[0].data().status, 'cancelled');
  });

  it('refuses the seller cancelling the buyer’s order', async () => {
    await placeOrder(buyer(), { orderNumber: 'SQ-T00021' });
    await assertFails(
      cancel(seller1(), { orderNumber: 'SQ-T00021' }),
    );
  });

  it('refuses cancelling after the delivery was completed', async () => {
    const deliveryId = await placeOrder(buyer(), { orderNumber: 'SQ-T00022' });
    await capture(seller1(), {
      orderNumber: 'SQ-T00022',
      deliveryId,
      code: '123456',
    });
    await assertFails(
      cancel(buyer(), { orderNumber: 'SQ-T00022' }),
    );
  });

  it('refuses cancelling twice', async () => {
    await placeOrder(buyer(), { orderNumber: 'SQ-T00023' });
    await assertSucceeds(cancel(buyer(), { orderNumber: 'SQ-T00023' }));
    await assertFails(cancel(buyer(), { orderNumber: 'SQ-T00023' }));
  });
});

// --- reading orders ---------------------------------------------------------

describe('reading orders', () => {
  it('lets participants read and hides everything from strangers', async () => {
    await placeOrder(buyer(), { orderNumber: 'SQ-T00030' });

    await assertSucceeds(
      buyer().collection('orders').doc('SQ-T00030').get(),
    );
    await assertSucceeds(
      seller1().collection('orders').doc('SQ-T00030').get(),
    );
    await assertFails(
      stranger().collection('orders').doc('SQ-T00030').get(),
    );
    await assertFails(
      anon().collection('orders').doc('SQ-T00030').get(),
    );
  });

  it('lets checkout probe an unused order id', async () => {
    await assertSucceeds(
      buyer().collection('orders').doc('SQ-FREE01').get(),
    );
  });

  it('scopes order lists to the caller', async () => {
    await placeOrder(buyer(), { orderNumber: 'SQ-T00031' });
    await placeOrder(buyer(), { orderNumber: 'SQ-T00032' });

    const mine = await buyer()
      .collection('orders')
      .where('userId', '==', 'buyer1')
      .get();
    assert.equal(mine.size, 2);

    const sales = await seller1()
      .collection('orders')
      .where('sellerIds', 'array-contains', 'seller1')
      .get();
    assert.equal(sales.size, 2);

    await assertFails(
      stranger()
        .collection('orders')
        .where('userId', '==', 'buyer1')
        .get(),
    );
  });
});

// --- notifications ----------------------------------------------------------

describe('notifications', () => {
  it('lets the seller read, count and mark their inbox read', async () => {
    await placeOrder(buyer(), { orderNumber: 'SQ-T00040' });
    const inbox = seller1()
      .collection('users')
      .doc('seller1')
      .collection('notifications');

    const snap = await assertSucceeds(inbox.get());
    assert.equal(snap.size, 1);

    await assertSucceeds(
      inbox.doc('n-SQ-T00040').update({ read: true }),
    );
    assert.equal((await inbox.doc('n-SQ-T00040').get()).data().read, true);
  });

  it('keeps the inbox private', async () => {
    await placeOrder(buyer(), { orderNumber: 'SQ-T00041' });
    await assertFails(
      buyer().collection('users').doc('seller1').collection('notifications').get(),
    );
    await assertFails(
      stranger().collection('users').doc('seller1').collection('notifications').get(),
    );
  });

  it('refuses editing anything but the read flag', async () => {
    await placeOrder(buyer(), { orderNumber: 'SQ-T00042' });
    const ref = seller1()
      .collection('users')
      .doc('seller1')
      .collection('notifications')
      .doc('n-SQ-T00042');
    await assertFails(ref.update({ title: 'Changed' }));
    await assertFails(ref.update({ read: false }));
  });

  it('refuses a notification created for an unrelated order', async () => {
    await placeOrder(buyer(), { orderNumber: 'SQ-T00043', notify: false });
    await assertFails(
      seller2()
        .collection('users')
        .doc('seller2')
        .collection('notifications')
        .doc('fake')
        .set({
          id: 'fake',
          userId: 'seller2',
          actorId: 'buyer1',
          actorUsername: 'Buyer One',
          type: 'new_sale',
          title: 'Fake',
          body: 'Fake',
          orderNumber: 'SQ-T00043',
          read: false,
          createdAt: FieldValue.serverTimestamp(),
        }),
    );
  });
});

// --- product counters -------------------------------------------------------

describe('product stock counters', () => {
  it('lets a sale move stock and soldCount together', async () => {
    await assertSucceeds(
      buyer()
        .collection('products')
        .doc('lamp')
        .update({
          stock: FieldValue.increment(-1),
          soldCount: FieldValue.increment(1),
          updatedAt: FieldValue.serverTimestamp(),
        }),
    );
    assert.equal(await stockOf('lamp'), 4);
  });

  it('lets a cancellation restock without touching soldCount', async () => {
    await placeOrder(buyer(), { orderNumber: 'SQ-T00050' });
    await assertSucceeds(
      buyer()
        .collection('products')
        .doc('lamp')
        .update({
          stock: FieldValue.increment(1),
          updatedAt: FieldValue.serverTimestamp(),
        }),
    );
    assert.equal(await stockOf('lamp'), 5);
    assert.equal(await soldOf('lamp'), 1);
  });

  it('refuses a stranger repricing the listing', async () => {
    await assertFails(
      stranger()
        .collection('products')
        .doc('lamp')
        .update({ price: 1 }),
    );
  });

  it('lets the owner edit their listing', async () => {
    await assertSucceeds(
      seller1().collection('products').doc('lamp').update({ price: 11 }),
    );
  });
});

// --- service requests, sales tallies and admin moderation ------------------

describe('service requests and notifications', () => {
  beforeEach(async () => {
    await env.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();
      await db.collection('services').doc('printing').set({
        providerId: 'seller1',
        providerUsername: 'seller_one',
        title: 'Printouts',
        category: 'printing',
        description: 'Colour printing',
        tags: ['print'],
        price: 1,
        priceType: 'page',
        images: [],
        coverImage: '',
        isActive: true,
        viewsCount: 0,
        searchText: 'printouts',
        searchTokens: ['printouts'],
        createdAt: FieldValue.serverTimestamp(),
      });
    });
  });

  it('creates the brief and the provider inbox entry together', async () => {
    const requestId = 'req1';
    const inboxId = 'note1';
    await assertSucceeds(
      buyer().runTransaction(async (tx) => {
        const stamp = FieldValue.serverTimestamp();
        tx.set(buyer().collection('serviceRequests').doc(requestId), {
          serviceId: 'printing',
          serviceTitle: 'Printouts',
          providerId: 'seller1',
          providerUsername: 'seller_one',
          requesterId: 'buyer1',
          requesterUsername: 'buyer_one',
          message: 'Please print 20 pages in colour.',
          phone: '0500000000',
          building: 'br1',
          roomNumber: '214',
          status: 'pending',
          createdAt: stamp,
        });
        tx.set(
          buyer().collection('users').doc('seller1')
            .collection('notifications').doc(inboxId),
          {
            id: inboxId,
            userId: 'seller1',
            actorId: 'buyer1',
            actorUsername: 'buyer_one',
            type: 'service_request',
            title: 'New service request',
            body: 'buyer_one requested "Printouts".',
            orderNumber: '',
            requestId,
            read: false,
            createdAt: stamp,
          },
        );
      }),
    );
    await assertSucceeds(
      seller1().collection('serviceRequests').doc(requestId).get(),
    );
    await assertSucceeds(
      seller1().collection('users').doc('seller1')
        .collection('notifications').doc(inboxId).get(),
    );
    await assertFails(
      stranger().collection('serviceRequests').doc(requestId).get(),
    );
  });

  it('refuses a brief without contact details', async () => {
    await assertFails(
      buyer().collection('serviceRequests').doc('req-bad').set({
        serviceId: 'printing',
        serviceTitle: 'Printouts',
        providerId: 'seller1',
        providerUsername: 'seller_one',
        requesterId: 'buyer1',
        requesterUsername: 'buyer_one',
        message: 'Please print these.',
        phone: '',
        building: '',
        roomNumber: '',
        status: 'pending',
        createdAt: FieldValue.serverTimestamp(),
      }),
    );
  });

  const draft = () => ({
    serviceId: 'printing', serviceTitle: 'Printouts',
    providerId: 'seller1', providerUsername: 'seller_one',
    requesterId: 'buyer1', requesterUsername: 'buyer_one',
    message: 'Please print my notes.', phone: '0500000000',
    building: 'br10', roomNumber: '101', status: 'pending',
    createdAt: FieldValue.serverTimestamp(),
  });

  async function transition(db, status, actor = 'seller1', recipient = 'buyer1') {
    const batch = db.batch();
    batch.update(db.collection('serviceRequests').doc('transition'), {
      status, respondedAt: FieldValue.serverTimestamp(),
    });
    batch.set(db.collection('users').doc(recipient).collection('notifications').doc(`transition_${status}`), {
      id: `transition_${status}`, userId: recipient, actorId: actor,
      actorUsername: actor, type: `request_${status}`, title: 'Request updated',
      body: 'Printouts', orderNumber: '', requestId: 'transition', read: false,
      createdAt: FieldValue.serverTimestamp(),
    });
    return batch.commit();
  }

  for (const status of ['accepted', 'declined']) {
    it(`notifies the requester atomically when the provider ${status}`, async () => {
      await assertSucceeds(buyer().collection('serviceRequests').doc('transition').set(draft()));
      await assertSucceeds(transition(seller1(), status));
      await assertSucceeds(buyer().collection('users').doc('buyer1').collection('notifications').doc(`transition_${status}`).get());
      await assertFails(transition(seller1(), status));
    });
  }

  it('notifies the provider when the requester cancels', async () => {
    await assertSucceeds(buyer().collection('serviceRequests').doc('transition').set(draft()));
    await assertSucceeds(transition(buyer(), 'cancelled', 'buyer1', 'seller1'));
  });

  it('lets only the provider finish accepted work and notifies the requester', async () => {
    await assertSucceeds(buyer().collection('serviceRequests').doc('transition').set(draft()));
    await assertFails(transition(seller1(), 'completed'));
    await assertSucceeds(transition(seller1(), 'accepted'));
    await assertFails(transition(buyer(), 'completed', 'buyer1'));
    await assertSucceeds(transition(seller1(), 'completed'));
    await assertFails(transition(seller1(), 'completed'));
  });

  it('rejects spoofed recipients, actors and repeated terminal transitions', async () => {
    await assertSucceeds(buyer().collection('serviceRequests').doc('transition').set(draft()));
    await assertFails(transition(stranger(), 'accepted', 'stranger'));
    await assertFails(transition(seller1(), 'accepted', 'seller1', 'stranger'));
    await assertFails(transition(buyer(), 'accepted', 'buyer1'));
    await assertSucceeds(transition(seller1(), 'accepted'));
    await assertFails(transition(seller1(), 'declined'));
    await assertFails(transition(buyer(), 'cancelled', 'buyer1', 'seller1'));
  });

  it('does not notify from an unrelated update or replay an old response', async () => {
    await assertSucceeds(buyer().collection('serviceRequests').doc('transition').set(draft()));
    await assertFails(seller1().collection('users').doc('buyer1').collection('notifications').doc('transition_accepted').set({
      id: 'transition_accepted', userId: 'buyer1', actorId: 'seller1',
      actorUsername: 'seller_one', type: 'request_accepted', title: 'Accepted',
      body: 'Printouts', orderNumber: '', requestId: 'transition', read: false,
      createdAt: FieldValue.serverTimestamp(),
    }));
  });

  it('cannot request a removed, inactive, mismatched or own service', async () => {
    await assertFails(buyer().collection('serviceRequests').doc('missing').set({...draft(), serviceId: 'missing'}));
    await assertFails(buyer().collection('serviceRequests').doc('mismatch').set({...draft(), providerId: 'stranger'}));
    await assertFails(seller1().collection('serviceRequests').doc('own').set({...draft(), requesterId: 'seller1'}));
    await assertSucceeds(seller1().collection('services').doc('printing').update({isActive: false}));
    await assertFails(buyer().collection('serviceRequests').doc('inactive').set(draft()));
  });
});

describe('seller sales tally', () => {
  beforeEach(async () => {
    await env.withSecurityRulesDisabled(async (context) => {
      await context.firestore().collection('users').doc('seller1').set({
        uid: 'seller1',
        username: 'seller_one',
        email: 'seller1@example.com',
        displayName: 'Seller One',
        photoUrl: '',
        phone: '',
        building: '',
        roomNumber: '',
        salesCount: 2,
        updatedAt: FieldValue.serverTimestamp(),
      });
    });
  });

  it('allows the delivery path to add exactly one sale', async () => {
    await assertSucceeds(
      seller1().collection('users').doc('seller1').set(
        {
          salesCount: FieldValue.increment(1),
          updatedAt: FieldValue.serverTimestamp(),
        },
        { merge: true },
      ),
    );
  });

  it('refuses a seller inflating the tally or editing their email', async () => {
    await assertFails(
      seller1().collection('users').doc('seller1').set(
        { salesCount: FieldValue.increment(100) },
        { merge: true },
      ),
    );
    await assertFails(
      seller1().collection('users').doc('seller1').set(
        { email: 'someone-else@example.com' },
        { merge: true },
      ),
    );
  });
});

describe('admin dashboard', () => {
  it('lets the verified admin broadcast and moderate, and nobody else', async () => {
    const admin = env
      .authenticatedContext('admin1', {
        email: 'abdullashahzan@gmail.com',
        email_verified: true,
      })
      .firestore();
    const almost = env
      .authenticatedContext('notadmin', {
        email: 'abdullashahzan@gmail.com',
        email_verified: false,
      })
      .firestore();

    await assertSucceeds(
      admin.collection('users').doc('seller1')
        .collection('notifications').doc('broadcast1').set({
          id: 'broadcast1',
          userId: 'seller1',
          actorId: 'admin1',
          actorUsername: 'Souq Akimi',
          type: 'announcement',
          title: 'Campus update',
          body: 'The souq is open late tonight.',
          orderNumber: '',
          requestId: '',
          read: false,
          createdAt: FieldValue.serverTimestamp(),
        }),
    );
    await assertFails(
      almost.collection('users').doc('seller1')
        .collection('notifications').doc('broadcast2').set({
          id: 'broadcast2',
          userId: 'seller1',
          actorId: 'notadmin',
          actorUsername: 'Not admin',
          type: 'announcement',
          title: 'Fake update',
          body: 'This should not land.',
          orderNumber: '',
          requestId: '',
          read: false,
          createdAt: FieldValue.serverTimestamp(),
        }),
    );
    await assertSucceeds(admin.collection('products').doc('kettle').delete());
    await assertFails(stranger().collection('products').doc('lamp').delete());
  });
});
