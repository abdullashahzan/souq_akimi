import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:souq_akimi/core/theme.dart';
import 'package:souq_akimi/models/app_notification.dart';
import 'package:souq_akimi/providers/auth.dart';
import 'package:souq_akimi/providers/dependencies.dart';
import 'package:souq_akimi/providers/notifications.dart';
import 'package:souq_akimi/widgets/notification_alerts.dart';

AppNotification note(
  String id, {
  bool read = false,
  String user = 'seller',
  String type = 'service_request',
}) => AppNotification.fromMap(id, {
  'userId': user,
  'actorId': 'buyer',
  'type': type,
  'title': 'New service request',
  'body': 'Please print my notes.',
  'requestId': 'request1',
  'read': read,
});

void main() {
  test(
    'request notifications link to the correct role and specific request',
    () {
      expect(note('1').destination, '/requests?tab=received&request=request1');
      expect(
        note('2', type: 'request_accepted').destination,
        '/requests?tab=sent&request=request1',
      );
      expect(
        note('3', type: 'request_declined').destination,
        '/requests?tab=sent&request=request1',
      );
      expect(
        note('4', type: 'request_cancelled').destination,
        '/requests?tab=received&request=request1',
      );
      expect(
        note('5', type: 'request_completed').destination,
        '/requests?tab=sent&request=request1',
      );
    },
  );

  testWidgets(
    'unread request alerts immediately, dismisses and does not replay',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final stream = StreamController<List<AppNotification>>();
      addTearDown(stream.close);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            currentUidProvider.overrideWithValue('seller'),
            notificationsProvider.overrideWith((ref) => stream.stream),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const Scaffold(
              body: NotificationAlerts(
                child: Center(child: Text('Marketplace')),
              ),
            ),
          ),
        ),
      );
      stream.add([note('new')]);
      await tester.pumpAndSettle();
      expect(find.text('New service request'), findsOneWidget);
      await tester.tap(find.byTooltip('Dismiss'));
      await tester.pumpAndSettle();
      expect(find.text('New service request'), findsNothing);
      stream.add([note('new')]);
      await tester.pumpAndSettle();
      expect(find.text('New service request'), findsNothing);
      stream.add([note('new2'), note('new')]);
      await tester.pumpAndSettle();
      expect(find.text('New service request'), findsOneWidget);
      expect(
        prefs.getStringList('inbox.alerts.seller'),
        containsAll(['new', 'new2']),
      );
    },
  );

  testWidgets('read, other-account and locally seen items never alert', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'inbox.alerts.seller': ['seen'],
    });
    final prefs = await SharedPreferences.getInstance();
    final stream = StreamController<List<AppNotification>>();
    addTearDown(stream.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          currentUidProvider.overrideWithValue('seller'),
          notificationsProvider.overrideWith((ref) => stream.stream),
        ],
        child: const MaterialApp(
          home: Scaffold(body: NotificationAlerts(child: SizedBox())),
        ),
      ),
    );
    stream.add([
      note('read', read: true),
      note('foreign', user: 'someone'),
      note('seen'),
    ]);
    await tester.pumpAndSettle();
    expect(find.text('New service request'), findsNothing);
  });

  test(
    'Services badge counts requests, but not announcements or read items',
    () {
      final container = ProviderContainer(
        overrides: [
          notificationsProvider.overrideWith(
            (ref) => Stream.value([
              note('1'),
              note('2', type: 'request_accepted'),
              note('3', read: true),
              AppNotification.fromMap('4', {
                'type': 'announcement',
                'read': false,
              }),
            ]),
          ),
        ],
      );
      addTearDown(container.dispose);
      final subscription = container.listen(notificationsProvider, (_, _) {});
      addTearDown(subscription.close);
      return container.read(notificationsProvider.future).then((_) {
        expect(container.read(unreadServiceNotificationCountProvider), 2);
        expect(container.read(unreadNotificationCountProvider), 3);
      });
    },
  );
}
