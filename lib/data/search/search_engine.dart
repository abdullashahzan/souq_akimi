import '../../models/enums.dart';
import '../../models/product.dart';
import '../../models/service.dart';
import 'query_parser.dart';
import 'search_text.dart';

/// Product & service search, ranking and display ordering.
///
/// A port of `souqapp/search.py`. The data volume on a campus catalogue is
/// small, so the synonym- and typo-aware layer runs against an in-memory list
/// fetched from Firestore. See `docs/firestore_schema.md` for the scale-up path.

/// The sort options offered in the UI (`SORT_CHOICES`).
const List<ProductSort> sortChoices = ProductSort.values;

typedef Cmp<T> = int Function(T a, T b);

void _sortBy<T>(List<T> items, List<Cmp<T>> comparators) {
  items.sort((a, b) {
    for (final compare in comparators) {
      final result = compare(a, b);
      if (result != 0) return result;
    }
    return 0;
  });
}

int _descInt(int a, int b) => b.compareTo(a);
int _descNum(num a, num b) => b.compareTo(a);
int _descStr(String a, String b) => b.compareTo(a);

DateTime _epoch(DateTime? at) => at ?? DateTime.fromMillisecondsSinceEpoch(0);
int _createdMillis(DateTime? at) => _epoch(at).millisecondsSinceEpoch;

// --------------------------------------------------------------------------- #
// Vocabulary (typo tolerance)
// --------------------------------------------------------------------------- #
Set<String> productVocabulary(List<Product> items) {
  final words = <String>{};
  for (final item in items) {
    words.addAll(
      item.searchTokens.isNotEmpty
          ? item.searchTokens
          : tokenize(item.searchText),
    );
  }
  return words;
}

Set<String> serviceVocabulary(List<Service> items) {
  final words = <String>{};
  for (final item in items) {
    words.addAll(
      item.searchTokens.isNotEmpty
          ? item.searchTokens
          : tokenize(item.searchText),
    );
  }
  return words;
}

// --------------------------------------------------------------------------- #
// Matching
// --------------------------------------------------------------------------- #
/// `searchText` is padded with a leading space, so a leading space anchors the
/// match to a word boundary: `' phone'` matches *phone* but not *headphones*.
bool _boundaryMatch(String searchText, Iterable<String> variants) {
  for (final variant in variants) {
    if (searchText.contains(' $variant')) return true;
  }
  return false;
}

bool _anySubstring(String haystack, Iterable<String> variants) {
  final lower = haystack.toLowerCase();
  for (final variant in variants) {
    if (lower.contains(variant)) return true;
  }
  return false;
}

// --------------------------------------------------------------------------- #
// Product comparators
// --------------------------------------------------------------------------- #
int _pInStockDesc(Product a, Product b) =>
    _descInt(a.isInStock ? 1 : 0, b.isInStock ? 1 : 0);
int _pCreatedDesc(Product a, Product b) =>
    _descNum(_createdMillis(a.createdAt), _createdMillis(b.createdAt));
int _pIdDesc(Product a, Product b) => _descStr(a.id, b.id);
int _pIdAsc(Product a, Product b) => a.id.compareTo(b.id);
int _pPriceAsc(Product a, Product b) => a.price.compareTo(b.price);
int _pPriceDesc(Product a, Product b) => b.price.compareTo(a.price);
int _pSoldDesc(Product a, Product b) => _descInt(a.soldCount, b.soldCount);
int _pViewsDesc(Product a, Product b) => _descInt(a.viewsCount, b.viewsCount);
int _pNameAsc(Product a, Product b) =>
    a.name.toLowerCase().compareTo(b.name.toLowerCase());

Cmp<Product> _pRelevance(String query) =>
    (a, b) =>
        _descNum(_productRelevance(a, query), _productRelevance(b, query));

/// `annotate_relevance` — first matching rung wins, exactly like `Case/When`.
num _productRelevance(Product item, String query) {
  final text = query.trim().toLowerCase();
  if (text.isEmpty) return 0;
  final name = item.name.toLowerCase();
  if (name == text) return 100;
  if (name.startsWith(text)) return 85;
  if (name.contains(text)) return 65;
  if (item.sellerUsername.toLowerCase() == text) return 55;
  if (item.description.toLowerCase().contains(text)) return 25;
  return 10;
}

