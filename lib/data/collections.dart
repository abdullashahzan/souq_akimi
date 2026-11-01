/// The single place every Firestore collection name is spelled, so a typo
/// can't silently query a non-existent collection.
class Col {
  const Col._();

  static const String users = 'users';
  static const String publicProfiles = 'publicProfiles';
  static const String products = 'products';
  static const String services = 'services';
  static const String serviceRequests = 'serviceRequests';
  static const String orders = 'orders';

  /// One delivery leg per seller in an order.
  static const String deliveries = 'deliveries';

  /// Buyer-only subcollection of an order holding each hand-over code. The
  /// seller is never allowed to read it (see `firestore.rules`).
  static const String deliverySecrets = 'deliverySecrets';

  /// Each user's in-app inbox: `users/{uid}/notifications/{id}`.
  static const String notifications = 'notifications';

  /// Firestore-hosted listing photos (see `ImageStore`).
  static const String images = 'images';
}
