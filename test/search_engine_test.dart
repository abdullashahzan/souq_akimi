import 'package:flutter_test/flutter_test.dart';
import 'package:souq_akimi/data/search/search_engine.dart';
import 'package:souq_akimi/data/search/search_text.dart';
import 'package:souq_akimi/models/enums.dart';
import 'package:souq_akimi/models/product.dart';
import 'package:souq_akimi/models/service.dart';

Product product({
  required String id,
  required String name,
  double price = 20,
  String description = '',
  List<String> tags = const [],
  String sellerUsername = 'seller',
  Condition condition = Condition.used,
  int stock = 3,
  bool isActive = true,
  int viewsCount = 0,
  int soldCount = 0,
  DateTime? createdAt,
}) {
  final blob = buildSearchText(
    name: name,
    description: description,
    tags: tags.join(', '),
    sellerUsername: sellerUsername,
  );
  return Product(
    id: id,
    sellerId: 'seller-$id',
    sellerUsername: sellerUsername,
    name: name,
    description: description,
    tags: tags,
    price: price,
    condition: condition,
    stock: stock,
    isActive: isActive,
    images: const [],
    viewsCount: viewsCount,
    soldCount: soldCount,
    createdAt: createdAt,
    searchText: blob,
    searchTokens: searchTokensOf(blob),
  );
}

Service service({
  required String id,
  required String title,
  ServiceCategory category = ServiceCategory.other,
  double price = 10,
  String description = '',
  List<String> tags = const [],
  bool isActive = true,
  int viewsCount = 0,
  DateTime? createdAt,
}) {
  final blob = buildSearchText(
    name: title,
    description: description,
    tags: tags.join(', '),
    sellerUsername: 'helper',
  );
  return Service(
    id: id,
    providerId: 'helper-$id',
    providerUsername: 'helper',
    title: title,
    category: category,
    description: description,
    tags: tags,
    price: price,
    priceType: PriceType.fixed,
    images: const [],
    isActive: isActive,
    viewsCount: viewsCount,
    createdAt: createdAt,
    searchText: blob,
    searchTokens: searchTokensOf(blob),
  );
}

List<String> names(List<Product> items) => [for (final p in items) p.name];
List<String> titles(List<Service> items) => [for (final s in items) s.title];