List<Product> _orderProducts(
  List<Product> items,
  String query,
  ProductSort order,
) {
  final hasQuery = tokenize(query).isNotEmpty;

  switch (order) {
    case ProductSort.relevance:
      if (!hasQuery) {
        _sortBy<Product>(items, [_pInStockDesc, _pCreatedDesc, _pIdDesc]);
      } else {
        _sortBy<Product>(items, [
          _pRelevance(query),
          _pInStockDesc,
          _pCreatedDesc,
          _pIdDesc,
        ]);
      }
      return items;

    case ProductSort.priceAsc:
      _sortBy<Product>(items, [_pPriceAsc, _pCreatedDesc, _pIdAsc]);
      return items;

    case ProductSort.priceDesc:
      _sortBy<Product>(items, [_pPriceDesc, _pCreatedDesc, _pIdAsc]);
      return items;

    case ProductSort.topSale:
      _sortBy<Product>(items, [
        _pSoldDesc,
        _pViewsDesc,
        _pCreatedDesc,
        _pIdAsc,
      ]);
      return items;

    case ProductSort.mostViewed:
      _sortBy<Product>(items, [_pViewsDesc, _pCreatedDesc, _pIdAsc]);
      return items;

    case ProductSort.name:
      _sortBy<Product>(items, [_pNameAsc, _pIdAsc]);
      return items;

    case ProductSort.newest:
      _sortBy<Product>(items, [_pCreatedDesc, _pIdAsc]);
      return items;
  }
}

// --------------------------------------------------------------------------- #
// Service comparators
// --------------------------------------------------------------------------- #
int _sCreatedDesc(Service a, Service b) =>
    _descNum(_createdMillis(a.createdAt), _createdMillis(b.createdAt));
int _sIdAsc(Service a, Service b) => a.id.compareTo(b.id);
int _sViewsDesc(Service a, Service b) => _descInt(a.viewsCount, b.viewsCount);

/// `_order_services` — a plain relevance ladder (no stock or condition).
List<Service> _orderServices(
  List<Service> items,
  ParsedQuery parsed,
  Set<String> vocab,
) {
  if (parsed.terms.isEmpty) {
    _sortBy<Service>(items, [_sCreatedDesc, _sIdAsc]);
    return items;
  }

  final groups = expandTermGroups(parsed, vocab);
  final phrase = parsed.terms.join(' ');

  int exact(Service s) => s.title.toLowerCase() == phrase ? 1 : 0;
  int phraseHit(Service s) => s.title.toLowerCase().contains(phrase) ? 1 : 0;
  int variantHit(Service s) {
    for (final variants in groups) {
      if (_anySubstring(s.title, variants)) return 1;
    }
    return 0;
  }

  _sortBy<Service>(items, [
    (a, b) => _descInt(exact(a), exact(b)),
    (a, b) => _descInt(phraseHit(a), phraseHit(b)),
    (a, b) => _descInt(variantHit(a), variantHit(b)),
    _sViewsDesc,
    _sCreatedDesc,
    _sIdAsc,
  ]);
  return items;
}

