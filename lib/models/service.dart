import 'package:cloud_firestore/cloud_firestore.dart';

import '../data/codec.dart';
import '../data/search/search_text.dart';
import 'enums.dart';

/// A service one student offers to another — the "do it for me" half of the
/// catalogue (delivery runs, homework help, printouts, tutoring…). Mirrors
/// `souqapp.models.Service`.
class Service {
  const Service({
    required this.id,
    required this.providerId,
    required this.providerUsername,
    required this.title,
    required this.category,
    required this.description,
    required this.tags,
    required this.price,
    required this.priceType,
    required this.images,
    required this.isActive,
    required this.viewsCount,
    this.createdAt,
    this.updatedAt,
    this.searchText = '',
    this.searchTokens = const [],
  });

  final String id;
  final String providerId;
  final String providerUsername;
  final String title;
  final ServiceCategory category;
  final String description;
  final List<String> tags;
  final double price;
  final PriceType priceType;

  /// Firestore image tokens or URLs. The first is the cover.
  final List<String> images;
  final bool isActive;
  final int viewsCount;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// Denormalised lowercased blob used by the smart search.
  final String searchText;
  final List<String> searchTokens;

  String get coverImage => images.isEmpty ? '' : images.first;

  bool isOwnedBy(String? uid) => uid != null && uid == providerId;

  String buildBlob() => buildSearchText(
    name: title,
    description: description,
    tags: tags.join(', '),
    sellerUsername: providerUsername,
  );

  factory Service.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) =>
      Service.fromMap(doc.id, doc.data() ?? const {});

  factory Service.fromMap(String id, Map<String, dynamic> data) => Service(
    id: id,
    providerId: Codec.str(data['providerId']),
    providerUsername: Codec.str(data['providerUsername']),
    title: Codec.str(data['title']),
    category: ServiceCategory.from(data['category']),
    description: Codec.str(data['description']),
    tags: Codec.strings(data['tags']),
    price: Codec.dbl(data['price']),
    priceType: PriceType.from(data['priceType']),
    images: _imagesFromMap(data),
    isActive: Codec.boolean(data['isActive'], true),
    viewsCount: Codec.integer(data['viewsCount']),
    createdAt: Codec.date(data['createdAt']),
    updatedAt: Codec.date(data['updatedAt']),
    searchText: Codec.str(data['searchText']),
    searchTokens: Codec.strings(data['searchTokens']),
  );

  Map<String, dynamic> toMap() {
    final blob = buildBlob();
    return {
      'providerId': providerId,
      'providerUsername': providerUsername,
      'title': title,
      'category': category.value,
      'description': description,
      'tags': tags,
      'price': price,
      'priceType': priceType.value,
      'images': images,
      'coverImage': coverImage,
      // Kept for older readers; the list above is authoritative.
      'image': coverImage,
      'isActive': isActive,
      'viewsCount': viewsCount,
      'searchText': blob,
      'searchTokens': searchTokensOf(blob),
    };
  }

  Service copyWith({
    String? title,
    ServiceCategory? category,
    String? description,
    List<String>? tags,
    double? price,
    PriceType? priceType,
    List<String>? images,
    bool? isActive,
    int? viewsCount,
  }) => Service(
    id: id,
    providerId: providerId,
    providerUsername: providerUsername,
    title: title ?? this.title,
    category: category ?? this.category,
    description: description ?? this.description,
    tags: tags ?? this.tags,
    price: price ?? this.price,
    priceType: priceType ?? this.priceType,
    images: images ?? this.images,
    isActive: isActive ?? this.isActive,
    viewsCount: viewsCount ?? this.viewsCount,
    createdAt: createdAt,
    updatedAt: updatedAt,
    searchText: searchText,
    searchTokens: searchTokens,
  );
}

List<String> _imagesFromMap(Map<String, dynamic> data) {
  final list = Codec.strings(data['images'])
      .where((value) => value.trim().isNotEmpty)
      .toList(growable: false);
  if (list.isNotEmpty) return list;
  final single = Codec.str(data['image']).trim();
  return single.isEmpty ? const <String>[] : <String>[single];
}

/// A student asking a provider to do their service. Mirrors
/// `souqapp.models.ServiceRequest`.
class ServiceRequest {
  const ServiceRequest({
    required this.id,
    required this.serviceId,
    required this.serviceTitle,
    required this.providerId,
    required this.providerUsername,
    required this.requesterId,
    required this.requesterUsername,
    required this.message,
    required this.phone,
    required this.building,
    required this.roomNumber,
    required this.status,
    this.createdAt,
    this.respondedAt,
  });

  final String id;
  final String serviceId;
  final String serviceTitle;
  final String providerId;
  final String providerUsername;
  final String requesterId;
  final String requesterUsername;
  final String message;

  /// Contact + delivery details captured with the brief, so the provider can
  /// reach the requester without a second conversation.
  final String phone;
  final String building;
  final String roomNumber;
  final ServiceRequestStatus status;
  final DateTime? createdAt;
  final DateTime? respondedAt;

  bool get isOpen => status.isOpen;

  factory ServiceRequest.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) =>
      ServiceRequest.fromMap(doc.id, doc.data() ?? const {});

  factory ServiceRequest.fromMap(String id, Map<String, dynamic> data) =>
      ServiceRequest(
        id: id,
        serviceId: Codec.str(data['serviceId']),
        serviceTitle: Codec.str(data['serviceTitle']),
        providerId: Codec.str(data['providerId']),
        providerUsername: Codec.str(data['providerUsername']),
        requesterId: Codec.str(data['requesterId']),
        requesterUsername: Codec.str(data['requesterUsername']),
        message: Codec.str(data['message']),
        phone: Codec.str(data['phone']),
        building: Codec.str(data['building']),
        roomNumber: Codec.str(data['roomNumber']),
        status: ServiceRequestStatus.from(data['status']),
        createdAt: Codec.date(data['createdAt']),
        respondedAt: Codec.date(data['respondedAt']),
      );

  Map<String, dynamic> toMap() => {
    'serviceId': serviceId,
    'serviceTitle': serviceTitle,
    'providerId': providerId,
    'providerUsername': providerUsername,
    'requesterId': requesterId,
    'requesterUsername': requesterUsername,
    'message': message,
    'phone': phone,
    'building': building,
    'roomNumber': roomNumber,
    'status': status.value,
    'respondedAt': Codec.stamp(respondedAt),
  };
}
