import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:souq_akimi/core/l10n.dart';
import 'package:souq_akimi/core/theme.dart';
import 'package:souq_akimi/features/shell/app_shell.dart';
import 'package:souq_akimi/models/product.dart';
import 'package:souq_akimi/providers/auth.dart';
import 'package:souq_akimi/providers/dependencies.dart';
import 'package:souq_akimi/providers/notifications.dart';
import 'package:souq_akimi/providers/sellers.dart';
import 'package:souq_akimi/widgets/product_card.dart';

void main() {
  tearDown(() => AppLocale.current = AppLanguage.english);

  test('Arabic brand uses alif, not ayn', () {
    AppLocale.current = AppLanguage.arabic;
    expect(translate('Souq Akimi'), 'سوق أكيمي');
    expect(translate('Souq Akimi'), isNot(contains('عكيمي')));
  });

  for (final width in [360.0, 800.0]) {
    testWidgets('floating navigation leaves room for content at width $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 960);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            unreadNotificationCountProvider.overrideWithValue(0),
            isSignedInProvider.overrideWithValue(false),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const AppShell(
              location: '/',
              child: Scaffold(body: Center(child: Text('Content is visible'))),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Content is visible'), findsOneWidget);
      expect(find.text('Browse'), findsOneWidget);
      expect(find.text('Sell'), findsOneWidget);
      expect(tester.getTopLeft(find.text('Browse')).dy, greaterThan(800));
    });
  }

  testWidgets('brand header has no subtitle', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(appBar: null, body: SouqAppBarTitle())),
    );
    expect(find.text('Souq Akimi'), findsOneWidget);
    expect(find.text('The campus marketplace'), findsNothing);
    expect(find.text('What would you like to sell?'), findsNothing);
  });

  testWidgets('product card fits a narrow phone grid with a large price', (
    tester,
  ) async {
    final product = Product.fromMap('sample', {
      'name': 'Student laptop with a long title',
      'price': 12345.67,
      'stock': 2,
      'sellerUsername': 'student',
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [visibleSellerSalesProvider.overrideWithValue({})],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 158,
                height: 310,
                child: ProductCard(product: product),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
