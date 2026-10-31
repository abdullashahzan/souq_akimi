import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/app_config.dart';
import '../data/repositories/admin_repository.dart';
import '../models/product.dart';
import '../models/service.dart';
import 'auth.dart';
import 'dependencies.dart';

/// The signed-in account's email is the admin gate in the UI. Firestore rules
/// enforce the same rule independently.
final isAdminProvider = Provider<bool>((ref) {
  final user = ref.watch(authStateProvider).value;
  return user?.email?.toLowerCase() == AppConfig.adminEmail &&
      user?.emailVerified == true;
});

final adminStatsProvider = FutureProvider<AdminStats>(
  (ref) => ref.watch(adminRepositoryProvider).stats(),
);

final adminProductsProvider = StreamProvider<List<Product>>(
  (ref) => ref.watch(adminRepositoryProvider).watchProducts(),
);

final adminServicesProvider = StreamProvider<List<Service>>(
  (ref) => ref.watch(adminRepositoryProvider).watchServices(),
);
