// Firestore exports its own `Order` (an index-direction enum); ours wins.
import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'package:firebase_auth/firebase_auth.dart' show FirebaseAuth;

import '../../core/souq_exception.dart';
import '../../models/delivery.dart';
import '../../models/enums.dart';
import '../../models/order.dart';
import '../codec.dart';
import '../collections.dart';
import '../order_math.dart';

/// The result of a successful `placeOrder`.
class PlaceOrderResult {
  const PlaceOrderResult({
    required this.orderNumber,
    required this.total,
    required this.deliveries,
  });

  final String orderNumber;
  final double total;
  final int deliveries;
}

/// The buyer's hand-over code plus how many tries remain.
class DeliveryOtpResult {
  const DeliveryOtpResult({required this.otp, required this.attemptsRemaining});

  final String otp;
  final int attemptsRemaining;
}

/// Buyer/seller views over `orders`, plus every delivery transition.
///
/// Every order is **cash on delivery** and the seller always brings the item
/// to the buyer's hostel room. This project runs on Firebase's Spark (free)
/// plan, which cannot deploy Cloud Functions, so the logic lives here as client
/// transactions and is *enforced* by `firestore.rules`:
///
/// - the order, its deliveries, their hand-over secrets, the seller's
///   notification and the stock decrement are written in **one** transaction,
///   so an order and its legs are born together;
/// - a seller can only mark a delivery `delivered` by submitting the buyer's
///   six-digit code, which the rules compare against `deliverySecrets` — a
///   document the seller is not allowed to read;
/// - only the buyer can cancel or rotate a code, and only the buyer's own
///   stock movements are paired with `soldCount`.
class OrderRepository {
  OrderRepository({FirebaseFirestore? db, FirebaseAuth? auth})
    : _db = db ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  CollectionReference<Map<String, dynamic>> get _orders =>
      _db.collection(Col.orders);
  CollectionReference<Map<String, dynamic>> get _products =>
      _db.collection(Col.products);
  CollectionReference<Map<String, dynamic>> get _users =>
      _db.collection(Col.users);

  // --- Views ---------------------------------------------------------------

  /// Orders the user placed as a buyer.
  Stream<List<Order>> watchForBuyer(String uid) => _orders
      .where('userId', isEqualTo: uid)
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((snap) => snap.docs.map(Order.fromDoc).toList());

  /// Orders containing at least one of the user's listings.
  Stream<List<Order>> watchForSeller(String uid) => _orders
      .where('sellerIds', arrayContains: uid)
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((snap) => snap.docs.map(Order.fromDoc).toList());

  Stream<Order?> watchOne(String orderNumber) => _orders
      .doc(orderNumber)
      .snapshots()
      .map((snap) => snap.exists ? Order.fromDoc(snap) : null);

  /// One delivery leg per seller in the order.
  Stream<List<Delivery>> watchDeliveries(String orderNumber) => _orders
      .doc(orderNumber)
      .collection(Col.deliveries)
      .orderBy('createdAt')
      .snapshots()
      .map((snap) => snap.docs.map(Delivery.fromDoc).toList());

  // --- Transitions ---------------------------------------------------------

  /// Place an order. `items` is `[{productId, quantity}]` — Souq is cartless,
  /// so the app always sends exactly one line item.
  ///
  /// Everything lands in a single transaction: the order, one delivery (plus
  /// its hand-over secret) per seller, a notification for each seller, and the
  /// stock decrement on every product. The security rules refuse partial
  /// versions of that write, which is what keeps stock honest without a server.
  Future<PlaceOrderResult> placeOrder({
    required List<Map<String, Object?>> items,
    required Map<String, Object?> delivery,
  }) async {
    final uid = _requireUid();
    final input = _parsePlaceOrderInput(items, delivery);

    final result = await _guard(() => _runPlaceOrder(uid, input));

    // Remember the details the buyer just typed so the next checkout is
    // prefilled. A failure here must never fail an order that already exists.
    await _rememberDeliveryDetails(uid, input);

    return result;
  }

