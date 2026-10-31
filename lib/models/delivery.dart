import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/app_config.dart';
import '../data/codec.dart';
import 'enums.dart';

/// A seller's leg of an order. One order has one delivery per seller; the
/// seller marks it delivered by typing the buyer's 6-digit hand-over code.
///
/// The code itself is **not** on this document — it lives in the buyer-only
/// `deliverySecrets` subcollection, so a seller can never read it.
class Delivery {
  const Delivery({
    required this.id,
    required this.sellerId,
    required this.sellerUsername,
    required this.amount,
    required this.status,
    required this.otpAttempts,
    this.deliveredAt,
    this.createdAt,
  });

  final String id;
  final String sellerId;
  final String sellerUsername;
  final double amount;
  final DeliveryStatus status;
  final int otpAttempts;
  final DateTime? deliveredAt;
  final DateTime? createdAt;

  /// `Delivery.attempts_remaining`.
  int get attemptsRemaining => (AppConfig.otpMaxAttempts - otpAttempts).clamp(
    0,
    AppConfig.otpMaxAttempts,
  );

  /// Only a delivery that is still open can be handed over with a code.
  bool get canBeReleased => status == DeliveryStatus.ready;

  bool get isDelivered => status == DeliveryStatus.delivered;

  factory Delivery.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) =>
      Delivery.fromMap(doc.id, doc.data() ?? const {});

  factory Delivery.fromMap(String id, Map<String, dynamic> data) => Delivery(
    id: id,
    sellerId: Codec.str(data['sellerId']),
    sellerUsername: Codec.str(data['sellerUsername']),
    amount: Codec.dbl(data['amount']),
    status: DeliveryStatus.from(data['status']),
    otpAttempts: Codec.integer(data['otpAttempts']),
    deliveredAt: Codec.date(data['deliveredAt']),
    createdAt: Codec.date(data['createdAt']),
  );
}
