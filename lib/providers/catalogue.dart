import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/app_config.dart';
import '../data/search/search_engine.dart';
import '../models/enums.dart';
import '../models/product.dart';
import '../models/product_category.dart';
import '../models/service.dart';
import 'auth.dart';
import 'dependencies.dart';

/// Sentinel so `copyWith` can distinguish "leave unchanged" from "set to null".
const Object _unset = Object();

// --------------------------------------------------------------------------- #
// Live catalogues
// --------------------------------------------------------------------------- #
/// The browse tab's window: the newest active listings, cheapest to stream.
final productsProvider = StreamProvider<List<Product>>(
  (ref) => ref
      .watch(productRepositoryProvider)
      .watchActive(limit: AppConfig.browseCatalogueLimit),
);

final servicesProvider = StreamProvider<List<Service>>(
  (ref) => ref
      .watch(serviceRepositoryProvider)
      .watchActive(limit: AppConfig.browseCatalogueLimit),
);

/// The search screen's wider window. Only subscribed once the buyer has typed
/// at least two characters, and auto-disposed when search closes, so simply
/// opening search never costs the 300-document read the wider catalogue needs
/// on Spark.
final searchProductsProvider = StreamProvider.autoDispose<List<Product>>(
  (ref) => ref.watch(productRepositoryProvider).watchActive(),
);

final searchServicesProvider = StreamProvider.autoDispose<List<Service>>(
  (ref) => ref.watch(serviceRepositoryProvider).watchActive(),
);

final searchProductCatalogueProvider = Provider.autoDispose<List<Product>>((
  ref,
) {
  if (ref.watch(searchFiltersProvider).query.trim().length < 2) {
    return const [];
  }
  return ref.watch(searchProductsProvider).value ?? const [];
});

final searchServiceCatalogueProvider = Provider.autoDispose<List<Service>>((
  ref,
) {
  if (ref.watch(searchFiltersProvider).query.trim().length < 2) {
    return const [];
  }
  return ref.watch(searchServicesProvider).value ?? const [];
});

/// The loaded catalogue as a plain list (empty while loading).
final productCatalogueProvider = Provider<List<Product>>(
  (ref) => ref.watch(productsProvider).value ?? const [],
);

final serviceCatalogueProvider = Provider<List<Service>>(
  (ref) => ref.watch(servicesProvider).value ?? const [],
);

/// A single listing, live (so stock edits show up immediately).
final productByIdProvider = StreamProvider.family<Product?, String>(
  (ref, id) => ref.watch(productRepositoryProvider).watchOne(id),
);

final serviceByIdProvider = StreamProvider.family<Service?, String>(
  (ref, id) => ref.watch(serviceRepositoryProvider).watchOne(id),
);

/// Related items: other listings from the same seller, or same-ish price band.
final relatedProductsProvider = Provider.family<List<Product>, String>((
  ref,
  productId,
) {
  final catalogue = ref.watch(productCatalogueProvider);
  final product = catalogue.where((p) => p.id == productId).firstOrNull;
  if (product == null) return const [];
  final related =
      catalogue.where((p) => p.id != productId && p.isInStock).toList()
        ..sort((a, b) {
          final sameSellerA = a.sellerId == product.sellerId ? 1 : 0;
          final sameSellerB = b.sellerId == product.sellerId ? 1 : 0;
          if (sameSellerA != sameSellerB) return sameSellerB - sameSellerA;
          final gapA = (a.price - product.price).abs();
          final gapB = (b.price - product.price).abs();
          return gapA.compareTo(gapB);
        });
  return related.take(6).toList();
});

// --------------------------------------------------------------------------- #
// The signed-in user's own listings
// --------------------------------------------------------------------------- #
final myProductsProvider = StreamProvider<List<Product>>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(const []);
  return ref.watch(productRepositoryProvider).watchBySeller(uid);
});

final myServicesProvider = StreamProvider<List<Service>>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(const []);
  return ref.watch(serviceRepositoryProvider).watchByProvider(uid);
});

// --------------------------------------------------------------------------- #
// Product search & filters
// --------------------------------------------------------------------------- #
/// The browse screen's query + filters.
class SearchFilters {
  const SearchFilters({
    this.query = '',
    this.sort = ProductSort.relevance,
    this.condition,
    this.priceMin,
    this.priceMax,
  });

  final String query;
  final ProductSort sort;
  final Condition? condition;
  final double? priceMin;
  final double? priceMax;

  bool get hasQuery => query.trim().isNotEmpty;
  bool get hasActiveFilters =>
      condition != null || priceMin != null || priceMax != null;

  SearchFilters copyWith({
    String? query,
    ProductSort? sort,
    Object? condition = _unset,
    Object? priceMin = _unset,
    Object? priceMax = _unset,
  }) => SearchFilters(
    query: query ?? this.query,
    sort: sort ?? this.sort,
    condition: identical(condition, _unset)
        ? this.condition
        : condition as Condition?,
    priceMin: identical(priceMin, _unset) ? this.priceMin : priceMin as double?,
    priceMax: identical(priceMax, _unset) ? this.priceMax : priceMax as double?,
  );

  SearchFilters cleared() => const SearchFilters();
}

class SearchFiltersNotifier extends Notifier<SearchFilters> {
  @override
  SearchFilters build() => const SearchFilters();

  void setQuery(String query) => state = state.copyWith(query: query);

  void setSort(ProductSort sort) => state = state.copyWith(sort: sort);

  void setCondition(Condition? condition) =>
      state = state.copyWith(condition: condition);

  void setPriceRange(double? min, double? max) =>
      state = state.copyWith(priceMin: min, priceMax: max);

