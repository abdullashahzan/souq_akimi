import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/app_user.dart';
import '../models/product.dart';
import '../models/service.dart';
import 'catalogue.dart';
import 'dependencies.dart';

/// Distinct sellers visible in the home catalogue, capped to the `whereIn`
/// limit so one small query can power every card's sales tally.
final visibleSellerIdsProvider = Provider<List<String>>((ref) {
  final products = ref.watch(productsProvider).value ?? const <Product>[];
  final services = ref.watch(servicesProvider).value ?? const <Service>[];
  final ids = <String>{
    for (final product in products)
      if (product.sellerId.isNotEmpty) product.sellerId,
    for (final service in services)
      if (service.providerId.isNotEmpty) service.providerId,
  }.toList(growable: false)..sort();
  return ids.take(30).toList(growable: false);
});

final visibleSellerProfilesProvider = StreamProvider<Map<String, AppUser>>((
  ref,
) {
  final ids = ref.watch(visibleSellerIdsProvider);
  if (ids.isEmpty) return Stream.value(const <String, AppUser>{});
  return ref.watch(userRepositoryProvider).watchMany(ids);
});

/// uid → completed sales, for the handles currently on screen.
final visibleSellerSalesProvider = Provider<Map<String, int>>((ref) {
  final profiles = ref.watch(visibleSellerProfilesProvider).value;
  if (profiles == null) return const {};
  return {
    for (final entry in profiles.entries) entry.key: entry.value.salesCount,
  };
});

/// A single seller's live public profile, for detail screens.
final sellerProfileProvider = StreamProvider.family<AppUser, String>((
  ref,
  uid,
) {
  if (uid.isEmpty) return Stream.value(AppUser.empty(''));
  return ref.watch(userRepositoryProvider).watchPublic(uid);
});

/// The visible display string for a seller, e.g. `@lina (12)`.
String sellerHandle(String username, int? sales) {
  // The LEFT-TO-RIGHT MARK keeps `@name (12)` from being reordered inside an
  // Arabic paragraph; without it the handle reads as `name (12)@`.
  const ltr = '\u200E';
  final handle = '$ltr@${username.trim()}';
  if (username.trim().isEmpty) return handle;
  return sales == null ? handle : '$handle ($sales)';
}
