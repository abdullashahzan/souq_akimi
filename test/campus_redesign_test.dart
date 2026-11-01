import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:souq_akimi/core/l10n.dart';
import 'package:souq_akimi/core/theme.dart';
import 'package:souq_akimi/data/repositories/product_repository.dart';
import 'package:souq_akimi/features/browse/browse_screen.dart';
import 'package:souq_akimi/features/product/product_detail_screen.dart';
import 'package:souq_akimi/models/app_user.dart';
import 'package:souq_akimi/models/enums.dart';
import 'package:souq_akimi/models/product.dart';
import 'package:souq_akimi/models/product_category.dart';
import 'package:souq_akimi/providers/auth.dart';
import 'package:souq_akimi/providers/catalogue.dart';
import 'package:souq_akimi/providers/dependencies.dart';
import 'package:souq_akimi/providers/notifications.dart';
import 'package:souq_akimi/providers/sellers.dart';
import 'package:souq_akimi/widgets/campus_banner.dart';
import 'package:souq_akimi/widgets/product_card.dart';
import 'package:souq_akimi/widgets/notification_alerts.dart';

final _samples = <Product>[
  Product.fromMap('laptop', {
    'name': 'Campus-ready laptop',
    'tags': ['tech', 'laptop'],
    'price': 850,
    'stock': 1,
    'isDemo': true,
  }),
  Product.fromMap('book', {
    'name': 'Weekend reading bundle',
    'tags': ['books', 'study'],
    'price': 45,
    'stock': 1,
    'isDemo': true,
  }),
];

class _ViewOnlyRepository implements ProductRepository {
  @override
  Future<void> recordView(String id) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  tearDown(() => AppLocale.current = AppLanguage.english);

