import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/app_config.dart';
import '../data/repositories/admin_repository.dart';
import '../models/product.dart';
import '../models/service.dart';
import '../models/app_control.dart';
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
  (ref) => ref
      .watch(adminRepositoryProvider)
      .watchProducts(limit: ref.watch(adminUserLimitProvider)),
);

final adminServicesProvider = StreamProvider<List<Service>>(
  (ref) => ref
      .watch(adminRepositoryProvider)
      .watchServices(limit: ref.watch(adminUserLimitProvider)),
);

class AdminUserLimit extends Notifier<int> {
  @override
  int build() => 200;
  void more() => state += 200;
}

final adminUserLimitProvider = NotifierProvider<AdminUserLimit, int>(
  AdminUserLimit.new,
);
final adminUsersProvider = StreamProvider<List<AdminUser>>(
  (ref) => ref
      .watch(adminRepositoryProvider)
      .watchUsers(limit: ref.watch(adminUserLimitProvider)),
);
final adminAccessProvider = StreamProvider<Map<String, UserAccess>>(
  (ref) => ref.watch(adminRepositoryProvider).watchAccess(),
);
final adminAuditProvider = StreamProvider<List<Map<String, dynamic>>>(
  (ref) => ref.watch(adminRepositoryProvider).watchAudit(),
);
final adminOrdersProvider = StreamProvider<List<Map<String, dynamic>>>(
  (ref) => ref
      .watch(adminRepositoryProvider)
      .watchRecords(requests: false, limit: ref.watch(adminUserLimitProvider)),
);
final adminRequestsProvider = StreamProvider<List<Map<String, dynamic>>>(
  (ref) => ref
      .watch(adminRepositoryProvider)
      .watchRecords(requests: true, limit: ref.watch(adminUserLimitProvider)),
);
