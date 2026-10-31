import 'package:cloud_firestore/cloud_firestore.dart';

import '../data/codec.dart';
import 'enums.dart';

/// One line of an order — a snapshot, so order history survives a listing being
/// edited or deleted. Mirrors `souqapp.models.OrderItem`.
class OrderItem {
  const OrderItem({
    required this.productId,
    required this.sellerId,
    required this.sellerUsername,
    required this.productName,
    required this.quantity,
    required this.price,
  });

  final String productId;
  final String sellerId;
  final String sellerUsername;
  final String productName;
  final int quantity;
  final double price;

  double get lineTotal => price * quantity;

  factory OrderItem.fromMap(Map<String, dynamic> data) => OrderItem(
    productId: Codec.str(data['productId']),
    sellerId: Codec.str(data['sellerId']),
    sellerUsername: Codec.str(data['sellerUsername']),
    productName: Codec.str(data['productName']),
    quantity: Codec.integer(data['quantity'], 1),
    price: Codec.dbl(data['price']),
  );

  Map<String, dynamic> toMap() => {
    'productId': productId,
    'sellerId': sellerId,
    'sellerUsername': sellerUsername,
    'productName': productName,
    'quantity': quantity,
    'price': price,
    'lineTotal': lineTotal,
  };
}

/// An order placed by a buyer. The document id *is* the order number.
///
/// Every order is cash on delivery and delivered to the buyer's hostel room,
/// so there are no payment or fulfilment fields to get out of step.
class Order {
  const Order({
    required this.orderNumber,
    required this.userId,
    required this.fullName,
    required this.email,
    required this.phone,
    required this.building,
    required this.roomNumber,
    required this.deliveryNotes,
    required this.total,
    required this.status,
    required this.items,
    required this.sellerIds,
    this.createdAt,
  });

  final String orderNumber;
  final String userId;
  final String fullName;
  final String email;
  final String phone;
  final String building;
  final String roomNumber;
  final String deliveryNotes;

  final double total;
  final OrderStatus status;
  final List<OrderItem> items;

  /// Distinct seller uids, so "my sales" is a single `array-contains` query.
  final List<String> sellerIds;
  final DateTime? createdAt;

  bool get isCancellable => status == OrderStatus.pending;

  /// Where the seller has to take this order.
  String get deliveryAddress {
    final parts = [
      if (building.trim().isNotEmpty) building.trim(),
      if (roomNumber.trim().isNotEmpty) 'room ${roomNumber.trim()}',
    ];
    return parts.join(', ');
  }

  factory Order.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) =>
      Order.fromMap(doc.id, doc.data() ?? const {});

  factory Order.fromMap(String id, Map<String, dynamic> data) => Order(
    orderNumber: Codec.str(data['orderNumber'], id),
    userId: Codec.str(data['userId']),
    fullName: Codec.str(data['fullName']),
    email: Codec.str(data['email']),
    phone: Codec.str(data['phone']),
    building: Codec.str(data['building']),
    roomNumber: Codec.str(data['roomNumber']),
    deliveryNotes: Codec.str(data['deliveryNotes']),
    total: Codec.dbl(data['total']),
    status: OrderStatus.from(data['status']),
    items: Codec.maps(data['items']).map(OrderItem.fromMap).toList(),
    sellerIds: Codec.strings(data['sellerIds']),
    createdAt: Codec.date(data['createdAt']),
  );
}
