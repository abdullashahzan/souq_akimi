# Firestore schema and security model

Souq Akimi runs on Firebase **Spark (free)**: Authentication + Firestore only.
There is no Cloud Storage and no Cloud Functions. Every write is a client
transaction, and `firestore.rules` decides whether it may commit.

This document is the reference for the collections, the fields that matter, the
allowed transitions, the indexes, and the threat model.

## Public-release changes (supersede the historical contracts below)

- `users/{uid}` is private to its owner and administrator. Seller reads now use
  `publicProfiles/{uid}` with **only** `username` and `salesCount`; no contacts.
- Buyer stock writes carry `lastOrderId` and prove either a new order or a
  pending → cancelled transition. The quantity and price match the real product.
  Orders require matching delivery, secret and seller-notification documents.
  Delivery IDs now equal the single seller UID, preventing additional legs.
- Each guess is stored as `pendingCode` while incrementing `otpAttempts` in a
  separate committed write **before** code comparison. Finalization can only
  compare that stored guess. A modified client cannot submit unlimited new codes
  without consuming attempts. Five guesses are allowed. Buyer rotation clears
  the guess/counter and changes the secret atomically.
- A private sales-tally update includes `salesOrderId` and `salesDeliveryId`,
  proving a ready → delivered leg in the same transaction. Public profiles may
  mirror but not invent the private tally. Order summaries must match the leg.
- Public release AI is disabled and no shared AI credential is compiled. Demo
  seeders/assets and live demo records are removed. Automated fixtures remain.

The older descriptions below document the evolution of the app, not exceptions
to these tightened rules. See [release guide](releases.md) and the executable
rule tests for the current contract. Old development clients must upgrade.

---

## Principles

1. **One transaction, one order.** An order, its delivery legs, their hand-over
   secrets, the sellers' notifications and the stock decrement are written
   together. The rules read the siblings with `getAfter()`, so a partial write
   cannot exist.
2. **The rules are the server.** Without Cloud Functions, the only trustworthy
   place to enforce "only the right person may do this" is the rules file. The
   Dart repositories are a convenience layer, not a security boundary.
3. **Cash on delivery.** The app never holds money. There is no escrow,
   `paymentStatus`, capture, refund or auto-release timer.
4. **Always delivered.** Every order goes to the buyer's hostel room. There is
   no pickup option and no fulfilment field.
5. **Cheap by default.** The home screen streams a small window; the wide
   catalogue is only loaded when search is opened. See *Quota* below.

---

## Collections

### `users/{uid}`

The single per-user document, created on first sign-in.

| Field | Type | Notes |
| --- | --- | --- |
| `uid` | string | Same as the document id |
| `username` | string | Unique-ish handle, shown as `@name` |
| `email` | string | Auth email snapshot |
| `displayName` | string | Buyer/seller name; checkout can update it |
| `photoUrl` | string | Unused today; kept for a future avatar picker |
| `phone` | string | Remembered delivery detail |
| `building` | string | One of `Br 1` … `Br 10` |
| `roomNumber` | string | Remembered delivery detail |
| `onboardingCompleted` | bool | Optional, defaults false; authenticated welcome completion |
| `createdAt` | timestamp | Server time |
| `updatedAt` | timestamp | Server time |

Readable by any signed-in student (so seller names resolve); writable only by
the owner.

#### `users/{uid}/notifications/{notificationId}`

The private in-app inbox. The only writer is a *different* user's checkout
transaction, and only for a `new_sale` tied to the order it just created.

| Field | Type | Notes |
| --- | --- | --- |
| `id` | string | Document id |
| `userId` | string | Recipient; must equal the inbox owner |
| `actorId` | string | Buyer uid |
| `actorUsername` | string | Buyer display name at purchase time |
| `type` | string | `new_sale` (extensible) |
| `title` | string | e.g. `New order #SQ-9SQRQ5` |
| `body` | string | Buyer, item summary and delivery address |
| `orderNumber` | string | Deep-link target |
| `read` | boolean | Starts `false`; the owner may only flip it to `true` |
| `createdAt` | timestamp | Must equal `request.time` of the order creation |