  testWidgets('inbox tooltip follows an in-place language switch', (
    tester,
  ) async {
    final language = ValueNotifier(const Locale('en'));
    addTearDown(language.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [unreadNotificationCountProvider.overrideWithValue(0)],
        child: ValueListenableBuilder(
          valueListenable: language,
          builder: (_, locale, _) => MaterialApp(
            locale: locale,
            supportedLocales: const [Locale('en'), Locale('ar')],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: const Scaffold(body: InboxButton()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byTooltip('Notifications'), findsOneWidget);
    AppLocale.current = AppLanguage.arabic;
    language.value = const Locale('ar');
    await tester.pumpAndSettle();
    expect(find.byTooltip('الإشعارات'), findsOneWidget);
  });

  test(
    'old listings stay real; demo flag survives parsing, edits and saving',
    () {
      expect(Product.fromMap('old', {}).isDemo, isFalse);
      final demo = _samples.first.copyWith(name: 'Edited');
      expect(demo.isDemo, isTrue);
      expect(demo.toMap()['isDemo'], isTrue);
    },
  );

  test('category shortcuts match both Arabic and English listing metadata', () {
    expect(ProductCategory.tech.matches(_samples.first), isTrue);
    expect(ProductCategory.books.matches(_samples.first), isFalse);
    expect(
      ProductCategory.books.matches(
        Product.fromMap('mouse', {'name': 'Wireless study mouse'}),
      ),
      isFalse,
    );
    expect(
      ProductCategory.room.matches(
        Product.fromMap('keyboard', {'name': 'Desktop keyboard'}),
      ),
      isFalse,
    );
    expect(
      ProductCategory.room.matches(
        Product.fromMap('ar', {'name': 'كرسي جميل'}),
      ),
      isTrue,
    );
    expect(
      ProductCategory.tech.matches(
        Product.fromMap('ar', {
          'tags': ['سماعات'],
        }),
      ),
      isTrue,
    );
  });

  test(
    'category, condition and price filters combine without changing search',
    () {
      final container = ProviderContainer(
        overrides: [productCatalogueProvider.overrideWithValue(_samples)],
      );
      addTearDown(container.dispose);
      container
          .read(browseCategoryProvider.notifier)
          .select(ProductCategory.books);
      expect(container.read(filteredProductsProvider).single.id, 'book');
      container.read(browseFiltersProvider.notifier).setPriceRange(50, null);
      expect(container.read(filteredProductsProvider), isEmpty);
      container.read(browseFiltersProvider.notifier).reset();
      container
          .read(browseCategoryProvider.notifier)
          .select(ProductCategory.tech);
      container
          .read(browseFiltersProvider.notifier)
          .setCondition(Condition.brandNew);
      expect(container.read(filteredProductsProvider), isEmpty);
      expect(container.read(searchFiltersProvider).hasActiveFilters, isFalse);
      expect(container.read(searchFiltersProvider).query, isEmpty);
    },
  );

  for (final arabic in [false, true]) {
    for (final owner in [false, true]) {
      testWidgets('demo cannot be bought, owner=$owner, Arabic=$arabic', (
        tester,
      ) async {
        AppLocale.current = arabic ? AppLanguage.arabic : AppLanguage.english;
        final demo = Product.fromMap('demo', {
          'name': 'Campus-ready laptop',
          'price': 850,
          'stock': 1,
          'sellerId': 'owner',
          'sellerUsername': 'student',
          'isDemo': true,
        });
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              productByIdProvider('demo')
                  .overrideWith((ref) => Stream.value(demo)),
              productRepositoryProvider.overrideWithValue(
                _ViewOnlyRepository(),
              ),
              relatedProductsProvider('demo').overrideWithValue([]),
              currentUidProvider.overrideWithValue(owner ? 'owner' : null),
              sellerProfileProvider('owner')
                  .overrideWith((ref) => Stream.value(AppUser.empty('owner'))),
            ],
            child: MaterialApp(
              theme: AppTheme.light(),
              locale: Locale(arabic ? 'ar' : 'en'),
              supportedLocales: const [Locale('en'), Locale('ar')],
              localizationsDelegates: const [
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              home: const ProductDetailScreen(productId: 'demo'),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text(translate('Demo item')), findsOneWidget);
        expect(
          tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
          isNull,
        );
        expect(find.text(translate('Buy now')), findsNothing);
      });
    }

    for (final width in [360.0, 800.0]) {
      testWidgets('masthead fits $width, Arabic=$arabic, enlarged text', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width, 1200);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        AppLocale.current = arabic ? AppLanguage.arabic : AppLanguage.english;
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light(),
            locale: Locale(arabic ? 'ar' : 'en'),
            supportedLocales: const [Locale('en'), Locale('ar')],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: MediaQuery(
              data: MediaQueryData(
                size: Size(width, 1200),
                textScaler: const TextScaler.linear(1.5),
              ),
              child: const Scaffold(
                body: SingleChildScrollView(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: CampusBanner(search: SizedBox(height: 54)),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(
          find.byIcon(Icons.headphones_rounded),
          width >= 600 ? findsOneWidget : findsNothing,
        );
      });
    }

    testWidgets(
      'browse shortcuts filter and reset in ${arabic ? 'Arabic' : 'English'}',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1600);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        SharedPreferences.setMockInitialValues({
          'souq.locale': arabic ? 'ar' : 'en',
        });
        final prefs = await SharedPreferences.getInstance();
        AppLocale.current = arabic ? AppLanguage.arabic : AppLanguage.english;
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              sharedPreferencesProvider.overrideWithValue(prefs),
              isSignedInProvider.overrideWithValue(false),
              productsProvider.overrideWith((ref) => Stream.value(_samples)),
              visibleSellerSalesProvider.overrideWithValue({}),
            ],
            child: MaterialApp(
              theme: AppTheme.light(),
              locale: Locale(arabic ? 'ar' : 'en'),
              supportedLocales: const [Locale('en'), Locale('ar')],
              localizationsDelegates: const [
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              home: const BrowseScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(ProductCard), findsNWidgets(2));
        await tester.tap(find.text(translate('Tech')).first);
        await tester.pumpAndSettle();
        expect(find.byType(ProductCard), findsOneWidget);
        expect(find.text(translate('Campus-ready laptop')), findsOneWidget);
        await tester.tap(find.text(translate('All finds')));
        await tester.pumpAndSettle();
        expect(find.byType(ProductCard), findsNWidgets(2));
        expect(tester.takeException(), isNull);
      },
    );
  }
}
