import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/app_notification.dart';
import '../../models/product.dart';
import '../../models/service.dart';
import '../../models/app_control.dart';
import '../../core/app_config.dart';
import '../../core/souq_exception.dart';
import '../collections.dart';
import 'image_store.dart';
import '../search/search_text.dart';

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

  Stream<List<AdminUser>> watchUsers({int limit = 200}) => _db
      .collection(Col.users)
      .orderBy(FieldPath.documentId)
      .limit(limit)
      .snapshots()
      .map((snap) => snap.docs.map(AdminUser.fromDoc).toList());

  Stream<Map<String, UserAccess>> watchAccess() => _db
      .collection('userAccess')
      .snapshots()
      .map(
        (snap) => {
          for (final doc in snap.docs) doc.id: UserAccess.fromMap(doc.data()),
        },
      );

  Stream<List<Map<String, dynamic>>> watchAudit() => _db
      .collection('adminAudit')
      .orderBy('createdAt', descending: true)
      .limit(50)
      .snapshots()
      .map((snap) => snap.docs.map((doc) => doc.data()).toList());

  Stream<List<Map<String, dynamic>>> watchRecords({
    required bool requests,
    int limit = 200,
  }) => _db
      .collection(requests ? Col.serviceRequests : Col.orders)
      .orderBy('createdAt', descending: true)
      .limit(limit)
      .snapshots()
      .map(
        (snap) => snap.docs
            .map((doc) => {...doc.data(), '_documentId': doc.id})
            .toList(),
      );

  /// Restrict first: a partial cleanup can never restore the target's access.
  /// This removes marketplace data, not Firebase Authentication credentials.
  Future<void> moderateUser({
    required AdminUser user,
    required String actorUid,
    required String status,
    required String reason,
  }) async {
    if (user.uid == actorUid || user.uid == AppConfig.adminUid) {
      throw const SouqException('The administrator account is protected.');
    }
    if (!['active', 'suspended', 'deleted'].contains(status) ||
        reason.trim().isEmpty) {
      throw const SouqException('A moderation reason is required.');
    }
    final access = _db.doc('userAccess/${user.uid}');
    await _db.runTransaction((tx) async {
      final before = await tx.get(access);
      if (before.data()?['status'] == 'deleted' && status != 'deleted') {
        throw const SouqException('A removed profile cannot be restored.');
      }
      tx.set(access, {
        'status': status,
        'reason': reason.trim(),
        'actorId': actorUid,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      tx.set(_db.collection('adminAudit').doc(), {
        'action': 'user.$status',
        'targetId': user.uid,
        'actorId': actorUid,
        'reason': reason.trim(),
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
    if (status == 'active') return;
    for (final entry in [
      (Col.products, 'sellerId'),
      (Col.services, 'providerId'),
    ]) {
      while (true) {
        final query = _db
            .collection(entry.$1)
            .where(entry.$2, isEqualTo: user.uid);
        final snap =
            await (status == 'deleted'
                    ? query
                    : query.where('isActive', isEqualTo: true))
                .limit(100)
                .get(const GetOptions(source: Source.server));
        if (snap.docs.isEmpty) break;
        final batch = _db.batch();
        for (final doc in snap.docs) {
          if (status == 'deleted') {
            batch.delete(doc.reference);
          } else {
            batch.update(doc.reference, {
              'isActive': false,
              'updatedAt': FieldValue.serverTimestamp(),
            });
          }
        }
        await batch.commit();
      }
    }
    if (status == 'deleted') {
      await _deleteQuery(
        _db.collection(Col.images).where('ownerId', isEqualTo: user.uid),
      );
      await _deleteQuery(
        _db.collection(Col.users).doc(user.uid).collection(Col.notifications),
      );
      await _db.collection(Col.users).doc(user.uid).delete();
      await _db.collection(Col.publicProfiles).doc(user.uid).delete();
    }
  }

  Future<void> _deleteQuery(Query<Map<String, dynamic>> query) async {
    while (true) {
      final snap = await query
          .limit(100)
          .get(const GetOptions(source: Source.server));
      if (snap.docs.isEmpty) return;
      final batch = _db.batch();
      for (final doc in snap.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }
  }

  Future<void> setMaintenance({
    required bool enabled,
    required String message,
    required String actorUid,
  }) async {
    final batch = _db.batch();
    batch.set(_db.doc('appConfig/control'), {
      'maintenance': enabled,
      'message': message.trim(),
      'actorId': actorUid,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    batch.set(_db.collection('adminAudit').doc(), {
      'action': 'maintenance.$enabled',
      'actorId': actorUid,
      'createdAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();
  }

  Future<void> publishMessage({
    required String adminUid,
    required String title,
    required String body,
    required bool everyLaunch,
  }) async {
    final history = _db.collection('announcements').doc();
    final data = {
      'id': history.id,
      'title': title.trim(),
      'body': body.trim(),
      'active': true,
      'everyLaunch': everyLaunch,
      'actorId': adminUid,
      'createdAt': FieldValue.serverTimestamp(),
    };
    final batch = _db.batch();
    batch.set(_db.doc('appConfig/launchMessage'), data);
    batch.set(history, data);
    batch.set(_db.collection('adminAudit').doc(), {
      'action': 'announcement.publish',
      'targetId': history.id,
      'actorId': adminUid,
      'createdAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();
  }

  Future<void> withdrawMessage(String actorUid) async {
    final batch = _db.batch();
    batch.set(_db.doc('appConfig/launchMessage'), {
      'active': false,
      'actorId': actorUid,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    batch.set(_db.collection('adminAudit').doc(), {
      'action': 'announcement.withdraw',
      'actorId': actorUid,
      'createdAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();
  }

  Future<void> editContent({
    required String id,
    required bool service,
    required String title,
    required String description,
    required num price,
    required int stock,
    required String actorUid,
  }) async {
    if (title.trim().isEmpty ||
        description.trim().isEmpty ||
        !price.isFinite ||
        price <= 0 ||
        stock < 0 ||
        stock > 999) {
      throw const SouqException(
        'Check the title, description, price and stock.',
      );
    }
    final target = _db
        .collection(service ? Col.services : Col.products)
        .doc(id);
    await _db.runTransaction((tx) async {
      final snapshot = await tx.get(target);
      final data = snapshot.data();
      if (data == null) throw const SouqException('Listing not found.');
      final blob = buildSearchText(
        name: title.trim(),
        description: description.trim(),
        tags: (data['tags'] as List? ?? []).join(', '),
        sellerUsername:
            '${data[service ? 'providerUsername' : 'sellerUsername'] ?? ''}',
      );
      tx.update(target, {
        if (service) 'title': title.trim() else 'name': title.trim(),
        'description': description.trim(),
        'price': price,
        if (!service) 'stock': stock,
        'searchText': blob,
        'searchTokens': searchTokensOf(blob),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      tx.set(_db.collection('adminAudit').doc(), {
        'action': 'content.edit',
        'targetId': id,
        'actorId': actorUid,
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
  }

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

  Future<void> _moderateContent(
    DocumentReference<Map<String, dynamic>> target,
    String action,
    String actorUid, [
    bool? active,
  ]) async {
    final batch = _db.batch();
    if (active == null) {
      batch.delete(target);
    } else {
      batch.update(target, {
        'isActive': active,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    batch.set(_db.collection('adminAudit').doc(), {
      'action': action,
      'targetId': target.path,
      'actorId': actorUid,
      'createdAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();
  }

  Future<void> removeProduct(
    Product product, {
    required String actorUid,
  }) async {
    await _moderateContent(
      _products.doc(product.id),
      'product.delete',
      actorUid,
    );
    await _images.deleteAll(product.images);
  }

  Future<void> setProductActive(
    String id,
    bool active, {
    required String actorUid,
  }) => _moderateContent(
    _products.doc(id),
    'product.active.$active',
    actorUid,
    active,
  );

  Future<void> setServiceActive(
    String id,
    bool active, {
    required String actorUid,
  }) => _moderateContent(
    _services.doc(id),
    'service.active.$active',
    actorUid,
    active,
  );

  Future<void> removeService(
    Service service, {
    required String actorUid,
  }) async {
    await _moderateContent(
      _services.doc(service.id),
      'service.delete',
      actorUid,
    );
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
