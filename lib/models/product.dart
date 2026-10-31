import 'package:cloud_firestore/cloud_firestore.dart';

import '../data/codec.dart';
import '../data/search/search_text.dart';
import 'enums.dart';

/// A second-hand (or new) item listed by a student. Mirrors
/// `souqapp.models.Product`.
class Product {
  const Product({
    required this.id,
    required this.sellerId,
    required this.sellerUsername,
    required this.name,
    required this.description,
    required this.tags,
    required this.price,
    required this.condition,
    required this.stock,
    required this.isActive,
    required this.images,
    required this.viewsCount,
    required this.soldCount,
    this.createdAt,
    this.updatedAt,
    this.searchText = '',
    this.searchTokens = const [],
  });

  final String id;
  final String sellerId;
  final String sellerUsername;
  final String name;
  final String description;

  /// Free-form keywords, lowercased.
  final List<String> tags;
  final double price;
  final Condition condition;
  final int stock;
  final bool isActive;

  /// Download URLs; the first is the cover.
  final List<String> images;
  final int viewsCount;
  final int soldCount;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// Denormalised lowercased blob used by the smart search (not shown).
  final String searchText;
  final List<String> searchTokens;

  /// `Product.is_in_stock`.
  bool get isInStock => isActive && stock > 0;

  String get coverImage => images.isEmpty ? '' : images.first;

  bool isOwnedBy(String? uid) => uid != null && uid == sellerId;

  /// The blob the listing should be saved with, rebuilt from live fields.
  String buildBlob() => buildSearchText(
    name: name,
    description: description,
    tags: tags.join(', '),
    sellerUsername: sellerUsername,
  );

  factory Product.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) =>
      Product.fromMap(doc.id, doc.data() ?? const {});

  factory Product.fromMap(String id, Map<String, dynamic> data) => Product(
    id: id,
    sellerId: Codec.str(data['sellerId']),
    sellerUsername: Codec.str(data['sellerUsername']),
    name: Codec.str(data['name']),
    description: Codec.str(data['description']),
    tags: Codec.strings(data['tags']),
    price: Codec.dbl(data['price']),
    condition: Condition.from(data['condition']),
    stock: Codec.integer(data['stock']),
    isActive: Codec.boolean(data['isActive'], true),
    images: Codec.strings(data['images']),
    viewsCount: Codec.integer(data['viewsCount']),
    soldCount: Codec.integer(data['soldCount']),
    createdAt: Codec.date(data['createdAt']),
    updatedAt: Codec.date(data['updatedAt']),
    searchText: Codec.str(data['searchText']),
    searchTokens: Codec.strings(data['searchTokens']),
  );

  /// Firestore payload. `searchText` / `searchTokens` are always rebuilt here
  /// so a listing can never be saved with a stale blob.
  Map<String, dynamic> toMap() {
    final blob = buildBlob();
    return {
      'sellerId': sellerId,
      'sellerUsername': sellerUsername,
      'name': name,
      'description': description,
      'tags': tags,
      'price': price,
      'condition': condition.value,
      'stock': stock,
      'isActive': isActive,
      'images': images,
      'coverImage': coverImage,
      'viewsCount': viewsCount,
      'soldCount': soldCount,
      'searchText': blob,
      'searchTokens': searchTokensOf(blob),
    };
  }

  Product copyWith({
    String? name,
    String? description,
    List<String>? tags,
    double? price,
    Condition? condition,
    int? stock,
    bool? isActive,
    List<String>? images,
    int? viewsCount,
    int? soldCount,
  }) => Product(
    id: id,
    sellerId: sellerId,
    sellerUsername: sellerUsername,
    name: name ?? this.name,
    description: description ?? this.description,
    tags: tags ?? this.tags,
    price: price ?? this.price,
    condition: condition ?? this.condition,
    stock: stock ?? this.stock,
    isActive: isActive ?? this.isActive,
    images: images ?? this.images,
    viewsCount: viewsCount ?? this.viewsCount,
    soldCount: soldCount ?? this.soldCount,
    createdAt: createdAt,
    updatedAt: updatedAt,
    searchText: searchText,
    searchTokens: searchTokens,
  );
}
