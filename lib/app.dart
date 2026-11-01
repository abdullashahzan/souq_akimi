import 'package:souq_akimi/widgets/ui.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/app_config.dart';
import 'core/feedback.dart';
import 'core/theme.dart';
import 'core/motion.dart';
import 'providers/locale.dart';
import 'router.dart';
import 'widgets/startup_gate.dart';

/// The parsed route table. Kept in a provider so tests can swap it out.
final routerProvider = Provider<GoRouter>((ref) => createRouter());

/// The app widget: Material 3 theme + the GoRouter.
class SouqApp extends ConsumerWidget {
  const SouqApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final locale = ref.watch(localeProvider);
    return MaterialApp.router(
      title: AppConfig.appName,
      locale: locale,
      supportedLocales: const [Locale('en'), Locale('ar')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      debugShowCheckedModeBanner: false,
      // Snack bars are raised through this key rather than a screen's context,
      // so a message survives the popup that triggered it closing.
      scaffoldMessengerKey: souqMessengerKey,
      theme: AppTheme.light(),
      scrollBehavior: const SouqScrollBehavior(),
      darkTheme: AppTheme.dark(),
      // The product look is a white app on both platforms; a half-finished dark
      // theme would be worse than none, so the system preference is ignored
      // until dark mode is designed properly.
      themeMode: ThemeMode.light,
      builder: (context, child) {
        if (child == null) return const SizedBox.shrink();
        // Keep the layout safe from extreme system font sizes without ignoring
        // the user's preference entirely.
        return MediaQuery.withClampedTextScaling(
          minScaleFactor: 0.9,
          maxScaleFactor: 1.35,
          child: StartupGate(child: child),
        );
      },
      routerConfig: router,
    );
  }
}
