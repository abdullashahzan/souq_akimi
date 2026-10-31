import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:souq_akimi/core/l10n.dart';
import 'package:souq_akimi/core/theme.dart';
import 'package:souq_akimi/data/repositories/admin_repository.dart';
import 'package:souq_akimi/features/admin/admin_screen.dart';
import 'package:souq_akimi/features/services/requests_screen.dart';
import 'package:souq_akimi/features/checkout/order_confirmation_screen.dart';
import 'package:souq_akimi/models/product.dart';
import 'package:souq_akimi/models/service.dart';
import 'package:souq_akimi/providers/admin.dart';
import 'package:souq_akimi/providers/auth.dart';
import 'package:souq_akimi/providers/dependencies.dart';
import 'package:souq_akimi/providers/notifications.dart';
import 'package:souq_akimi/providers/orders.dart';

class _AdminUser implements User {
  @override
  String get email => 'abdullashahzan@gmail.com';
  @override
  bool get emailVerified => true;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  tearDown(() => AppLocale.current = AppLanguage.english);
  for (final arabic in [false, true]) {
    for (final screen in ['admin', 'requests', 'confirmation']) {
      testWidgets(
        '$screen fits a small ${arabic ? 'Arabic' : 'English'} phone',
        (tester) async {
          tester.view.physicalSize = const Size(360, 640);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          AppLocale.current = arabic ? AppLanguage.arabic : AppLanguage.english;
          SharedPreferences.setMockInitialValues({
            'souq.locale': arabic ? 'ar' : 'en',
          });
          final prefs = await SharedPreferences.getInstance();
          final request = ServiceRequest.fromMap('focused', {
            'serviceId': 'service',
            'serviceTitle': 'Student printing and campus services',
            'providerUsername': 'provider',
            'requesterUsername': 'requester',
            'phone': '0500000000',
            'building': 'br10',
            'roomNumber': '101',
            'message': 'Please print three pages.',
            'status': 'accepted',
          });
          final router = GoRouter(
            initialLocation: '/?tab=received&request=focused',
            routes: [
              GoRoute(
                path: '/',
                builder: (_, _) => switch (screen) {
                  'admin' => const AdminScreen(),
                  'requests' => const RequestsScreen(),
                  _ => const OrderConfirmationScreen(orderNumber: 'QA123'),
                },
              ),
            ],
          );
          addTearDown(router.dispose);
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                sharedPreferencesProvider.overrideWithValue(prefs),
                authStateProvider.overrideWith(
                  (ref) => Stream.value(_AdminUser()),
                ),
                isAdminProvider.overrideWithValue(true),
                currentUidProvider.overrideWithValue('admin'),
                unreadNotificationCountProvider.overrideWithValue(0),
                adminStatsProvider.overrideWith(
                  (ref) async => AdminStats.empty,
                ),
                adminProductsProvider.overrideWith(
                  (ref) => Stream.value([
                    Product.fromMap('product', {
                      'name': 'Long product title for responsive moderation',
                      'price': 12345,
                      'isActive': true,
                    }),
                  ]),
                ),
                adminServicesProvider.overrideWith((ref) => Stream.value([])),
                incomingRequestsProvider.overrideWith(
                  (ref) => Stream.value([request]),
                ),
                outgoingRequestsProvider.overrideWith(
                  (ref) => Stream.value([]),
                ),
                orderProvider('QA123')
                    .overrideWith((ref) => Stream.value(null)),
              ],
              child: MaterialApp.router(
                theme: AppTheme.light(),
                routerConfig: router,
                locale: Locale(arabic ? 'ar' : 'en'),
                supportedLocales: const [Locale('en'), Locale('ar')],
                localizationsDelegates: const [
                  GlobalMaterialLocalizations.delegate,
                  GlobalWidgetsLocalizations.delegate,
                  GlobalCupertinoLocalizations.delegate,
                ],
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          if (screen == 'admin') {
            await tester.tap(
              find.text(arabic ? translate('Content') : 'Content'),
            );
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
            expect(find.byTooltip(translate('Pause listing')), findsOneWidget);
          }
          if (screen == 'requests') {
            expect(find.text(translate('Mark completed')), findsOneWidget);
            expect(find.text(translate('Decline')), findsNothing);
          }
        },
      );
    }
  }
}
