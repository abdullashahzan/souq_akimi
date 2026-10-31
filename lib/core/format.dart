import 'package:intl/intl.dart';

import 'app_config.dart';
import 'l10n.dart';

/// Display formatting shared across the app.
class Format {
  const Format._();

  static final NumberFormat _amount = NumberFormat('#,##0.00', 'en');

  /// `1234.5` → `SAR 1,234.50` (English) / `1,234.50 ر.س` (Arabic).
  static String money(num? amount) {
    final value = _amount.format(amount ?? 0);
    return AppLocale.isArabic
        ? '$value ${AppConfig.currencySymbolArabic}'
        : '${AppConfig.currencySymbol} $value';
  }

  /// A price plus its unit, e.g. `SAR 45.00 / hour` for a service.
  static String priceWithUnit(num? amount, String unitSuffix) {
    if (unitSuffix.isEmpty) return money(amount);
    return '${money(amount)} ${_suffix(unitSuffix)}';
  }

  static String _suffix(String suffix) => switch (suffix) {
    '/ hour' => AppLocale.isArabic ? '/ ساعة' : '/ hour',
    '/ job' => AppLocale.isArabic ? '/ مهمة' : '/ job',
    '/ page' => AppLocale.isArabic ? '/ صفحة' : '/ page',
    _ => suffix,
  };

  static final DateFormat _short = DateFormat('d MMM y');
  static final DateFormat _withTime = DateFormat('d MMM y · HH:mm');
  static final DateFormat _shortArabic = DateFormat('d MMM y', 'ar');
  static final DateFormat _withTimeArabic = DateFormat('d MMM y · HH:mm', 'ar');

  static String date(DateTime? at) {
    if (at == null) return '';
    final local = at.toLocal();
    return (AppLocale.isArabic ? _shortArabic : _short).format(local);
  }

  static String dateTime(DateTime? at) {
    if (at == null) return '';
    final local = at.toLocal();
    return (AppLocale.isArabic ? _withTimeArabic : _withTime).format(local);
  }

  /// "just now", "5m ago", "3h ago", "2d ago", then a plain date.
  static String relative(DateTime? at) {
    if (at == null) return '';
    final diff = DateTime.now().difference(at);
    if (diff.inSeconds < 45) return translate('just now');
    if (diff.inMinutes < 60) {
      return AppLocale.isArabic
          ? 'قبل ${diff.inMinutes} د'
          : '${diff.inMinutes}m ago';
    }
    if (diff.inHours < 24) {
      return AppLocale.isArabic
          ? 'قبل ${diff.inHours} س'
          : '${diff.inHours}h ago';
    }
    if (diff.inDays < 7) {
      return AppLocale.isArabic
          ? 'قبل ${diff.inDays} ي'
          : '${diff.inDays}d ago';
    }
    return date(at);
  }

  /// "3 left" style stock label.
  static String stock(int stock) => stock <= 0
      ? translate('Sold out')
      : (AppLocale.isArabic ? '$stock متبقي' : '$stock left');

  static String count(int value, String singular, String plural) =>
      '$value ${value == 1 ? singular : plural}';

  /// The display label for a stored building code.
  static String building(String raw) {
    if (raw.trim().isEmpty) return '';
    return AppConfig.buildingFor(raw).label(AppLocale.isArabic);
  }
}
