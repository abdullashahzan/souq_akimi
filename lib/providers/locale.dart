import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/l10n.dart';
import 'dependencies.dart';

/// The saved language, read synchronously from SharedPreferences.
///
/// Switching is instant: `MaterialApp.locale` changes, every `Text` rebuilds,
/// and Material's own widgets (date pickers, tooltips) follow along.
class LocaleNotifier extends Notifier<Locale> {
  static const String _key = 'souq.locale';

  @override
  Locale build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final language = AppLanguage.fromCode(prefs.getString(_key));
    AppLocale.current = language;
    return Locale(language.code);
  }

  Future<void> setLanguage(AppLanguage language) async {
    AppLocale.current = language;
    state = Locale(language.code);
    await ref.read(sharedPreferencesProvider).setString(_key, language.code);
  }

  Future<void> toggle() => setLanguage(
    AppLocale.isArabic ? AppLanguage.english : AppLanguage.arabic,
  );
}

final localeProvider = NotifierProvider<LocaleNotifier, Locale>(
  LocaleNotifier.new,
);

/// Convenience for the settings UI.
final appLanguageProvider = Provider<AppLanguage>(
  (ref) => AppLanguage.fromCode(ref.watch(localeProvider).languageCode),
);
