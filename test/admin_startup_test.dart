import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:souq_akimi/core/l10n.dart';
import 'package:souq_akimi/core/theme.dart';
import 'package:souq_akimi/data/repositories/admin_repository.dart';
import 'package:souq_akimi/data/repositories/image_store.dart';
import 'package:souq_akimi/data/repositories/user_repository.dart';
import 'package:souq_akimi/features/admin/admin_management.dart';
import 'package:souq_akimi/features/admin/admin_screen.dart';
import 'package:souq_akimi/models/app_control.dart';
import 'package:souq_akimi/models/app_user.dart';
import 'package:souq_akimi/providers/admin.dart';
import 'package:souq_akimi/providers/app_control.dart';
import 'package:souq_akimi/providers/auth.dart';
import 'package:souq_akimi/providers/dependencies.dart';
import 'package:souq_akimi/providers/locale.dart';
import 'package:souq_akimi/widgets/startup_gate.dart';

class _Db implements FirebaseFirestore {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _User implements User {
  _User(this.uid);
  @override
  final String uid;
  @override
  String get email =>
      uid == 'admin' ? 'abdullashahzan@gmail.com' : '$uid@example.com';
  @override
  bool get emailVerified => true;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Users extends UserRepository {
  _Users() : super(db: _Db());
  final completed = <String>[];
  @override
  Future<void> completeOnboarding(String uid) async {
    completed.add(uid);
  }
}

class _Admin extends AdminRepository {
  _Admin()
    : super(
        db: _Db(),
        images: ImageStore(firestore: _Db()),
      );
  final actions = <String>[];
  String? published;
  @override
  Future<void> moderateUser({
    required AdminUser user,
    required String actorUid,
    required String status,
    required String reason,
  }) async {
    actions.add('${user.uid}:$status:$reason');
  }

  @override
  Future<void> publishMessage({
    required String adminUid,
    required String title,
    required String body,
    required bool everyLaunch,
  }) async {
    published = '$title|$body|$everyLaunch';
  }
}

Future<SharedPreferences> _prefs([
  Map<String, Object> values = const {},
]) async {
  SharedPreferences.setMockInitialValues(values);
  return SharedPreferences.getInstance();
}

Widget _app({
  required SharedPreferences prefs,
  Widget? child,
  User? user,
  LaunchMessage message = const LaunchMessage(id: '', title: '', body: ''),
  Stream<LaunchMessage>? messages,
  UserAccess access = const UserAccess(),
  bool complete = false,
  _Users? users,
  _Admin? admin,
  bool arabic = false,
  Stream<User?>? auth,
  AppControl control = const AppControl(),
}) {
  AppLocale.current = arabic ? AppLanguage.arabic : AppLanguage.english;
  return ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      authStateProvider.overrideWith((ref) => auth ?? Stream.value(user)),
      isAdminProvider.overrideWith(
        (ref) => ref.watch(currentUidProvider) == 'admin',
      ),
      userAccessProvider.overrideWith((ref) => Stream.value(access)),
      launchMessageProvider.overrideWith(
        (ref) => messages ?? Stream.value(message),
      ),
      appControlProvider.overrideWith((ref) => Stream.value(control)),
      profileProvider.overrideWith(
        (ref) => Stream.value(
          AppUser.fromMap(ref.watch(currentUidProvider) ?? '', {
            'onboardingCompleted': complete,
          }),
        ),
      ),
      userRepositoryProvider.overrideWithValue(users ?? _Users()),
      adminRepositoryProvider.overrideWithValue(admin ?? _Admin()),
      adminStatsProvider.overrideWith((ref) async => AdminStats.empty),
      adminProductsProvider.overrideWith((ref) => Stream.value([])),
      adminServicesProvider.overrideWith((ref) => Stream.value([])),
      adminUsersProvider.overrideWith(
        (ref) => Stream.value([
          const AdminUser('admin', {
            'username': 'shahzan',
            'email': 'abdullashahzan@gmail.com',
          }),
          const AdminUser('student', {
            'username': 'student',
            'email': 'student@example.com',
          }),
        ]),
      ),
      adminAccessProvider.overrideWith((ref) => Stream.value({})),
      adminAuditProvider.overrideWith((ref) => Stream.value([])),
      adminOrdersProvider.overrideWith((ref) => Stream.value([])),
      adminRequestsProvider.overrideWith((ref) => Stream.value([])),
    ],
    child: Consumer(
      builder: (context, ref, _) => MaterialApp(
        theme: AppTheme.light(),
        locale: ref.watch(localeProvider),
        supportedLocales: const [Locale('ar'), Locale('en')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        builder: child == null
            ? (context, child) => StartupGate(child: child!)
            : null,
        home: child ?? const Scaffold(body: Center(child: Text('Marketplace'))),
      ),
    ),
  );
}

const _notice = LaunchMessage(
  id: 'v1',
  title: 'Bug fix update',
  body: 'A detailed message about the latest fixes.',
  active: true,
);

void main() {
  tearDown(() => AppLocale.current = AppLanguage.english);

  testWidgets('launch message is shown before first-user onboarding', (
    tester,
  ) async {
    final prefs = await _prefs();
    await tester.pumpWidget(_app(prefs: prefs, message: _notice));
    await tester.pumpAndSettle();
    expect(find.text(_notice.title), findsOneWidget);
    expect(find.text('Welcome to Souq Akimi'), findsNothing);
    await tester.tap(find.text('Got it'));
    await tester.pumpAndSettle();
    expect(find.text('Welcome to Souq Akimi'), findsOneWidget);
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.text('Start exploring'));
    await tester.pumpAndSettle();
    expect(prefs.getBool('onboarding.v1.guest'), isTrue);
    expect(find.text('Welcome to Souq Akimi'), findsNothing);
  });

