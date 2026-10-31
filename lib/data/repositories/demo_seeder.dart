import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../core/souq_exception.dart';
import '../../models/product.dart';
import '../../models/service.dart';
import '../collections.dart';
import '../demo_seed_data.dart';

/// Dev helper: writes the sample catalogue into Firestore from the device.
///
/// This replaces the `seedDemoData` callable from `functions/src/seed.ts`: the
/// app runs on the Spark free tier, so there are no Cloud Functions to call.
/// The Admin SDK used to stamp any seller id it liked; security rules only let
/// a seller create their own listings, so every document is stamped with the
/// signed-in uid instead. Ids stay deterministic (`demo-product-{slug}`), so
/// re-running overwrites the same rows rather than duplicating them.
class DemoSeeder {
  DemoSeeder({FirebaseFirestore? db, FirebaseAuth? auth})
    : _db = db ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  CollectionReference<Map<String, dynamic>> get _users =>
      _db.collection(Col.users);
  CollectionReference<Map<String, dynamic>> get _products =>
      _db.collection(Col.products);
  CollectionReference<Map<String, dynamic>> get _services =>
      _db.collection(Col.services);

  /// Dev helper: write the sample catalogue into Firestore under the signed-in
  /// user's uid (security rules only let a seller create their own listings).
  ///
  /// Writes the first `count` seed products and every seed service in one
  /// batch — 36 writes at most, well inside Firestore's batch limit.
  Future<({int products, int services})> seed({int count = 20}) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw const SouqException(
        'Please sign in to continue.',
        code: 'unauthenticated',
      );
    }

    try {
      final username = await _usernameFor(user);
      final take = count.clamp(1, DemoSeedData.products.length).toInt();
      final batch = _db.batch();

      var products = 0;
      for (final item in DemoSeedData.products.take(take)) {
        final id = 'demo-product-${item.slug}';
        final product = Product(
          id: id,
          sellerId: user.uid,
          sellerUsername: username,
          name: item.name,
          description: item.description,
          tags: item.tags,
          price: item.price,
          condition: item.condition,
          stock: item.stock,
          isActive: true,
          images: _productImages(item.slug),
          viewsCount: 0,
          soldCount: 0,
        );
        // Merge so a re-run refreshes the row without touching anything a
        // later edit may have added.
        batch.set(
          _products.doc(id),
          _withServerStamps(product.toMap(), id),
          SetOptions(merge: true),
        );
        products++;
      }

      for (final item in DemoSeedData.services) {
        final id = 'demo-service-${item.slug}';
        final service = Service(
          id: id,
          providerId: user.uid,
          providerUsername: username,
          title: item.title,
          category: item.category,
          description: item.description,
          tags: item.tags,
          price: item.price,
          priceType: item.priceType,
          images: ['https://picsum.photos/seed/${item.slug}/900/675'],
          isActive: true,
          viewsCount: 0,
        );
        batch.set(
          _services.doc(id),
          _withServerStamps(service.toMap(), id),
          SetOptions(merge: true),
        );
      }

      await batch.commit();
      return (products: products, services: DemoSeedData.services.length);
    } on SouqException {
      rethrow;
    } on FirebaseException catch (error) {
      // A second account hits `permission-denied`: the existing catalogue
      // belongs to whoever seeded first, and rules forbid taking it over.
      throw SouqException(
        'Demo catalogue already exists — it was seeded by another account.',
        code: error.code,
      );
    }
  }

  /// The handle denormalised onto every listing: the profile username when the
  /// `users/{uid}` document exists, otherwise a slug minted from the auth email
  /// so a freshly registered account still seeds plausible seller names.
  Future<String> _usernameFor(User user) async {
    final snap = await _users.doc(user.uid).get();
    final raw = snap.data()?['username'];
    if (raw is String && raw.trim().isNotEmpty) return raw.trim();

    final local = user.email?.split('@').first.toLowerCase() ?? '';
    final slug = local
        .split(RegExp(r'[^a-z0-9]+'))
        .where((part) => part.isNotEmpty)
        .join('_');
    return slug.isEmpty ? 'seller' : slug;
  }

  /// The three placeholder photos `seed.ts` attached to every product; the
  /// first one doubles as the cover.
  static List<String> _productImages(String slug) => [
    for (var n = 1; n <= 3; n++) 'https://picsum.photos/seed/$slug-$n/900/675',
  ];

  /// A model payload plus the two fields `toMap()` deliberately omits: the
  /// document id (kept in sync so a payload always names itself) and
  /// server-side timestamps, exactly like `ProductRepository.create`.
  Map<String, dynamic> _withServerStamps(
    Map<String, dynamic> data,
    String id,
  ) => data
    ..['id'] = id
    ..['createdAt'] = FieldValue.serverTimestamp()
    ..['updatedAt'] = FieldValue.serverTimestamp();
}
