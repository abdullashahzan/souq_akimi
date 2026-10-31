import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/delivery.dart';
import '../models/order.dart';
import '../models/product.dart';
import '../models/service.dart';
import 'auth.dart';
import 'dependencies.dart';

// --------------------------------------------------------------------------- #
// Orders
// --------------------------------------------------------------------------- #
/// Orders the signed-in user placed.
final myOrdersProvider = StreamProvider<List<Order>>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(const []);
  return ref.watch(orderRepositoryProvider).watchForBuyer(uid);
});

/// Orders containing one of the signed-in user's listings.
final mySalesProvider = StreamProvider<List<Order>>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(const []);
  return ref.watch(orderRepositoryProvider).watchForSeller(uid);
});

final orderProvider = StreamProvider.family<Order?, String>(
  (ref, orderNumber) =>
      ref.watch(orderRepositoryProvider).watchOne(orderNumber),
);

final deliveriesProvider = StreamProvider.family<List<Delivery>, String>(
  (ref, orderNumber) =>
      ref.watch(orderRepositoryProvider).watchDeliveries(orderNumber),
);

// --------------------------------------------------------------------------- #
// Service requests
// --------------------------------------------------------------------------- #
/// Requests the user sent to providers.
final outgoingRequestsProvider = StreamProvider<List<ServiceRequest>>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(const []);
  return ref.watch(serviceRepositoryProvider).watchRequestsByRequester(uid);
});

/// Requests other students sent to the user.
final incomingRequestsProvider = StreamProvider<List<ServiceRequest>>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(const []);
  return ref.watch(serviceRepositoryProvider).watchRequestsByProvider(uid);
});

// --------------------------------------------------------------------------- #
// The "buy now" draft — Souq has no cart, one listing at a time.
// --------------------------------------------------------------------------- #
class PendingPurchase {
  const PendingPurchase({this.product, this.quantity = 1});

  final Product? product;
  final int quantity;

  bool get isEmpty => product == null;

  double get lineTotal => (product?.price ?? 0) * quantity;

  PendingPurchase copyWith({Product? product, int? quantity}) =>
      PendingPurchase(
        product: product ?? this.product,
        quantity: quantity ?? this.quantity,
      );
}

class PendingPurchaseNotifier extends Notifier<PendingPurchase> {
  @override
  PendingPurchase build() => const PendingPurchase();

  /// Start a purchase, clamping the quantity to what is actually in stock.
  void start(Product product, {int quantity = 1}) {
    final maxQuantity = product.stock > 0 ? product.stock : 1;
    state = PendingPurchase(
      product: product,
      quantity: quantity.clamp(1, maxQuantity),
    );
  }

  void setQuantity(int quantity) {
    final product = state.product;
    if (product == null) return;
    final maxQuantity = product.stock > 0 ? product.stock : 1;
    state = state.copyWith(quantity: quantity.clamp(1, maxQuantity));
  }

  void clear() => state = const PendingPurchase();
}

final pendingPurchaseProvider =
    NotifierProvider<PendingPurchaseNotifier, PendingPurchase>(
      PendingPurchaseNotifier.new,
    );