  void clearFilters() =>
      state = state.copyWith(condition: null, priceMin: null, priceMax: null);

  void reset() => state = state.cleared();
}

final searchFiltersProvider =
    NotifierProvider<SearchFiltersNotifier, SearchFilters>(
      SearchFiltersNotifier.new,
    );

/// The browse tab's sort + condition. Kept apart from [searchFiltersProvider]
/// so typing in search never leaves the home catalogue filtered once the buyer
/// taps back.
final browseFiltersProvider =
    NotifierProvider<SearchFiltersNotifier, SearchFilters>(
      SearchFiltersNotifier.new,
    );

class BrowseCategoryNotifier extends Notifier<ProductCategory?> {
  @override
  ProductCategory? build() => null;

  void select(ProductCategory? category) => state = category;
}

final browseCategoryProvider =
    NotifierProvider<BrowseCategoryNotifier, ProductCategory?>(
      BrowseCategoryNotifier.new,
    );

/// The browse tab's catalogue filtered by its own sort + filter state.
final filteredProductsProvider = Provider<List<Product>>((ref) {
  final catalogue = ref.watch(productCatalogueProvider);
  final filters = ref.watch(browseFiltersProvider);
  final category = ref.watch(browseCategoryProvider);
  return searchProducts(
    category == null ? catalogue : catalogue.where(category.matches).toList(),
    filters.query,
    sort: filters.sort,
    condition: filters.condition,
    priceMin: filters.priceMin,
    priceMax: filters.priceMax,
  );
});

/// The same ranking, but over the wider search window.
final searchResultsProvider = Provider.autoDispose<List<Product>>((ref) {
  final catalogue = ref.watch(searchProductCatalogueProvider);
  final filters = ref.watch(searchFiltersProvider);
  return searchProducts(
    catalogue,
    filters.query,
    sort: filters.sort,
    condition: filters.condition,
    priceMin: filters.priceMin,
    priceMax: filters.priceMax,
  );
});

// --------------------------------------------------------------------------- #
// Service search & filters
// --------------------------------------------------------------------------- #
class ServiceFilters {
  const ServiceFilters({
    this.query = '',
    this.category,
    this.priceMin,
    this.priceMax,
  });

  final String query;
  final ServiceCategory? category;
  final double? priceMin;
  final double? priceMax;

  bool get hasActiveFilters =>
      category != null || priceMin != null || priceMax != null;

  ServiceFilters copyWith({
    String? query,
    Object? category = _unset,
    Object? priceMin = _unset,
    Object? priceMax = _unset,
  }) => ServiceFilters(
    query: query ?? this.query,
    category: identical(category, _unset)
        ? this.category
        : category as ServiceCategory?,
    priceMin: identical(priceMin, _unset) ? this.priceMin : priceMin as double?,
    priceMax: identical(priceMax, _unset) ? this.priceMax : priceMax as double?,
  );

  ServiceFilters cleared() => const ServiceFilters();
}

class ServiceFiltersNotifier extends Notifier<ServiceFilters> {
  @override
  ServiceFilters build() => const ServiceFilters();

  void setQuery(String query) => state = state.copyWith(query: query);

  void setCategory(ServiceCategory? category) =>
      state = state.copyWith(category: category);

  void setPriceRange(double? min, double? max) =>
      state = state.copyWith(priceMin: min, priceMax: max);

  void reset() => state = state.cleared();
}

final serviceFiltersProvider =
    NotifierProvider<ServiceFiltersNotifier, ServiceFilters>(
      ServiceFiltersNotifier.new,
    );

final filteredServicesProvider = Provider<List<Service>>((ref) {
  final catalogue = ref.watch(serviceCatalogueProvider);
  final filters = ref.watch(serviceFiltersProvider);
  return searchServices(
    catalogue,
    filters.query,
    category: filters.category,
    priceMin: filters.priceMin,
    priceMax: filters.priceMax,
  );
});

// --------------------------------------------------------------------------- #
// Search-as-you-type
// --------------------------------------------------------------------------- #
final searchSuggestionsProvider =
    Provider.autoDispose<({String corrected, List<SearchSuggestion> items})>((
      ref,
    ) {
      final query = ref.watch(searchFiltersProvider).query;
      if (query.trim().length < 2) {
        return (corrected: '', items: const <SearchSuggestion>[]);
      }
      return suggest(
        ref.watch(searchProductCatalogueProvider),
        ref.watch(searchServiceCatalogueProvider),
        query,
      );
    });

// --------------------------------------------------------------------------- #
// Recent searches (persisted)
// --------------------------------------------------------------------------- #
class RecentSearchesNotifier extends AsyncNotifier<List<String>> {
  static const String _key = 'souq.recent_searches';

  @override
  Future<List<String>> build() async {
    final prefs = ref.watch(sharedPreferencesProvider);
    return prefs.getStringList(_key) ?? const <String>[];
  }

  /// Remember a term (mirrors `record_search`: 2–60 chars, newest first).
  Future<void> add(String query) async {
    final term = query.trim().toLowerCase();
    if (term.length < 2 || term.length > 60) return;
    final current = state.value ?? const <String>[];
    final next = <String>[
      term,
      ...current.where((s) => s != term),
    ].take(AppConfig.maxRecentSearches).toList();
    state = AsyncData(next);
    await ref.read(sharedPreferencesProvider).setStringList(_key, next);
  }

  Future<void> clear() async {
    state = const AsyncData(<String>[]);
    await ref.read(sharedPreferencesProvider).remove(_key);
  }
}

final recentSearchesProvider =
    AsyncNotifierProvider<RecentSearchesNotifier, List<String>>(
      RecentSearchesNotifier.new,
    );
