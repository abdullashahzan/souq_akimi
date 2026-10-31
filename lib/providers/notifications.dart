import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/app_notification.dart';
import 'auth.dart';
import 'dependencies.dart';

/// The signed-in user's in-app inbox, newest first.
final notificationsProvider = StreamProvider<List<AppNotification>>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(const <AppNotification>[]);
  return ref.watch(notificationRepositoryProvider).watch(uid);
});

/// How many unread items the inbox holds. Drives the Orders-tab badge.
final unreadNotificationCountProvider = Provider<int>((ref) {
  final items = ref.watch(notificationsProvider).value;
  if (items == null) return 0;
  return items.where((item) => !item.read).length;
});

final unreadServiceNotificationCountProvider = Provider<int>((ref) {
  return (ref.watch(notificationsProvider).value ?? const <AppNotification>[])
      .where((item) => !item.read && item.isRequest)
      .length;
});
