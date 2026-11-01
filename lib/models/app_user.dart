import 'package:cloud_firestore/cloud_firestore.dart';

import '../data/codec.dart';

/// The single per-user document: public identity plus the delivery details
/// checkout remembers. Mirrors `BuyerProfile` + `SellerProfile` in the Django
/// app, merged because they share one identity.
class AppUser {
  const AppUser({
    required this.uid,
    required this.username,
    required this.email,
    required this.displayName,
    required this.photoUrl,
    required this.phone,
    required this.building,
    required this.roomNumber,
    this.salesCount = 0,
    this.onboardingCompleted = false,
    this.createdAt,
    this.updatedAt,
  });

  final String uid;
  final String username;
  final String email;
  final String displayName;
  final String photoUrl;

  // --- Remembered delivery details ---------------------------------------
  final String phone;
  final String building;
  final String roomNumber;

  /// Completed deliveries. Public, so it can sit next to a seller's name.
  final int salesCount;
  final bool onboardingCompleted;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// A name safe to show anywhere.
  String get name => displayName.trim().isNotEmpty
      ? displayName.trim()
      : (username.trim().isNotEmpty ? username.trim() : 'Student');

  /// The saved delivery details that are actually filled in.
  Map<String, String> deliveryData() => {
    if (phone.trim().isNotEmpty) 'phone': phone,
    if (building.trim().isNotEmpty) 'building': building,
    if (roomNumber.trim().isNotEmpty) 'roomNumber': roomNumber,
  };

  /// Whether checkout can be prefilled completely: a phone, a building and a
  /// room. Used for the reassuring "remembered" subtitle in Profile.
  bool get hasCompleteDeliveryDetails =>
      phone.trim().isNotEmpty &&
      building.trim().isNotEmpty &&
      roomNumber.trim().isNotEmpty;

  factory AppUser.empty(String uid) => AppUser(
    uid: uid,
    username: '',
    email: '',
    displayName: '',
    photoUrl: '',
    phone: '',
    building: '',
    roomNumber: '',
    salesCount: 0,
  );

  factory AppUser.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) =>
      AppUser.fromMap(doc.id, doc.data() ?? const {});

  factory AppUser.fromMap(String id, Map<String, dynamic> data) => AppUser(
    uid: Codec.str(data['uid'], id),
    username: Codec.str(data['username']),
    email: Codec.str(data['email']),
    displayName: Codec.str(data['displayName']),
    photoUrl: Codec.str(data['photoUrl']),
    phone: Codec.str(data['phone']),
    building: Codec.str(data['building']),
    roomNumber: Codec.str(data['roomNumber']),
    salesCount: Codec.integer(data['salesCount']),
    onboardingCompleted: data['onboardingCompleted'] == true,
    createdAt: Codec.date(data['createdAt']),
    updatedAt: Codec.date(data['updatedAt']),
  );

  /// Only the mutable profile fields.
  Map<String, dynamic> toProfileMap() => {
    'uid': uid,
    'username': username,
    'email': email,
    'displayName': displayName,
    'photoUrl': photoUrl,
    'phone': phone,
    'building': building,
    'roomNumber': roomNumber,
    'updatedAt': FieldValue.serverTimestamp(),
  };

  AppUser copyWith({
    String? username,
    String? email,
    String? displayName,
    String? photoUrl,
    String? phone,
    String? building,
    String? roomNumber,
    int? salesCount,
  }) => AppUser(
    uid: uid,
    username: username ?? this.username,
    email: email ?? this.email,
    displayName: displayName ?? this.displayName,
    photoUrl: photoUrl ?? this.photoUrl,
    phone: phone ?? this.phone,
    building: building ?? this.building,
    roomNumber: roomNumber ?? this.roomNumber,
    salesCount: salesCount ?? this.salesCount,
    onboardingCompleted: onboardingCompleted,
    createdAt: createdAt,
    updatedAt: updatedAt,
  );
}