  Future<PlaceOrderResult> _runPlaceOrder(
    String uid,
    _PlaceOrderInput input,
  ) => _db.runTransaction<PlaceOrderResult>((txn) async {
    // ---- reads -----------------------------------------------------------
    final productIds = input.merged.keys.toList(growable: false);
    final productSnaps = <String, DocumentSnapshot<Map<String, dynamic>>>{};
    for (final id in productIds) {
      productSnaps[id] = await txn.get(_products.doc(id));
    }

    // Allocate a free order id (retry a few times on the astronomically
    // unlikely collision; random ids make this effectively never loop).
    var orderNumber = OrderMath.generateOrderNumber();
    var orderSnap = await txn.get(_orders.doc(orderNumber));
    for (var guard = 0; orderSnap.exists && guard < 5; guard++) {
      orderNumber = OrderMath.generateOrderNumber();
      orderSnap = await txn.get(_orders.doc(orderNumber));
    }
    if (orderSnap.exists) {
      throw const SouqException(
        'Could not allocate an order number. Please retry.',
        code: 'internal',
      );
    }

    // ---- validate + build line items ------------------------------------
    final lineItems = <Map<String, Object>>[];
    for (final id in productIds) {
      final snap = productSnaps[id]!;
      if (!snap.exists) {
        throw const SouqException(
          'One of the items in your basket is no longer available.',
          code: 'failed-precondition',
        );
      }
      final product = snap.data() ?? const <String, dynamic>{};
      if (Codec.boolean(product['isDemo'])) {
        throw const SouqException(
          'Demo items are for browsing only and cannot be purchased.',
          code: 'failed-precondition',
        );
      }
      final name = Codec.str(product['name'], 'This item');
      if (Codec.boolean(product['isActive']) != true) {
        throw SouqException(
          '$name is no longer available.',
          code: 'failed-precondition',
        );
      }
      final stock = Codec.integer(product['stock']);
      final quantity = input.merged[id]!;
      if (stock < quantity) {
        throw SouqException(
          'Only $stock left of $name.',
          code: 'failed-precondition',
        );
      }
      final price = Codec.dbl(product['price']);
      final sellerId = Codec.str(product['sellerId']);
      if (sellerId.isEmpty) {
        throw SouqException(
          '$name is not for sale right now.',
          code: 'failed-precondition',
        );
      }
      lineItems.add({
        'productId': id,
        'sellerId': sellerId,
        'sellerUsername': Codec.str(product['sellerUsername']),
        'productName': name,
        'quantity': quantity,
        'price': price,
        'lineTotal': OrderMath.roundMoney(price * quantity),
      });
    }

    final sellerIds = <String>{
      for (final item in lineItems) item['sellerId'] as String,
    }.toList(growable: false);
    final sellerUsernames = <String, String>{
      for (final item in lineItems)
        item['sellerId'] as String: item['sellerUsername'] as String,
    };
    final sellerItems = <String, List<Map<String, Object>>>{};
    for (final item in lineItems) {
      sellerItems.putIfAbsent(item['sellerId'] as String, () => []).add(item);
    }

    // ---- compute totals --------------------------------------------------
    final total = OrderMath.roundMoney(
      lineItems.fold<double>(
        0,
        (running, item) => running + (item['lineTotal'] as num).toDouble(),
      ),
    );
    final sellerAmounts = <String, double>{};
    for (final item in lineItems) {
      final sellerId = item['sellerId'] as String;
      sellerAmounts[sellerId] = OrderMath.roundMoney(
        (sellerAmounts[sellerId] ?? 0) + (item['lineTotal'] as num).toDouble(),
      );
    }

    final stamp = FieldValue.serverTimestamp();

    // ---- writes ----------------------------------------------------------
    final orderRef = _orders.doc(orderNumber);
    txn.set(orderRef, <String, Object?>{
      'orderNumber': orderNumber,
      'userId': uid,
      'fullName': input.fullName,
      'email': input.email,
      'phone': input.phone,
      'building': input.building,
      'roomNumber': input.roomNumber,
      'deliveryNotes': input.deliveryNotes,
      'total': total,
      'status': 'pending',
      'items': lineItems,
      'sellerIds': sellerIds,
      'createdAt': stamp,
    });

    final deliveriesCol = orderRef.collection(Col.deliveries);
    final secretsCol = orderRef.collection(Col.deliverySecrets);
    for (final sellerId in sellerIds) {
      final deliveryRef = deliveriesCol.doc(sellerId);
      txn.set(deliveryRef, <String, Object>{
        'id': deliveryRef.id,
        'sellerId': sellerId,
        'sellerUsername': sellerUsernames[sellerId] ?? '',
        'amount': sellerAmounts[sellerId] ?? 0,
        'status': 'ready',
        'otpAttempts': 0,
        'createdAt': stamp,
      });
      // The one document the seller can never open: it carries the code the
      // buyer will read out at the door.
      txn.set(secretsCol.doc(deliveryRef.id), <String, Object>{
        'deliveryId': deliveryRef.id,
        'code': OrderMath.generateOtp(),
        'createdAt': stamp,
      });

      // Tell the seller right away. The notification lives in their own inbox
      // so a single query streams it, and the rules check it against the
      // order this same transaction just created.
      final items = sellerItems[sellerId] ?? const <Map<String, Object>>[];
      final summary = items
          .map((item) => '${item['quantity']} × ${item['productName']}')
          .join(', ');
      final notificationRef = _users
          .doc(sellerId)
          .collection(Col.notifications)
          .doc('n-$orderNumber');
      txn.set(notificationRef, <String, Object>{
        'id': notificationRef.id,
        'userId': sellerId,
        'actorId': uid,
        'actorUsername': input.fullName,
        'type': 'new_sale',
        'title': 'New order #$orderNumber',
        'body':
            '${input.fullName} ordered $summary. '
            'Deliver to ${input.building}, room ${input.roomNumber}.',
        'orderNumber': orderNumber,
        'read': false,
        'createdAt': stamp,
      });
    }

    for (final id in productIds) {
      final quantity = input.merged[id]!;
      txn.update(_products.doc(id), {
        'stock': FieldValue.increment(-quantity),
        'soldCount': FieldValue.increment(quantity),
        'updatedAt': stamp,
        'lastOrderId': orderNumber,
      });
    }

    return PlaceOrderResult(
      orderNumber: orderNumber,
      total: total,
      deliveries: sellerIds.length,
    );
  });

