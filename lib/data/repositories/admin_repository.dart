import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/app_notification.dart';
import '../../models/product.dart';
import '../../models/service.dart';
import '../collections.dart';
import 'image_store.dart';

/// Marketplace-wide reads and moderation actions for the admin dashboard.
///
/// Access is re-checked by `firestore.rules` using the admin's verified email;
/// hiding the dashboard link is never the security boundary.
class AdminRepository {
  AdminRepository({FirebaseFirestore? db, ImageStore? images})
    : _db = db ?? FirebaseFirestore.instance,
      _images = images ?? ImageStore();

  final FirebaseFirestore _db;
  final ImageStore _images;

  CollectionReference<Map<String, dynamic>> get _products =>
      _db.collection(Col.products);
  CollectionReference<Map<String, dynamic>> get _services =>
      _db.collection(Col.services);

  /// Every listing, including paused ones. Admin-only UI; capped so the
  /// dashboard stays light on the Spark plan.
  Stream<List<Product>> watchProducts({int limit = 200}) => _products
      .orderBy('createdAt', descending: true)
      .limit(limit)
      .snapshots()
      .map((snap) => snap.docs.map(Product.fromDoc).toList(growable: false));

  Stream<List<Service>> watchServices({int limit = 200}) => _services
      .orderBy('createdAt', descending: true)
      .limit(limit)
      .snapshots()
      .map((snap) => snap.docs.map(Service.fromDoc).toList(growable: false));

  Future<AdminStats> stats() async {
    final results = await Future.wait([
      _count(Col.users),
      _count(Col.products),
      _count(Col.services),
      _count(Col.orders),
      _count(Col.serviceRequests, field: 'status', value: 'pending'),
      _count(Col.products, field: 'isActive', value: true),
      _count(Col.services, field: 'isActive', value: true),
    ]);
    return AdminStats(
      users: results[0],
      products: results[1],
      services: results[2],
      orders: results[3],
      pendingRequests: results[4],
      activeProducts: results[5],
      activeServices: results[6],
    );
  }

  Future<int> _count(String collection, {String? field, Object? value}) async {
    Query<Map<String, dynamic>> query = _db.collection(collection);
    if (field != null) query = query.where(field, isEqualTo: value);
    final snapshot = await query.count().get();
    return snapshot.count ?? 0;
  }

  Future<void> removeProduct(Product product) async {
    await _products.doc(product.id).delete();
    await _images.deleteAll(product.images);
  }

  Future<void> setProductActive(String id, bool active) => _products
      .doc(id)
      .update({'isActive': active, 'updatedAt': FieldValue.serverTimestamp()});

  Future<void> setServiceActive(String id, bool active) => _services
      .doc(id)
      .update({'isActive': active, 'updatedAt': FieldValue.serverTimestamp()});

  Future<void> removeService(Service service) async {
    await _services.doc(service.id).delete();
    await _images.deleteAll(service.images);
  }

  /// Fan a single announcement into every user's inbox.
  ///
  /// Firestore allows 500 writes per batch; 400 leaves room for the index
  /// overhead and keeps each commit comfortably under the limit. Returns the
  /// number of inboxes written.
  Future<int> broadcast({
    required String adminUid,
    required String title,
    required String body,
  }) async {
    final users = await _db
        .collection(Col.users)
        .limit(1000)
        .get(const GetOptions(source: Source.server));
    if (users.docs.isEmpty) return 0;

    var sent = 0;
    for (var start = 0; start < users.docs.length; start += 400) {
      final end = (start + 400).clamp(0, users.docs.length);
      final batch = _db.batch();
      for (final user in users.docs.sublist(start, end)) {
        final ref = _db
            .collection(Col.users)
            .doc(user.id)
            .collection(Col.notifications)
            .doc();
        batch.set(ref, <String, Object?>{
          'id': ref.id,
          'userId': user.id,
          'actorId': adminUid,
          'actorUsername': 'Souq Akimi',
          'type': AppNotification.typeAnnouncement,
          'title': title.trim(),
          'body': body.trim(),
          'orderNumber': '',
          'requestId': '',
          'read': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
        sent++;
      }
      await batch.commit();
    }
    return sent;
  }
}

class AdminStats {
  const AdminStats({
    required this.users,
    required this.products,
    required this.services,
    required this.orders,
    required this.pendingRequests,
    required this.activeProducts,
    required this.activeServices,
  });

  final int users;
  final int products;
  final int services;
  final int orders;
  final int pendingRequests;
  final int activeProducts;
  final int activeServices;

  static const empty = AdminStats(
    users: 0,
    products: 0,
    services: 0,
    orders: 0,
    pendingRequests: 0,
    activeProducts: 0,
    activeServices: 0,
  );
}
