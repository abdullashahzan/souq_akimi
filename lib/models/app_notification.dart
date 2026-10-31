import 'package:cloud_firestore/cloud_firestore.dart';

import '../data/codec.dart';

/// One item in a user's in-app inbox (`users/{uid}/notifications`).
///
/// Notifications are written by the buyer's device inside the same transaction
/// as the order, so a seller sees "new order" even if they were offline when it
/// was placed. Delivery is in-app only: the project runs on the Spark plan, so
/// there is no server to send push messages.
class AppNotification {
  const AppNotification({
    required this.id,
    required this.userId,
    required this.actorId,
    required this.actorUsername,
    required this.type,
    required this.title,
    required this.body,
    required this.orderNumber,
    required this.requestId,
    required this.read,
    this.createdAt,
  });

  /// `new_sale` is the only type that exists today; kept as a string so adding
  /// service-request notifications later needs no migration.
  static const String typeNewSale = 'new_sale';
  static const String typeServiceRequest = 'service_request';
  static const String typeAnnouncement = 'announcement';

  final String id;

  /// The recipient — always the owner of the inbox.
  final String userId;

  /// Who caused it (the buyer).
  final String actorId;
  final String actorUsername;
  final String type;
  final String title;
  final String body;
  final String orderNumber;
  final String requestId;
  final bool read;
  final DateTime? createdAt;

  bool get isAnnouncement => type == typeAnnouncement;

  factory AppNotification.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) =>
      AppNotification.fromMap(doc.id, doc.data() ?? const {});

  factory AppNotification.fromMap(String id, Map<String, dynamic> data) =>
      AppNotification(
        id: id,
        userId: Codec.str(data['userId']),
        actorId: Codec.str(data['actorId']),
        actorUsername: Codec.str(data['actorUsername']),
        type: Codec.str(data['type']),
        title: Codec.str(data['title']),
        body: Codec.str(data['body']),
        orderNumber: Codec.str(data['orderNumber']),
        requestId: Codec.str(data['requestId']),
        read: Codec.boolean(data['read']),
        createdAt: Codec.date(data['createdAt']),
      );
}
