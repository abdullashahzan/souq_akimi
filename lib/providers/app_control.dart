import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/app_control.dart';
import '../data/repositories/app_control_repository.dart';
import 'auth.dart';

final appControlRepositoryProvider = Provider((ref) => AppControlRepository());
final appControlProvider = StreamProvider<AppControl>(
  (ref) => ref.watch(appControlRepositoryProvider).watchControl(),
);
final launchMessageProvider = StreamProvider<LaunchMessage>(
  (ref) => ref.watch(appControlRepositoryProvider).watchMessage(),
);
final userAccessProvider = StreamProvider<UserAccess>((ref) {
  final uid = ref.watch(currentUidProvider);
  return uid == null
      ? Stream.value(const UserAccess())
      : ref.watch(appControlRepositoryProvider).watchAccess(uid);
});