  testWidgets('signed-in onboarding completion is saved to the user profile', (
    tester,
  ) async {
    final users = _Users();
    await tester.pumpWidget(
      _app(prefs: await _prefs(), user: _User('student'), users: users),
    );
    await tester.pumpAndSettle();
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.text('Start exploring'));
    await tester.pumpAndSettle();
    expect(users.completed, ['student']);
  });

  testWidgets(
    'language switches safely above the root router during onboarding',
    (tester) async {
      await tester.pumpWidget(_app(prefs: await _prefs()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('العربية'));
      await tester.pumpAndSettle();
      expect(find.text('مرحبًا بك في سوق أكيمي'), findsOneWidget);
      await tester.tap(find.text('English'));
      await tester.pumpAndSettle();
      expect(find.text('Welcome to Souq Akimi'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('profile completion skips onboarding on another device', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(prefs: await _prefs(), user: _User('student'), complete: true),
    );
    await tester.pumpAndSettle();
    expect(find.text('Welcome to Souq Akimi'), findsNothing);
  });

  testWidgets(
    'every-open message reappears on resume without replaying onboarding',
    (tester) async {
      await tester.pumpWidget(
        _app(
          prefs: await _prefs({'onboarding.v1.guest': true}),
          message: _notice,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Got it'));
      await tester.pumpAndSettle();
      expect(find.text(_notice.title), findsNothing);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(find.text(_notice.title), findsOneWidget);
    },
  );

  testWidgets('once-only message remains acknowledged after resume', (
    tester,
  ) async {
    final prefs = await _prefs({'onboarding.v1.guest': true});
    await tester.pumpWidget(
      _app(
        prefs: prefs,
        message: const LaunchMessage(
          id: 'once',
          title: 'News',
          body: 'Campus news.',
          active: true,
          everyLaunch: false,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Got it'));
    await tester.pumpAndSettle();
    expect(prefs.getBool('announcement.guest.once'), isTrue);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.text('News'), findsNothing);
  });

  testWidgets(
    'new revision interrupts the app; withdrawal removes its overlay',
    (tester) async {
      final messages = StreamController<LaunchMessage>.broadcast();
      addTearDown(messages.close);
      await tester.pumpWidget(
        _app(
          prefs: await _prefs({'onboarding.v1.guest': true}),
          messages: messages.stream,
        ),
      );
      messages.add(_notice);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Got it'));
      await tester.pumpAndSettle();
      messages.add(
        const LaunchMessage(
          id: 'v2',
          title: 'New update',
          body: 'More fixes are ready.',
          active: true,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('New update'), findsOneWidget);
      messages.add(
        const LaunchMessage(
          id: 'v2',
          title: 'New update',
          body: 'More fixes are ready.',
          active: false,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('New update'), findsNothing);
    },
  );

  testWidgets('account switch does not share announcement acknowledgements', (
    tester,
  ) async {
    final auth = StreamController<User?>.broadcast();
    addTearDown(auth.close);
    await tester.pumpWidget(
      _app(
        prefs: await _prefs(),
        auth: auth.stream,
        complete: true,
        message: const LaunchMessage(
          id: 'once',
          title: 'News',
          body: 'Campus news.',
          active: true,
          everyLaunch: false,
        ),
      ),
    );
    auth.add(_User('first'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Got it'));
    await tester.pumpAndSettle();
    auth.add(_User('second'));
    await tester.pumpAndSettle();
    expect(find.text('News'), findsOneWidget);
  });

  for (final status in ['suspended', 'deleted']) {
    testWidgets(
      '$status account is blocked before announcements or onboarding',
      (tester) async {
        await tester.pumpWidget(
          _app(
            prefs: await _prefs(),
            user: _User('student'),
            message: _notice,
            access: UserAccess(
              status: status,
              reason: 'Please contact the owner.',
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.text(
            status == 'deleted' ? 'Account removed' : 'Account suspended',
          ),
          findsOneWidget,
        );
        expect(find.text(_notice.title), findsNothing);
        expect(find.text('Sign out'), findsOneWidget);
      },
    );
  }

  testWidgets(
    'maintenance notice leaves browsing and existing work accessible',
    (tester) async {
      await tester.pumpWidget(
        _app(
          prefs: await _prefs({'onboarding.v1.guest': true}),
          control: const AppControl(maintenance: true),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Marketplace maintenance'), findsOneWidget);
      await tester.tap(find.text('Continue browsing'));
      await tester.pumpAndSettle();
      expect(find.text('Marketplace maintenance'), findsNothing);
    },
  );

  testWidgets('admin cannot suspend or remove their own account in the UI', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        prefs: await _prefs(),
        user: _User('admin'),
        child: const Scaffold(body: AdminUsersTab()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Protected administrator'), findsOneWidget);
    expect(find.text('Suspend'), findsOneWidget);
    expect(find.text('Remove user'), findsOneWidget);
  });

  testWidgets('removal requires a reason and exact DELETE confirmation', (
    tester,
  ) async {
    final admin = _Admin();
    await tester.pumpWidget(
      _app(
        prefs: await _prefs(),
        user: _User('admin'),
        admin: admin,
        child: const Scaffold(body: AdminUsersTab()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove user'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();
    expect(admin.actions, isEmpty);
    await tester.enterText(find.byType(TextFormField).first, 'Repeated abuse');
    await tester.enterText(find.byType(TextFormField).last, 'DELETE');
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();
    expect(admin.actions, ['student:deleted:Repeated abuse']);
  });

  for (final arabic in [false, true]) {
    testWidgets(
      'onboarding and launch message fit a small phone, Arabic=$arabic',
      (tester) async {
        tester.view.physicalSize = const Size(360, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          _app(
            prefs: await _prefs({'souq.locale': arabic ? 'ar' : 'en'}),
            message: _notice,
            arabic: arabic,
          ),
        );
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text(translate('Got it')));
        await tester.tap(find.text(translate('Got it')));
        await tester.pumpAndSettle();
        for (var i = 0; i < 3; i++) {
          await tester.ensureVisible(find.text(translate('Next')));
          await tester.tap(find.text(translate('Next')));
          await tester.pumpAndSettle();
        }
        await tester.ensureVisible(find.text(translate('Start exploring')));
        await tester.tap(find.text(translate('Start exploring')));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('new admin tabs fit a small phone, Arabic=$arabic', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        _app(
          prefs: await _prefs({'souq.locale': arabic ? 'ar' : 'en'}),
          user: _User('admin'),
          arabic: arabic,
          child: const AdminScreen(),
        ),
      );
      await tester.pumpAndSettle();
      for (final name in ['Broadcast', 'Users', 'Controls', 'Activity']) {
        final tab = find.widgetWithText(Tab, translate(name));
        await tester.ensureVisible(tab);
        await tester.tap(tab);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
    });
  }
}
