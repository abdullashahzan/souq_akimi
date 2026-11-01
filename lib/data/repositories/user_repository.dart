import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/app_user.dart';
import '../collections.dart';

/// Reads and writes the per-user profile document (`users/{uid}`).
class UserRepository {
  UserRepository({FirebaseFirestore? db})
    : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> _userRef(String uid) =>
      _db.collection(Col.users).doc(uid);

  /// Live profile. Emits an empty profile when the document does not exist yet,
  /// so the UI never has to handle a null user.
  Stream<AppUser> watch(String uid) => _userRef(uid).snapshots().map(
    (snap) => snap.exists
        ? AppUser.fromMap(uid, snap.data() ?? const {})
        : AppUser.empty(uid),
  );

  /// Live profiles for a handful of sellers (Firestore caps `whereIn` at 30).
  ///
  /// Used to show the public sales tally next to a seller's handle without
  /// denormalising the number onto every listing they own.
  Stream<Map<String, AppUser>> watchMany(List<String> uids) {
    if (uids.isEmpty) return Stream.value(const {});
    final ids = uids.take(30).toList(growable: false);
    return _db
        .collection(Col.publicProfiles)
        .where(FieldPath.documentId, whereIn: ids)
        .snapshots()
        .map(
          (snap) => {
            for (final doc in snap.docs)
              doc.id: AppUser.fromMap(doc.id, doc.data()),
          },
        );
  }

  Stream<AppUser> watchPublic(String uid) => _db
      .collection(Col.publicProfiles)
      .doc(uid)
      .snapshots()
      .map((doc) => AppUser.fromMap(uid, doc.data() ?? {}));

  Future<AppUser?> get(String uid) async {
    final snap = await _userRef(uid).get();
    if (!snap.exists) return null;
    return AppUser.fromMap(uid, snap.data() ?? const {});
  }

  /// Create the profile document on first sign-in/registration. Idempotent:
  /// existing values are never overwritten.
  Future<void> ensureProfile({
    required String uid,
    required String username,
    required String email,
    String? displayName,
  }) async {
    final ref = _userRef(uid);
    final snap = await ref.get();
    if (snap.exists) {
      await _db.collection(Col.publicProfiles).doc(uid).set({
        'username': snap.data()?['username'] ?? username,
        'salesCount': snap.data()?['salesCount'] ?? 0,
      });
      return;
    }
    final batch = _db.batch();
    batch.set(ref, {
      'uid': uid,
      'username': username,
      'email': email,
      'displayName': (displayName ?? username).trim(),
      'photoUrl': '',
      'phone': '',
      'building': '',
      'roomNumber': '',
      'salesCount': 0,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    batch.set(_db.collection(Col.publicProfiles).doc(uid), {
      'username': username,
      'salesCount': 0,
    });
    await batch.commit();
  }

  /// Save the editable profile fields.
  Future<void> completeOnboarding(String uid) => _userRef(uid).update({
    'onboardingCompleted': true,
    'updatedAt': FieldValue.serverTimestamp(),
  });

  /// Save the editable profile fields.
  Future<void> saveProfile(AppUser user) async {
    final batch = _db.batch();
    batch.set(_userRef(user.uid), user.toProfileMap(), SetOptions(merge: true));
    batch.set(_db.collection(Col.publicProfiles).doc(user.uid), {
      'username': user.username,
      'salesCount': user.salesCount,
    });
    await batch.commit();
  }

  /// Save just the details checkout remembers. Used after an order so the next
  /// checkout is already filled in.
  Future<void> saveDeliveryDetails({
    required String uid,
    String? displayName,
    required String phone,
    required String building,
    required String roomNumber,
  }) => _userRef(uid).set({
    if (displayName != null && displayName.trim().isNotEmpty)
      'displayName': displayName.trim(),
    'phone': phone.trim(),
    'building': building.trim(),
    'roomNumber': roomNumber.trim(),
    'updatedAt': FieldValue.serverTimestamp(),
  }, SetOptions(merge: true));
}