Rules: read/delete by the owner; create by a signed-in buyer **only** when
`getAfter(order).userId == request.auth.uid`, the owner is in the order's
`sellerIds`, and both timestamps equal `request.time`. That makes replaying a
notification for an old order impossible.

### `products/{productId}`

| Field | Type | Notes |
| --- | --- | --- |
| `sellerId`, `sellerUsername` | string | Owner |
| `name`, `description` | string | |
| `tags` | list<string> | Free-form |
| `price` | number | USD |
| `condition` | string | `new` \| `used` |
| `stock`, `soldCount` | number | Move together on a sale |
| `isActive` | boolean | Soft delete |
| `images` | list<string> | Firestore image URLs/data refs |
| `coverImage` | string | Optional first image |
| `viewsCount` | number | +1 by any signed-in viewer |
| `createdAt`, `updatedAt` | timestamp | |

Public read. Owner create/update/delete. Non-owners may move only
`stock`/`soldCount`/`updatedAt` (a sale or a restock, bounded to 999) or bump
`viewsCount` by exactly one.

### `services/{serviceId}`

| Field | Type | Notes |
| --- | --- | --- |
| `providerId`, `providerUsername` | string | Owner |
| `title`, `description` | string | |
| `category` | string | See `ServiceCategory` |
| `price`, `priceUnit` | number/string | e.g. `$10 / hour` |
| `isActive` | boolean | |
| `viewsCount` | number | |
| `createdAt`, `updatedAt` | timestamp | |

Same visibility and counter rules as products, keyed on `providerId`.

### `serviceRequests/{requestId}`

| Field | Type | Notes |
| --- | --- | --- |
| `serviceId`, `serviceTitle` | string | Snapshot |
| `requesterId`, `requesterUsername` | string | |
| `providerId` | string | |
| `message` | string | Brief |
| `status` | string | `pending` \| `accepted` \| `declined` \| `cancelled` |
| `createdAt`, `respondedAt` | timestamp | |

Visible to the requester and provider. The provider may set `accepted` /
`declined` (and `respondedAt`); the requester may set `cancelled`. Nothing else
is editable, nothing is deletable.

### `orders/{orderNumber}`

The document id **is** the order number (`SQ-` + six uppercase base36 chars).

| Field | Type | Notes |
| --- | --- | --- |
| `orderNumber` | string | Equals the doc id |
| `userId` | string | Buyer |
| `fullName`, `email`, `phone` | string | Snapshot at checkout |
| `building`, `roomNumber` | string | Required; where the seller delivers |
| `deliveryNotes` | string | Optional |
| `total` | number | Must equal the single line total |
| `status` | string | `pending` \| `delivered` \| `cancelled` |
| `items` | list<map> | `{productId, sellerId, sellerUsername, productName, quantity, price, lineTotal}` |
| `sellerIds` | list<string> | Distinct sellers |
| `createdAt` | timestamp | `request.time` |

Souq is cartless: the app sends one line, and the rules require
`total == items[0].lineTotal` and `sellerIds == [items[0].sellerId]`, with that
product's stock decremented in the same transaction. (`items.size != 1` is
allowed for future multi-line orders but skips the one-line checks.)

Readable by the buyer and by any seller in `sellerIds`; a missing document may
be probed by any signed-in user (checkout allocates a free id). Participants may
update only `status`, to one of the three values, and never after cancellation.
Orders are never deleted.

### `orders/{orderNumber}/deliveries/{deliveryId}`

One leg per seller.

| Field | Type | Notes |
| --- | --- | --- |
| `id` | string | Equals the doc id |
| `sellerId`, `sellerUsername` | string | Owner of this leg |
| `amount` | number | This seller's share |
| `status` | string | `ready` \| `delivered` \| `cancelled` |
| `otpAttempts` | number | 0–5 |
| `otpEntered` | string | Written only by a successful capture |
| `deliveredAt` | timestamp | `request.time` on success |
| `createdAt` | timestamp | Same transaction as the order |