// --------------------------------------------------------------------------- #
// Public API — products
// --------------------------------------------------------------------------- #
/// The smart search used by the browse & search screens.
///
/// Applies parsed constraints (price, condition hints), explicit filters and an
/// expanded, synonym/typo-aware text filter, then ranks.
List<Product> searchProducts(
  List<Product> catalogue,
  String raw, {
  ProductSort? sort,
  Condition? condition,
  double? priceMin,
  double? priceMax,
}) {
  final parsed = parseQuery(raw);
  var results = catalogue.where((p) => p.isActive).toList();

  if (condition != null) {
    results = results.where((p) => p.condition == condition).toList();
  }

  final low = priceMin ?? parsed.priceMin;
  final high = priceMax ?? parsed.priceMax;
  if (low != null) results = results.where((p) => p.price >= low).toList();
  if (high != null) results = results.where((p) => p.price <= high).toList();

  final vocab = productVocabulary(catalogue);
  final groups = expandTermGroups(parsed, vocab);
  if (groups.isNotEmpty) {
    results = results
        .where((p) => groups.every((g) => _boundaryMatch(p.searchText, g)))
        .toList();
  }

  for (final phrase in parsed.phrases) {
    results = results.where((p) => p.searchText.contains(' $phrase')).toList();
  }

  final queryText = parsed.terms.join(' ');

  // Explicit sort wins, then a sort hinted by the query ("cheap"), then the
  // default relevance ladder when there are terms, else the display order.
  if (sort != null) return _orderProducts(results, queryText, sort);
  if (parsed.sortHint == 'price_asc') {
    return _orderProducts(results, queryText, ProductSort.priceAsc);
  }
  if (parsed.sortHint == 'price_desc') {
    return _orderProducts(results, queryText, ProductSort.priceDesc);
  }
  if (parsed.terms.isEmpty) {
    return _orderProducts(results, '', ProductSort.relevance);
  }

  final nameVariants = <String>[for (final group in groups) ...group];
  int nameHit(Product p) => _anySubstring(p.name, nameVariants) ? 1 : 0;
  int exactHit(Product p) => p.name.toLowerCase() == queryText ? 1 : 0;
  int phraseHit(Product p) => p.name.toLowerCase().contains(queryText) ? 1 : 0;
  int conditionHit(Product p) =>
      parsed.conditionPref != null && p.condition == parsed.conditionPref
      ? 1
      : 0;

  _sortBy<Product>(results, [
    (a, b) => _descInt(exactHit(a), exactHit(b)),
    (a, b) => _descInt(phraseHit(a), phraseHit(b)),
    (a, b) => _descInt(nameHit(a), nameHit(b)),
    (a, b) => _descInt(conditionHit(a), conditionHit(b)),
    _pInStockDesc,
    _pViewsDesc,
    _pCreatedDesc,
  ]);
  return results;
}

// --------------------------------------------------------------------------- #
// Public API — services
// --------------------------------------------------------------------------- #
/// The services filter: a text query plus category and price range. Mirrors
/// [searchProducts] so a search behaves the same whichever tab you are on.
List<Service> searchServices(
  List<Service> catalogue,
  String raw, {
  ServiceCategory? category,
  double? priceMin,
  double? priceMax,
}) {
  final parsed = parseQuery(raw);
  var results = catalogue.where((s) => s.isActive).toList();

  if (category != null) {
    results = results.where((s) => s.category == category).toList();
  }

  final low = priceMin ?? parsed.priceMin;
  final high = priceMax ?? parsed.priceMax;
  if (low != null) results = results.where((s) => s.price >= low).toList();
  if (high != null) results = results.where((s) => s.price <= high).toList();

  final vocab = serviceVocabulary(catalogue);
  final groups = expandTermGroups(parsed, vocab);
  if (groups.isNotEmpty) {
    results = results
        .where((s) => groups.every((g) => _boundaryMatch(s.searchText, g)))
        .toList();
  }

  for (final phrase in parsed.phrases) {
    results = results.where((s) => s.searchText.contains(' $phrase')).toList();
  }

  return _orderServices(results, parsed, vocab);
}

// --------------------------------------------------------------------------- #
// Suggestions (search-as-you-type)
// --------------------------------------------------------------------------- #
/// A row in the suggestion dropdown.
class SearchSuggestion {
  const SearchSuggestion({
    required this.id,
    required this.title,
    required this.price,
    required this.image,
    required this.isService,
  });

  final String id;
  final String title;
  final double price;
  final String image;
  final bool isService;
}

/// Build the payload for the search-as-you-type dropdown.
({String corrected, List<SearchSuggestion> items}) suggest(
  List<Product> products,
  List<Service> services,
  String raw, {
  int limit = 6,
}) {
  final query = raw.trim();
  if (query.length < 2) {
    return (corrected: '', items: const <SearchSuggestion>[]);
  }

  final items = <SearchSuggestion>[];
  for (final product in searchProducts(products, query)) {
    if (items.length >= limit) break;
    items.add(
      SearchSuggestion(
        id: product.id,
        title: product.name,
        price: product.price,
        image: product.coverImage,
        isService: false,
      ),
    );
  }
  for (final service in searchServices(services, query)) {
    if (items.length >= limit) break;
    items.add(
      SearchSuggestion(
        id: service.id,
        title: service.title,
        price: service.price,
        image: service.coverImage,
        isService: true,
      ),
    );
  }

  return (
    corrected: didYouMean(query, productVocabulary(products)),
    items: items,
  );
}
