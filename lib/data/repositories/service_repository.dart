import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/app_config.dart';
import '../../core/l10n.dart';
import '../../models/app_notification.dart';
import '../../models/enums.dart';
import '../../models/service.dart';
import '../collections.dart';

/// Reads and writes `services` and `serviceRequests`.
class ServiceRepository {
  ServiceRepository({FirebaseFirestore? db})
    : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _services =>
      _db.collection(Col.services);
  CollectionReference<Map<String, dynamic>> get _requests =>
      _db.collection(Col.serviceRequests);

  // --- Listings -----------------------------------------------------------
  /// Live catalogue of active services, newest first.
  ///
  /// [limit] defaults to the full search window; the browse tab passes the
  /// smaller `browseCatalogueLimit` so its cold start stays cheap.
  Stream<List<Service>> watchActive({int? limit}) => _services
      .where('isActive', isEqualTo: true)
      .orderBy('createdAt', descending: true)
      .limit(limit ?? AppConfig.searchCatalogueLimit)
      .snapshots()
      .map((snap) => snap.docs.map(Service.fromDoc).toList());

  Stream<List<Service>> watchByProvider(String providerId) => _services
      .where('providerId', isEqualTo: providerId)
      .orderBy('createdAt', descending: true)
      .limit(AppConfig.searchCatalogueLimit)
      .snapshots()
      .map((snap) => snap.docs.map(Service.fromDoc).toList());

  Stream<Service?> watchOne(String id) => _services
      .doc(id)
      .snapshots()
      .map((snap) => snap.exists ? Service.fromDoc(snap) : null);

  Future<String> create(Service draft) async {
    final ref = _services.doc();
    final data = draft.toMap()
      ..['createdAt'] = FieldValue.serverTimestamp()
      ..['updatedAt'] = FieldValue.serverTimestamp();
    await ref.set(data);
    return ref.id;
  }

  Future<void> update(Service service) =>
      _services.doc(service.id).update(service.toMap());

  Future<void> delete(String id) => _services.doc(id).delete();

  Future<void> recordView(String id) async {
    try {
      await _services.doc(id).update({'viewsCount': FieldValue.increment(1)});
    } catch (_) {
      // Ignored: analytics must never break the UI.
    }
  }

  // --- Requests -----------------------------------------------------------
  /// A student asks for a service. Returns the new request id.
  Future<String> createRequest({
    required Service service,
    required String requesterId,
    required String requesterUsername,
    required String message,
    required String phone,
    required String building,
    required String roomNumber,
  }) async {
    final ref = _requests.doc();
    final request = ServiceRequest(
      id: ref.id,
      serviceId: service.id,
      serviceTitle: service.title,
      providerId: service.providerId,
      providerUsername: service.providerUsername,
      requesterId: requesterId,
      requesterUsername: requesterUsername,
      message: message.trim(),
      phone: phone.trim(),
      building: building.trim(),
      roomNumber: roomNumber.trim(),
      status: ServiceRequestStatus.pending,
    );
    // The request and the provider's inbox entry are born together: a request
    // the provider is never told about is exactly the bug this fixes.
    final inbox = _db
        .collection(Col.users)
        .doc(service.providerId)
        .collection(Col.notifications)
        .doc();
    await _db.runTransaction<void>((txn) async {
      final stamp = FieldValue.serverTimestamp();
      txn.set(ref, {...request.toMap(), 'createdAt': stamp});
      txn.set(inbox, <String, Object?>{
        'id': inbox.id,
        'userId': service.providerId,
        'actorId': requesterId,
        'actorUsername': requesterUsername,
        'type': AppNotification.typeServiceRequest,
        'title': translate('New service request'),
        'body': translate(
          '{requester} requested "{service}".',
          args: {
            'requester': requesterUsername,
            'service': service.title,
          },
        ),
        'orderNumber': '',
        'requestId': ref.id,
        'read': false,
        'createdAt': stamp,
      });
    });
    return ref.id;
  }

  /// Requests the student sent.
  Stream<List<ServiceRequest>> watchRequestsByRequester(String uid) => _requests
      .where('requesterId', isEqualTo: uid)
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((snap) => snap.docs.map(ServiceRequest.fromDoc).toList());

  /// Requests other students sent to this provider.
  Stream<List<ServiceRequest>> watchRequestsByProvider(String uid) => _requests
      .where('providerId', isEqualTo: uid)
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((snap) => snap.docs.map(ServiceRequest.fromDoc).toList());

  /// The provider accepts or declines; the requester may only cancel.
  Future<void> respond(String requestId, ServiceRequestStatus status) =>
      _requests.doc(requestId).update({
        'status': status.value,
        'respondedAt': FieldValue.serverTimestamp(),
      });

  Future<void> cancel(String requestId) => _requests.doc(requestId).update({
    'status': ServiceRequestStatus.cancelled.value,
  });
}
