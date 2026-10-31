import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:souq_akimi/widgets/ui.dart';

/// The app's visual language: a deep campus emerald, warm off-white paper,
/// generous 24-point corners and soft, low-contrast depth.
///
/// The palette stays close to the original teal so the marketplace keeps its
/// identity, but surfaces are now layered instead of pure white and the
/// typography is deliberately heavier and more confident.
class AppTheme {
  const AppTheme._();

  /// Seed for the whole colour scheme.
  static const Color seed = Color(0xFF0B5D4B);

  /// Amber used for gentle "waiting" accents.
  static const Color escrow = Color(0xFFB7791F);

  static const Color canvas = Color(0xFFF4F6F2);
  static const Color ink = Color(0xFF12211B);
  static const Color muted = Color(0xFF5B6B64);

  /// The one theme the app ships (see `themeMode` in `app.dart`).
  static ThemeData light() {
    final scheme =
        ColorScheme.fromSeed(
          seedColor: seed,
          brightness: Brightness.light,
        ).copyWith(
          primary: seed,
          onPrimary: Colors.white,
          primaryContainer: const Color(0xFFD7F2E7),
          onPrimaryContainer: const Color(0xFF063B2E),
          secondary: const Color(0xFFE8B85C),
          onSecondary: const Color(0xFF3A2A06),
          secondaryContainer: const Color(0xFFFFF0D2),
          onSecondaryContainer: const Color(0xFF4A3408),
          tertiary: const Color(0xFF2D6CE0),
          onTertiary: Colors.white,
          tertiaryContainer: const Color(0xFFE4EDFF),
          onTertiaryContainer: const Color(0xFF11326F),
          surface: const Color(0xFFFCFDFB),
          surfaceContainerLowest: Colors.white,
          surfaceContainerLow: const Color(0xFFF7F9F5),
          surfaceContainer: const Color(0xFFF1F4EF),
          surfaceContainerHigh: const Color(0xFFEAF0E9),
          surfaceContainerHighest: const Color(0xFFE2E9E1),
          onSurface: ink,
          onSurfaceVariant: muted,
          outline: const Color(0xFF97A79F),
          outlineVariant: const Color(0xFFE1E8E1),
          error: const Color(0xFFC43D3D),
          onError: Colors.white,
        );
    return _base(scheme);
  }

  /// Kept so a dark mode can be switched on later without a rewrite; the app
  /// currently pins [ThemeMode.light] because the warm paper background is the
  /// requested product look.
  static ThemeData dark() =>
      _base(ColorScheme.fromSeed(seedColor: seed, brightness: Brightness.dark));

  static ThemeData _base(ColorScheme scheme) {
    final isLight = scheme.brightness == Brightness.light;
    final surface = isLight ? canvas : scheme.surface;
    final generated = ThemeData(
      useMaterial3: true,
      fontFamily: 'Cairo',
    ).textTheme;

    final textTheme = generated
        .copyWith(
          displaySmall: generated.displaySmall?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.9,
            height: 1.05,
          ),
          headlineMedium: generated.headlineMedium?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.6,
            height: 1.12,
          ),
          headlineSmall: generated.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
            height: 1.15,
          ),
          titleLarge: generated.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.2,
          ),
          titleMedium: generated.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
          titleSmall: generated.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
          bodyLarge: generated.bodyLarge?.copyWith(height: 1.5),
          bodyMedium: generated.bodyMedium?.copyWith(height: 1.5),
          labelLarge: generated.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
          labelMedium: generated.labelMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
          labelSmall: generated.labelSmall?.copyWith(
            fontWeight: FontWeight.w600,
            letterSpacing: 0.1,
          ),
        )
        .apply(
          fontFamily: 'Cairo',
          bodyColor: scheme.onSurface,
          displayColor: scheme.onSurface,
        );

    return ThemeData(
      useMaterial3: true,
      fontFamily: 'Cairo',
      colorScheme: scheme,
      scaffoldBackgroundColor: surface,
      canvasColor: surface,
      textTheme: textTheme,
      visualDensity: VisualDensity.adaptivePlatformDensity,
      // One, light, platform-appropriate transition everywhere: the M3
      // fade-forwards on Android, the native slide (with the edge swipe-back
      // gesture students expect) on iOS.
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.fuchsia: FadeForwardsPageTransitionsBuilder(),
        },
      ),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        toolbarHeight: 72,
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          color: scheme.onSurface,
          fontSize: 21,
          fontWeight: FontWeight.w800,
        ),
        iconTheme: IconThemeData(color: scheme.onSurface, size: 23),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: isLight ? Colors.white : scheme.surfaceContainer,
        surfaceTintColor: Colors.transparent,
        clipBehavior: Clip.antiAlias,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.8)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: isLight ? Colors.white : scheme.surfaceContainer,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: isLight ? Colors.white : scheme.surfaceContainer,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: isLight ? Colors.white : scheme.surfaceContainer,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        floatingLabelBehavior: FloatingLabelBehavior.always,
        filled: true,
        fillColor: isLight ? Colors.white : scheme.surfaceContainerHigh,
        hintStyle: textTheme.bodyLarge?.copyWith(
          color: scheme.onSurfaceVariant.withValues(alpha: 0.8),
        ),
        labelStyle: textTheme.bodyLarge?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
        floatingLabelStyle: textTheme.bodyLarge?.copyWith(
          color: scheme.primary,
          fontWeight: FontWeight.w700,
        ),
        prefixIconColor: scheme.onSurfaceVariant,
        suffixIconColor: scheme.onSurfaceVariant,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: scheme.primary, width: 1.8),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: scheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: scheme.error, width: 1.8),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 16,
        ),
      ),
      // A finite minimum width matters: `Size.fromHeight` would make every
      // button demand infinite width, which is fine when it is stretched by a
      // Column but crashes the moment a button sits inside a Row. Full-width
      // calls to action ask for it explicitly instead.
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 54),
          elevation: 0,
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, 54),
          foregroundColor: scheme.onSurface,
          side: BorderSide(color: scheme.outlineVariant),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: scheme.primary,
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: isLight ? Colors.white : scheme.surfaceContainerHigh,
        selectedColor: scheme.primary,
        secondarySelectedColor: scheme.primary,
        checkmarkColor: scheme.onPrimary,
        showCheckmark: false,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        labelStyle: TextStyle(
          color: scheme.onSurface,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
        secondaryLabelStyle: TextStyle(
          color: scheme.onPrimary,
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
        side: BorderSide(color: scheme.outlineVariant),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        thickness: 1,
        space: 1,
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        elevation: 0,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        indicatorColor: scheme.primary.withValues(alpha: 0.12),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.onSurface,
        contentTextStyle: TextStyle(
          color: scheme.surface,
          fontWeight: FontWeight.w600,
        ),
        actionTextColor: scheme.secondary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        insetPadding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: scheme.primary,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: scheme.primary),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      bottomAppBarTheme: BottomAppBarThemeData(
        color: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
    );
  }
}
