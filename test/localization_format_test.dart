import 'package:flutter_test/flutter_test.dart';
import 'package:souq_akimi/core/app_config.dart';
import 'package:souq_akimi/core/format.dart';
import 'package:souq_akimi/core/l10n.dart';
import 'package:souq_akimi/features/shell/app_shell.dart';
import 'package:souq_akimi/providers/sellers.dart';

void main() {
  tearDown(() => AppLocale.current = AppLanguage.english);

  group('Arabic copy', () {
    test('translates known copy and leaves unknown data alone', () {
      AppLocale.current = AppLanguage.arabic;
      expect(translate('Sign in'), 'تسجيل الدخول');
      expect(translate('Sara’s old desk'), 'Sara’s old desk');
    });

    test('fills interpolation arguments in both languages', () {
      expect(
        translate(
          'Only {count} left — adjust the quantity on the listing page.',
          args: {'count': '3'},
        ),
        'Only 3 left — adjust the quantity on the listing page.',
      );
      AppLocale.current = AppLanguage.arabic;
      final arabic = translate(
        'This will add the announcement to {count} inboxes. Continue?',
        args: {'count': '42'},
      );
      expect(arabic, contains('42'));
      expect(arabic, contains('صندوق وارد'));
    });
  });

  group('money and services', () {
    test('prices are SAR in English and ر.س in Arabic', () {
      expect(Format.money(1234.5), 'SAR 1,234.50');
      AppLocale.current = AppLanguage.arabic;
      expect(Format.money(1234.5), '1,234.50 ر.س');
      expect(Format.priceWithUnit(45, '/ hour'), contains('/ ساعة'));
      expect(Format.stock(0), 'نفدت الكمية');
    });
  });

  group('buildings', () {
    test('br1 is Ashra and br10 is Wahid', () {
      expect(AppConfig.buildingFor('br1').arabicName, 'برج عشرة');
      expect(AppConfig.buildingFor('br10').arabicName, 'برج واحد');
      expect(AppConfig.buildingFor('Br 10').code, 'br10');
      expect(AppConfig.buildingFor('Br 1').code, 'br1');
      AppLocale.current = AppLanguage.arabic;
      expect(Format.building('br1'), 'br1 · برج عشرة');
    });

    test('unknown legacy values survive untouched', () {
      expect(AppConfig.buildingFor('Old Block').code, 'Old Block');
    });
  });

  group('seller handles', () {
    test('completed sales sit in brackets', () {
      expect(sellerHandle('lina', 12), '\u200E@lina (12)');
      expect(sellerHandle('lina', 0), '\u200E@lina (0)');
      expect(sellerHandle('lina', null), '\u200E@lina');
      expect(sellerHandle('  ', 9), '\u200E@');
    });
  });

  test('the admin route keeps the Profile tab selected', () {
    expect(AppShell.indexFor('/admin'), 4);
    expect(AppShell.indexFor('/sell/service'), 2);
    expect(AppShell.indexFor('/requests'), 1);
  });
}
