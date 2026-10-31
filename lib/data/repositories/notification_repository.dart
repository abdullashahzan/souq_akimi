import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/app_notification.dart';
import '../collections.dart';

/// Reads and updates the signed-in user's in-app inbox.
///
/// Notifications are created by other users' devices (a buyer placing an
/// order), so this class only ever *reads* them and marks them read.
class NotificationRepository {
  NotificationRepository({FirebaseFirestore? db})
    : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> _inbox(String uid) =>
      _db.collection(Col.users).doc(uid).collection(Col.notifications);

  /// The newest notifications, newest first. Limiting the stream keeps the
  /// inbox cheap on the free plan; the badge only needs "is there anything
  /// unread", not an exact total.
  Stream<List<AppNotification>> watch(String uid, {int limit = 50}) =>
      _inbox(uid)
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .snapshots()
          .map((snap) => snap.docs.map(AppNotification.fromDoc).toList());

  Future<void> markRead(String uid, String notificationId) =>
      _inbox(uid).doc(notificationId).update({'read': true});

  /// Marks every unread notification as read in one batch.
  ///
  /// The rules let the owner touch only the `read` flag, so a batch update is
  /// exactly as safe as a single one.
  Future<void> markAllRead(String uid) async {
    final unread = await _inbox(uid).where('read', isEqualTo: false).get();
    if (unread.docs.isEmpty) return;
    final batch = _db.batch();
    for (final doc in unread.docs) {
      batch.update(doc.reference, {'read': true});
    }
    await batch.commit();
  }
}