void main() {
  late List<Product> catalogue;

  setUp(() {
    catalogue = [
      product(
        id: 'p1',
        name: 'Laptop',
        price: 400,
        viewsCount: 90,
        createdAt: DateTime(2026, 1, 5),
      ),
      product(
        id: 'p2',
        name: 'Gaming Laptop',
        price: 650,
        viewsCount: 10,
        createdAt: DateTime(2026, 2, 1),
      ),
      product(
        id: 'p3',
        name: 'Phone Case',
        price: 8,
        tags: ['mobile'],
        createdAt: DateTime(2026, 1, 20),
      ),
      product(
        id: 'p4',
        name: 'Headphones',
        price: 45,
        createdAt: DateTime(2026, 1, 25),
      ),
      product(
        id: 'p5',
        name: 'Desk Lamp',
        price: 25,
        condition: Condition.brandNew,
        stock: 0,
        createdAt: DateTime(2026, 2, 10),
      ),
      product(
        id: 'p6',
        name: 'Brand New Laptop Sleeve',
        price: 15,
        condition: Condition.brandNew,
        createdAt: DateTime(2026, 2, 14),
      ),
    ];
  });

  group('matching', () {
    test('an exact name beats a partial match', () {
      final results = searchProducts(catalogue, 'laptop');
      expect(results.first.name, 'Laptop');
    });

    test('synonyms widen the match', () {
      // "mobile" is never in the product's blob, but its synonym "phone" is.
      final results = searchProducts(catalogue, 'mobile');
      expect(names(results), contains('Phone Case'));
    });

    test('matches only on word boundaries', () {
      // "phone" must not catch the "phone" inside "headphones".
      final results = searchProducts(catalogue, 'phone');
      expect(names(results), contains('Phone Case'));
      expect(names(results), isNot(contains('Headphones')));
    });

    test('typos still find the item', () {
      final results = searchProducts(catalogue, 'laptp');
      expect(names(results), contains('Laptop'));
      expect(names(results), contains('Gaming Laptop'));
    });

    test('every term must match', () {
      final results = searchProducts(catalogue, 'gaming laptop');
      expect(names(results), equals(['Gaming Laptop']));
    });

    test('a quoted phrase is matched as a whole', () {
      final results = searchProducts(catalogue, '"brand new laptop"');
      expect(names(results), equals(['Brand New Laptop Sleeve']));
    });

    test('paused listings never appear', () {
      catalogue.firstWhere((p) => p.id == 'p1');
      catalogue = [
        for (final p in catalogue)
          if (p.id != 'p1') p,
        product(id: 'p7', name: 'Retired Laptop', isActive: false),
      ];
      final results = searchProducts(catalogue, 'laptop');
      expect(names(results), isNot(contains('Retired Laptop')));
    });
  });

  group('constraints', () {
    test('a bare amount caps the budget', () {
      final results = searchProducts(catalogue, '\$50');
      expect(results, isNotEmpty);
      expect(results.every((p) => p.price <= 50), isTrue);
    });

    test('"over" sets a floor', () {
      final results = searchProducts(catalogue, 'over \$300');
      expect(results.every((p) => p.price >= 300), isTrue);
      expect(results.length, 2); // the two laptops
    });

    test('explicit filters beat what the query implies', () {
      final results = searchProducts(
        catalogue,
        'laptop',
        condition: Condition.brandNew,
      );
      expect(names(results), equals(['Brand New Laptop Sleeve']));
    });

    test('a price range can be passed directly', () {
      final results = searchProducts(catalogue, '', priceMin: 40, priceMax: 50);
      expect(names(results), equals(['Headphones']));
    });
  });

  group('ranking', () {
    test('the "cheap" hint sorts by ascending price', () {
      final results = searchProducts(catalogue, 'cheap laptop');
      final prices = [for (final p in results) p.price];
      expect(prices, List<double>.from(prices)..sort());
      expect(prices.first, 15); // the sleeve
    });

    test('an explicit sort overrides the query hint', () {
      final results = searchProducts(
        catalogue,
        'cheap laptop',
        sort: ProductSort.priceDesc,
      );
      expect(results.first.price, 650);
    });

    test('descending price sort works without a query', () {
      final results = searchProducts(
        catalogue,
        '',
        sort: ProductSort.priceDesc,
      );
      expect(results.first.price, 650);
      expect(results.last.price, 8);
    });

    test('name sort is alphabetical', () {
      final results = searchProducts(catalogue, '', sort: ProductSort.name);
      final sorted = names(results);
      final expected = List<String>.from(sorted)..sort();
      expect(sorted, expected);
    });

    test('top sales prefers the best seller', () {
      catalogue = [
        ...catalogue,
        product(id: 'p8', name: 'Charger', soldCount: 40),
        product(id: 'p9', name: 'Cable', soldCount: 5),
      ];
      final results = searchProducts(catalogue, '', sort: ProductSort.topSale);
      expect(results.first.name, 'Charger');
    });

    test('out of stock sinks below in-stock items on relevance', () {
      final results = searchProducts(catalogue, 'lamp');
      // The desk lamp is out of stock but is the only lamp — it still shows.
      expect(names(results), contains('Desk Lamp'));
      final mixed = searchProducts([
        ...catalogue,
        product(id: 'p10', name: 'Led Lamp', price: 30),
      ], 'lamp');
      expect(mixed.first.name, 'Led Lamp');
    });
  });

  group('services', () {
    late List<Service> offers;

    setUp(() {
      offers = [
        service(
          id: 's1',
          title: 'Printing & Binding',
          category: ServiceCategory.printing,
          price: 5,
          viewsCount: 12,
        ),
        service(
          id: 's2',
          title: 'Weekend Tutoring',
          category: ServiceCategory.tutoring,
          price: 15,
          viewsCount: 40,
        ),
        service(
          id: 's3',
          title: 'Campus Delivery Runs',
          category: ServiceCategory.delivery,
          price: 3,
        ),
        service(
          id: 's4',
          title: 'Assignment Writing Help',
          category: ServiceCategory.homework,
          price: 25,
        ),
      ];
    });

    test('the synonym map reaches across titles', () {
      final results = searchServices(offers, 'printout');
      expect(titles(results), contains('Printing & Binding'));
    });

    test('category narrows the list', () {
      final results = searchServices(
        offers,
        '',
        category: ServiceCategory.delivery,
      );
      expect(titles(results), equals(['Campus Delivery Runs']));
    });

    test('price bounds are respected', () {
      final results = searchServices(offers, 'under 10');
      expect(results.every((s) => s.price <= 10), isTrue);
      expect(titles(results), isNot(contains('Weekend Tutoring')));
    });

    test('an exact title outranks a partial one', () {
      final results = searchServices(offers, 'tutoring');
      expect(results.first.title, 'Weekend Tutoring');
    });

    test('services with no query fall back to newest first', () {
      final results = searchServices(offers, '');
      expect(titles(results), hasLength(offers.length));
    });
  });

  group('suggest', () {
    test('needs at least two characters', () {
      final result = suggest(catalogue, const [], 'l');
      expect(result.items, isEmpty);
      expect(result.corrected, '');
    });

    test('offers both products and services, capped', () {
      final offers = [
        service(id: 's1', title: 'Laptop Repair'),
        service(id: 's2', title: 'Laptop Cleaning'),
      ];
      final result = suggest(catalogue, offers, 'laptop', limit: 4);
      expect(result.items.length, 4);
      expect(result.items.any((s) => s.isService), isTrue);
      expect(result.items.any((s) => !s.isService), isTrue);
    });

    test('reports a corrected spelling', () {
      final result = suggest(catalogue, const [], 'laptp');
      expect(result.corrected, 'laptop');
    });
  });
}