Created only with the order (`orderAfter().createdAt == request.time`), with
`status: ready` and `otpAttempts: 0`. Never deleted.

### `orders/{orderNumber}/deliverySecrets/{deliveryId}`

The hand-over code. Only the buyer may read it.

| Field | Type | Notes |
| --- | --- | --- |
| `deliveryId` | string | Equals the doc id |
| `code` | string | `^[0-9]{6}$` |
| `createdAt` | timestamp | |

The seller can never read this document. The delivery-capture rule compares the
seller's typed `otpEntered` against `secret().data.code` inside the rules engine.

### `images/{imageId}`

Listing photos stored in Firestore because Storage is unavailable on Spark.

| Field | Type | Notes |
| --- | --- | --- |
| `ownerId` | string | Uploader |
| `data` | string | Resized base64 payload |
| `size` | number | Bytes; rules cap at 640 KB |
| `createdAt` | timestamp | |

Public read (the catalogue is public), owner-only create/delete, immutable.

---

## Owner-control collections

The administrator follow-up adds the following collections (see the
[operator guide](admin-controls.md) for deletion and delivery limitations):

- `userAccess/{uid}`: `status` (`active`, `suspended`, `deleted`), `reason`,
  `actorId`, `updatedAt`. Only the verified admin may write; only the target
  and admin may read. A deleted restriction cannot be cleared/restored through
  client rules. Restricted UIDs lose marketplace writes; absence means active.
  The admin UID/current admin is protected. Retained after marketplace removal.
- `appConfig/control`: public maintenance flag/message; admin-write only. Stops
  new content, images, orders and service requests, not normal existing-work
  transitions for unrestricted accounts.
- `appConfig/launchMessage`: public active launch-message revision, full title
  and body, `everyLaunch`, actor and timestamps. Admin-write only. Local
  acknowledgements are per device/account; publication reaches future users.
- `announcements/{id}`: immutable admin-readable publication history.
- `adminAudit/{id}`: immutable admin-readable action history. Client entries
  must identify the verified current administrator and use server timestamps;
  the trusted IAM Auth-cleanup tool may also append its operator audit record.

New orders are strictly single-line, matching the current cartless client.
Rules check the actual product's seller, access status, active/demo flags and
stock transition. Admin inspection includes order/request snapshots but does
not expose the buyer-only hand-over-secret subcollection. Marketplace removal
does not delete transaction history or a Firebase Authentication account.

## Transition contracts

All transitions run as Firestore transactions from the client and are validated
by the rules.

### `placeOrder(items, delivery)`

Reads the products, allocates a free `SQ-` id, validates name/email/phone/
building/room, then writes in one transaction:

1. the order (`status: pending`),
2. one delivery per seller (`status: ready`, `otpAttempts: 0`),
3. one secret per delivery (a random 6-digit code),
4. one `new_sale` notification per seller,
5. `stock -= quantity`, `soldCount += quantity` per product.

After the commit, the buyer's name/phone/building/room are written back to their
profile (best effort). A failure there never fails the order.

### `releaseDelivery(orderNumber, deliveryId, code)`

Seller-only. A wrong code makes the rules reject the whole transaction, then the
client increments `otpAttempts` in a second transaction (the rules allow only
+1, max 5). On success: delivery → `delivered` (`otpEntered`, `deliveredAt`),
and the order status is recomputed from all legs (`delivered` only when every
leg is delivered).

### `rotateDeliveryCode(orderNumber, deliveryId)`

Buyer-only, for a locked-out seller. Rewrites the secret's `code` and resets
`otpAttempts` to 0 in one transaction.

### `cancelOrder(orderNumber)`

Buyer-only, before any leg is delivered. Cancels every open leg, restores stock
(`stock += quantity`, `soldCount` untouched) and sets the order to `cancelled`.
After delivery, cancellation is refused.

### Status derivation

`OrderMath.deriveOrderStatus`:

- every leg delivered → `delivered`
- every leg cancelled → `cancelled`
- otherwise → `pending`

---

## Rules matrix

| Operation | Buyer | Seller in the order | Stranger | Signed out |
| --- | --- | --- | --- | --- |
| Read order | ✅ | ✅ | ❌ | ❌ |
| Probe unused order id | ✅ | ✅ | ✅ | ❌ |
| Create order | ✅ (own uid) | — | — | ❌ |
| Update order status | ✅ | ✅ | ❌ | ❌ |
| Read delivery | ✅ | ✅ | ❌ | ❌ |
| Create delivery | ✅ (with order only) | — | — | ❌ |
| Capture delivery | ❌ (cannot type own code) | ✅ (with code) | ❌ | ❌ |
| Record failed attempt | — | ✅ (+1 only) | ❌ | ❌ |
| Reset attempts / rotate code | ✅ | ❌ | ❌ | ❌ |
| Cancel a leg | ✅ | ❌ | ❌ | ❌ |
| Read hand-over secret | ✅ | ❌ | ❌ | ❌ |
| Read inbox / mark read | — | ✅ (owner) | ❌ | ❌ |
| Create notification | ✅ (with the order) | — | ❌ | ❌ |

---

## Indexes

Deployed from `firestore.indexes.json`:

| Collection | Fields | Why |
| --- | --- | --- |
| `products` | `isActive ASC, createdAt DESC` | Browse |
| `products` | `sellerId ASC, createdAt DESC` | My listings |
| `services` | `isActive ASC, createdAt DESC` | Services tab |
| `services` | `providerId ASC, createdAt DESC` | My services |
| `serviceRequests` | `providerId ASC, createdAt DESC` | Inbox |
| `serviceRequests` | `requesterId ASC, createdAt DESC` | Sent requests |
| `orders` | `userId ASC, createdAt DESC` | My orders |
| `orders` | `sellerIds CONTAINS, createdAt DESC` | My sales |

Single-field indexes cover `deliveries.createdAt`,
`notifications.createdAt`, and `notifications.read`.

---

## Quota and scale

Spark limits: **50,000 reads / 20,000 writes per day**.

The app keeps the home screen cheap:

- Browse streams **60 products + 60 services** (`browseCatalogueLimit`).
- Search is opened on demand and streams up to **300 + 300** for the smart
  search (`searchCatalogueLimit`).
- Firestore's mobile offline cache means repeat opens cost little.
- The notification inbox is limited to the 50 newest items.

Order placement costs roughly 3 reads and 5 writes; a delivery completion costs
about 5 reads and 2 writes.

**1,000 registered users fits. 1,000 daily active users does not.** At ~120
reads per cold session, the free daily read allowance covers roughly 400 fresh
sessions/day before search and orders. For a genuinely busy marketplace, move
to Blaze (or another backend) and/or add server-side search.

---

## Threat model

| Attack | Mitigation |
| --- | --- |
| Seller reads the buyer's code from Firestore | `deliverySecrets` is buyer-only; the capture rule compares it server-side |
| Seller grinds codes | Five attempts max; the counter can only +1; the buyer rotates |
| Attacker marks a delivery delivered | Only the owning seller, only with the secret code, only from `ready` |
| Attacker cancels someone's order | Buyer-only, before delivery, participant-checked |
| Buyer cancels after receiving goods | Refused once any leg is `delivered` |
| Attacker creates a fake order | `userId == auth.uid`, one-line total/stock checks, `createdAt == request.time` |
| Attacker spams a seller's inbox | Create is bound to an order created in the same transaction by the caller; recipient must be in `sellerIds` |
| Stranger edits a listing | Owner-only fields; non-owners limited to bounded stock/views counters |
| Oversized image upload | 640 KB size cap in the rules |

Residual risk: a signed-in user can pair `stock`/`soldCount` moves without an
order (the rules cannot link a counter write to an order). The blast radius is
bounded to 999 units and cannot change price, text or visibility. Eliminating it
requires server-side writes or App Check with a trusted backend.