  /// Writes the checkout details back to the profile so the form is prefilled
  /// next time. Best-effort: the order already committed.
  Future<void> _rememberDeliveryDetails(
    String uid,
    _PlaceOrderInput input,
  ) async {
    try {
      await _users.doc(uid).set({
        'displayName': input.fullName,
        'phone': input.phone,
        'building': input.building,
        'roomNumber': input.roomNumber,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {
      // Never turn a successful order into an error because a convenience
      // write failed.
    }
  }

  /// Buyer-only: read the one-time code for a delivery.
  Future<DeliveryOtpResult> getDeliveryOtp({
    required String orderNumber,
    required String deliveryId,
  }) async {
    final uid = _requireUid();
    return _guard(() async {
      final orderRef = _orders.doc(orderNumber);
      final orderSnap = await orderRef.get();
      if (!orderSnap.exists) {
        throw const SouqException('Order not found.', code: 'not-found');
      }
      if (Codec.str(orderSnap.data()?['userId']) != uid) {
        throw const SouqException(
          'Only the buyer can view this delivery code.',
          code: 'permission-denied',
        );
      }

      final secretSnap = await orderRef
          .collection(Col.deliverySecrets)
          .doc(deliveryId)
          .get();
      if (!secretSnap.exists) {
        throw const SouqException(
          'We could not find that any more.',
          code: 'not-found',
        );
      }
      final deliverySnap = await orderRef
          .collection(Col.deliveries)
          .doc(deliveryId)
          .get();
      if (!deliverySnap.exists) {
        throw const SouqException('Delivery not found.', code: 'not-found');
      }

      return DeliveryOtpResult(
        otp: Codec.str(secretSnap.data()?['code']),
        attemptsRemaining: Delivery.fromDoc(deliverySnap).attemptsRemaining,
      );
    });
  }

  /// Buyer-only: mint a fresh hand-over code after a seller is locked out.
  ///
  /// Resets the failed-attempt counter in the same transaction, so the rules
  /// (which only the buyer may satisfy) hand the seller five new tries.
  Future<void> rotateDeliveryCode({
    required String orderNumber,
    required String deliveryId,
  }) async {
    final uid = _requireUid();
    await _guard(() async {
      final orderRef = _orders.doc(orderNumber);
      final deliveryRef = orderRef.collection(Col.deliveries).doc(deliveryId);
      final secretRef = orderRef
          .collection(Col.deliverySecrets)
          .doc(deliveryId);

      await _db.runTransaction<void>((txn) async {
        final orderSnap = await txn.get(orderRef);
        if (!orderSnap.exists) {
          throw const SouqException('Order not found.', code: 'not-found');
        }
        if (Codec.str(orderSnap.data()?['userId']) != uid) {
          throw const SouqException(
            'Only the buyer can view this delivery code.',
            code: 'permission-denied',
          );
        }
        final deliverySnap = await txn.get(deliveryRef);
        if (!deliverySnap.exists) {
          throw const SouqException('Delivery not found.', code: 'not-found');
        }
        final delivery = Delivery.fromDoc(deliverySnap);
        if (!delivery.canBeReleased) {
          throw const SouqException(
            'This delivery is already settled.',
            code: 'failed-precondition',
          );
        }

        final secretSnap = await txn.get(secretRef);
        if (secretSnap.exists) {
          txn.update(secretRef, {'code': OrderMath.generateOtp()});
        } else {
          txn.set(secretRef, <String, Object>{
            'deliveryId': deliveryId,
            'code': OrderMath.generateOtp(),
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
        txn.update(deliveryRef, {'otpAttempts': 0, 'pendingCode': ''});
      });
    });
  }

  /// Seller-only: complete a delivery by proving the buyer's code.
  ///
  /// The expected code lives in a document this client is forbidden to read, so
  /// a wrong guess is a `permission-denied` from the rules — that is what makes
  /// the counter in [Delivery.otpAttempts] a real lockout rather than a
  /// suggestion. Returns the new order status.
  Future<String> releaseDelivery({
    required String orderNumber,
    required String deliveryId,
    required String code,
  }) async {
    final uid = _requireUid();
    return _guard(() async {
      final orderRef = _orders.doc(orderNumber);
      final deliveryRef = orderRef.collection(Col.deliveries).doc(deliveryId);

      // Cheap pre-reads for friendly messages; the rules re-check everything.
      final preOrder = await orderRef.get();
      if (!preOrder.exists) {
        throw const SouqException('Order not found.', code: 'not-found');
      }
      final preDelivery = await deliveryRef.get();
      if (!preDelivery.exists) {
        throw const SouqException('Delivery not found.', code: 'not-found');
      }
      final delivery = Delivery.fromDoc(preDelivery);
      if (delivery.sellerId != uid) {
        throw const SouqException(
          'Only the seller can complete this delivery.',
          code: 'permission-denied',
        );
      }
      if (!delivery.canBeReleased) {
        throw const SouqException(
          'This delivery has already been settled.',
          code: 'failed-precondition',
        );
      }
      if (delivery.attemptsRemaining <= 0) {
        throw const SouqException(
          'Too many incorrect codes. Ask the buyer to generate a new code.',
          code: 'failed-precondition',
        );
      }

      final ids = await _deliveryIds(orderNumber);
      // Consume a guess BEFORE asking the rules to compare it. Rejected writes
      // cannot count attempts; storing the guess first prevents modified clients
      // from brute-forcing the secret without spending their five attempts.
      await _db.runTransaction<void>((txn) async {
        final snap = await txn.get(deliveryRef);
        final data = snap.data() ?? {};
        final used = Codec.integer(data['otpAttempts']);
        if (data['status'] != 'ready' || used >= 5) {
          throw const SouqException(
            'Too many incorrect codes. Ask the buyer to generate a new code.',
          );
        }
        txn.update(deliveryRef, {'otpAttempts': used + 1, 'pendingCode': code});
      });
      try {
        return await _db.runTransaction<String>((txn) async {
          final oSnap = await txn.get(orderRef);
          if (!oSnap.exists) {
            throw const SouqException(
              'Order or delivery not found.',
              code: 'not-found',
            );
          }
          final all = await _readDeliveries(txn, deliveryRef.parent, ids);
          final sellerProfile = await txn.get(_users.doc(uid));
          Delivery? current;
          for (final candidate in all) {
            if (candidate.id == deliveryId) {
              current = candidate;
              break;
            }
          }
          if (current == null) {
            throw const SouqException('Delivery not found.', code: 'not-found');
          }
          if (current.sellerId != uid) {
            throw const SouqException(
              'Only the seller can complete this delivery.',
              code: 'permission-denied',
            );
          }
          if (!current.canBeReleased) {
            throw const SouqException(
              'This delivery has already been settled.',
              code: 'failed-precondition',
            );
          }

          final status = OrderMath.deriveOrderStatus([
            for (final d in all)
              d.id == deliveryId ? 'delivered' : d.status.value,
          ]);

          final stamp = FieldValue.serverTimestamp();
          txn.update(deliveryRef, {
            'status': 'delivered',
            'otpEntered': code,
            'deliveredAt': stamp,
          });
          txn.update(orderRef, {'status': status});
          // One completed delivery = one sale in the seller's public tally.
          // A newly completed delivery proves this increment to the rules.
          txn.set(_users.doc(uid), {
            'salesCount': FieldValue.increment(1),
            'updatedAt': stamp,
            'salesOrderId': orderNumber,
            'salesDeliveryId': deliveryId,
          }, SetOptions(merge: true));
          txn.set(_db.collection(Col.publicProfiles).doc(uid), {
            'username': sellerProfile.data()?['username'] ?? '',
            'salesCount':
                Codec.integer(sellerProfile.data()?['salesCount']) + 1,
          });
          return status;
        });
      } on FirebaseException catch (error) {
        if (error.code != 'permission-denied') rethrow;
        // The rules rejected the code (or the delivery is no longer open).
        final latest = await deliveryRef.get();
        final remaining = OrderMath.attemptsRemaining(
          Codec.integer(latest.data()?['otpAttempts']),
        );
        if (remaining <= 0) {
          throw const SouqException(
            'Too many incorrect codes. Ask the buyer to generate a new code.',
            code: 'failed-precondition',
          );
        }
        throw SouqException(
          'Incorrect code. $remaining attempt${remaining == 1 ? '' : 's'} '
          'remaining.',
          code: 'invalid-argument',
        );
      }
    });
  }

  /// Buyer-only: cancel an order that has not been delivered yet, returning
  /// every line to stock.
  Future<void> cancelOrder(String orderNumber) async {
    final uid = _requireUid();
    await _guard(() async {
      final orderRef = _orders.doc(orderNumber);

      final ids = await _deliveryIds(orderNumber);
      await _db.runTransaction<void>((txn) async {
        final oSnap = await txn.get(orderRef);
        if (!oSnap.exists) {
          throw const SouqException('Order not found.', code: 'not-found');
        }
        final order = Order.fromDoc(oSnap);
        if (order.userId != uid) {
          throw const SouqException(
            'Only the buyer can cancel this order.',
            code: 'permission-denied',
          );
        }
        if (order.status == OrderStatus.cancelled) {
          throw const SouqException(
            'This order is already cancelled.',
            code: 'failed-precondition',
          );
        }

        final deliveriesRef = orderRef.collection(Col.deliveries);
        final deliveries = await _readDeliveries(txn, deliveriesRef, ids);
        if (deliveries.any((d) => d.isDelivered)) {
          throw const SouqException(
            'This order has already been delivered and can no longer be '
            'cancelled.',
            code: 'failed-precondition',
          );
        }
        final open = deliveries.where((d) => d.canBeReleased).toList();
        if (open.isEmpty) {
          throw const SouqException(
            'This order has already been settled.',
            code: 'failed-precondition',
          );
        }

        final restock = await _readRestock(txn, items: order.items);
        final stamp = FieldValue.serverTimestamp();
        for (final delivery in open) {
          txn.update(deliveriesRef.doc(delivery.id), {'status': 'cancelled'});
        }
        for (final entry in restock) {
          txn.update(entry.ref, {
            'stock': FieldValue.increment(entry.qty),
            'updatedAt': stamp,
            'lastOrderId': orderNumber,
          });
        }
        txn.update(orderRef, {'status': 'cancelled'});
      });
    });
  }

  // --- Shared plumbing -----------------------------------------------------

  /// The delivery ids of an order, oldest first.
  ///
  /// Queried *outside* the transaction because the Flutter SDK only supports
  /// `Transaction.get` on documents, never on queries; the transaction then
  /// re-fetches each id, so the recompute always reads committed state.
  Future<List<String>> _deliveryIds(String orderNumber) async {
    final snap = await _orders
        .doc(orderNumber)
        .collection(Col.deliveries)
        .orderBy('createdAt')
        .get();
    return [for (final doc in snap.docs) doc.id];
  }

  /// Fresh reads of every delivery listed in [ids], in the same order.
  Future<List<Delivery>> _readDeliveries(
    Transaction txn,
    CollectionReference<Map<String, dynamic>> col,
    List<String> ids,
  ) async {
    final deliveries = <Delivery>[];
    for (final id in ids) {
      final snap = await txn.get(col.doc(id));
      if (snap.exists) deliveries.add(Delivery.fromDoc(snap));
    }
    return deliveries;
  }

  /// Reads (never writes) the products that need stock restored. Firestore
  /// transactions demand every read before every write, so this is awaited
  /// before the caller touches anything. When [sellerId] is null every line in
  /// the order is restocked.
  Future<List<({DocumentReference<Map<String, dynamic>> ref, int qty})>>
  _readRestock(
    Transaction txn, {
    required List<OrderItem> items,
    String? sellerId,
  }) async {
    final entries =
        <({DocumentReference<Map<String, dynamic>> ref, int qty})>[];
    for (final item in items) {
      if (sellerId != null && item.sellerId != sellerId) continue;
      final ref = _products.doc(item.productId);
      final snap = await txn.get(ref);
      if (snap.exists) entries.add((ref: ref, qty: item.quantity));
    }
    return entries;
  }

  String _requireUid() {
    final uid = _auth.currentUser?.uid;
    if (uid == null || uid.isEmpty) {
      throw const SouqException(
        'Please sign in to continue.',
        code: 'unauthenticated',
      );
    }
    return uid;
  }

  /// Runs [run], turning Firestore failures into display-ready exceptions.
  Future<T> _guard<T>(Future<T> Function() run) async {
    try {
      return await run();
    } on SouqException {
      rethrow;
    } on FirebaseException catch (error) {
      throw _friendly(error);
    }
  }

  SouqException _friendly(FirebaseException error) => switch (error.code) {
    'unauthenticated' => const SouqException(
      'Please sign in to continue.',
      code: 'unauthenticated',
    ),
    'permission-denied' => const SouqException(
      'You are not allowed to do that.',
      code: 'permission-denied',
    ),
    'not-found' => const SouqException(
      'We could not find that any more.',
      code: 'not-found',
    ),
    'unavailable' || 'deadline-exceeded' => const SouqException(
      'The server is unreachable. Check your connection and try again.',
      code: 'unavailable',
    ),
    'aborted' => const SouqException(
      'Someone else changed this just now. Please try again.',
      code: 'aborted',
    ),
    _ => SouqException(
      'Something went wrong. Please try again.',
      code: error.code,
    ),
  };

  /// Input validation — the messages mirror `parsePlaceOrderInput` in the
  /// reference implementation so users see the same wording.
  _PlaceOrderInput _parsePlaceOrderInput(
    List<Map<String, Object?>> items,
    Map<String, Object?> delivery,
  ) {
    if (items.isEmpty) {
      throw const SouqException(
        'Add at least one item to your order.',
        code: 'invalid-argument',
      );
    }
    if (items.length > 50) {
      throw const SouqException(
        'Too many distinct items in one order.',
        code: 'invalid-argument',
      );
    }

    // Merge duplicate product ids so a client cannot double-decrement a product.
    final merged = <String, int>{};
    for (var i = 0; i < items.length; i++) {
      final productId = Codec.str(items[i]['productId']).trim();
      if (productId.isEmpty || productId.length > 200) {
        throw SouqException(
          'items[$i].productId is required.',
          code: 'invalid-argument',
        );
      }
      final quantity = items[i]['quantity'];
      final value = quantity is num ? quantity.toInt() : 0;
      if (value < 1 || value > 999) {
        throw SouqException(
          'items[$i].quantity must be between 1 and 999.',
          code: 'invalid-argument',
        );
      }
      final total = (merged[productId] ?? 0) + value;
      if (total > 999) {
        throw const SouqException(
          'Only 999 of an item can be ordered at once.',
          code: 'invalid-argument',
        );
      }
      merged[productId] = total;
    }

    final email = Codec.str(delivery['email']).trim();
    if (!OrderMath.isValidEmail(email)) {
      throw const SouqException(
        'delivery.email must be a valid email address.',
        code: 'invalid-argument',
      );
    }

    return _PlaceOrderInput(
      merged: merged,
      fullName: _required(delivery['fullName'], 'delivery.fullName', 200),
      email: email,
      phone: _required(delivery['phone'], 'delivery.phone', 40),
      building: _required(delivery['building'], 'delivery.building', 40),
      roomNumber: _required(delivery['roomNumber'], 'delivery.roomNumber', 40),
      deliveryNotes: _optional(delivery['deliveryNotes'], 1000),
    );
  }

  static String _required(Object? value, String name, int max) {
    final text = value is String ? value.trim() : '';
    if (text.isEmpty || text.length > max) {
      throw SouqException('$name is required.', code: 'invalid-argument');
    }
    return text;
  }

  static String _optional(Object? value, int max) {
    final text = value is String ? value.trim() : '';
    return text.length > max ? text.substring(0, max) : text;
  }
}

/// Validated `placeOrder` input.
class _PlaceOrderInput {
  const _PlaceOrderInput({
    required this.merged,
    required this.fullName,
    required this.email,
    required this.phone,
    required this.building,
    required this.roomNumber,
    required this.deliveryNotes,
  });

  /// product id → total quantity, duplicates already merged.
  final Map<String, int> merged;
  final String fullName;
  final String email;
  final String phone;
  final String building;
  final String roomNumber;
  final String deliveryNotes;
}
