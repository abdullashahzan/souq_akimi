import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/app_config.dart';
import '../../models/product.dart';
import '../collections.dart';

/// Reads and writes the `products` collection.
class ProductRepository {
  ProductRepository({FirebaseFirestore? db})
    : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection(Col.products);

  /// Live catalogue of active listings, newest first.
  ///
  /// The whole active catalogue (up to `searchCatalogueLimit`) is streamed so
  /// the smart search can rank it on-device.
  Stream<List<Product>> watchActive({int? limit}) => _col
      .where('isActive', isEqualTo: true)
      .orderBy('createdAt', descending: true)
      .limit(limit ?? AppConfig.searchCatalogueLimit)
      .snapshots()
      .map((snap) => snap.docs.map(Product.fromDoc).toList());

  /// A seller's own listings, including inactive ones.
  Stream<List<Product>> watchBySeller(String sellerId) => _col
      .where('sellerId', isEqualTo: sellerId)
      .orderBy('createdAt', descending: true)
      .limit(AppConfig.searchCatalogueLimit)
      .snapshots()
      .map((snap) => snap.docs.map(Product.fromDoc).toList());

  Stream<Product?> watchOne(String id) => _col
      .doc(id)
      .snapshots()
      .map((snap) => snap.exists ? Product.fromDoc(snap) : null);

  Future<Product?> getById(String id) async {
    final snap = await _col.doc(id).get();
    return snap.exists ? Product.fromDoc(snap) : null;
  }

  /// Create a listing and return its new id.
  Future<String> create(Product draft) async {
    final ref = _col.doc();
    final data = draft.toMap()
      ..['createdAt'] = FieldValue.serverTimestamp()
      ..['updatedAt'] = FieldValue.serverTimestamp();
    await ref.set(data);
    return ref.id;
  }

  Future<void> update(Product product) =>
      _col.doc(product.id).update(product.toMap());

  Future<void> delete(String id) => _col.doc(id).delete();

  /// Best-effort view counter. The security rules only permit this exact
  /// `+1` on `viewsCount`, and a failure is never worth interrupting a browse.
  Future<void> recordView(String id) async {
    try {
      await _col.doc(id).update({'viewsCount': FieldValue.increment(1)});
    } catch (_) {
      // Ignored: analytics must never break the UI.
    }
  }
}
