import 'package:flutter_test/flutter_test.dart';
import 'package:souq_akimi/core/app_config.dart';
import 'package:souq_akimi/data/order_math.dart';

/// The order flow's pure half: money, ids, hand-over codes and the status
/// derivation. Kept free of Firestore so it runs in milliseconds.
void main() {
  group('roundMoney', () {
    test('keeps exactly two decimals', () {
      expect(OrderMath.roundMoney(123.456), 123.46);
      expect(OrderMath.roundMoney(45), 45.0);
      expect(OrderMath.roundMoney(0), 0.0);
    });

    test('erases the float drift of price * quantity', () {
      expect(OrderMath.roundMoney(0.1 + 0.2), 0.3);
      expect(OrderMath.roundMoney(1.1 * 3), 3.3);
    });

    test('is idempotent, so a re-round of a line total cannot move money', () {
      final once = OrderMath.roundMoney(0.1 * 3);
      expect(OrderMath.roundMoney(once), once);
      expect(OrderMath.roundMoney(22.5), 22.5);
    });
  });

  group('order numbers', () {
    test('are SQ- plus six uppercase base36 characters', () {
      final pattern = RegExp(r'^SQ-[0-9A-Z]{6}$');
      for (var i = 0; i < 50; i++) {
        expect(OrderMath.generateOrderNumber(), matches(pattern));
      }
    });

    test('are not sequential', () {
      final seen = <String>{
        for (var i = 0; i < 2; i++) OrderMath.generateOrderNumber(),
      };
      expect(seen.length, 2);
    });
  });

  group('hand-over codes', () {
    test('are always six digits, including leading zeros', () {
      final pattern = RegExp(r'^[0-9]{6}$');
      for (var i = 0; i < 500; i++) {
        final otp = OrderMath.generateOtp();
        expect(otp, matches(pattern));
        expect(otp.length, 6);
      }
    });

    test('isValidOtp accepts only exactly six digits', () {
      expect(OrderMath.isValidOtp('123456'), isTrue);
      expect(OrderMath.isValidOtp('000000'), isTrue);
      expect(OrderMath.isValidOtp('12345'), isFalse);
      expect(OrderMath.isValidOtp('1234567'), isFalse);
      expect(OrderMath.isValidOtp('12345a'), isFalse);
      expect(OrderMath.isValidOtp(''), isFalse);
    });

    test('attemptsRemaining never goes below zero', () {
      expect(OrderMath.attemptsRemaining(0), AppConfig.otpMaxAttempts);
      expect(OrderMath.attemptsRemaining(1), AppConfig.otpMaxAttempts - 1);
      expect(OrderMath.attemptsRemaining(AppConfig.otpMaxAttempts), 0);
      expect(OrderMath.attemptsRemaining(99), 0);
    });
  });

  group('email', () {
    test('accepts a normal address and rejects obvious typos', () {
      expect(OrderMath.isValidEmail('student@example.com'), isTrue);
      expect(OrderMath.isValidEmail('a.b+tag@campus.edu'), isTrue);
      expect(OrderMath.isValidEmail('student@example'), isFalse);
      expect(OrderMath.isValidEmail('student.example.com'), isFalse);
      expect(OrderMath.isValidEmail(''), isFalse);
    });
  });

  group('deriveOrderStatus', () {
    test('an order is delivered only when every leg is delivered', () {
      expect(OrderMath.deriveOrderStatus(['delivered']), 'delivered');
      expect(
        OrderMath.deriveOrderStatus(['delivered', 'delivered']),
        'delivered',
      );
      expect(OrderMath.deriveOrderStatus(['delivered', 'ready']), 'pending');
    });

    test('an order is cancelled only when every leg is cancelled', () {
      expect(OrderMath.deriveOrderStatus(['cancelled']), 'cancelled');
      expect(
        OrderMath.deriveOrderStatus(['cancelled', 'cancelled']),
        'cancelled',
      );
      expect(
        OrderMath.deriveOrderStatus(['delivered', 'cancelled']),
        'pending',
      );
    });

    test('a missing delivery list stays pending', () {
      expect(OrderMath.deriveOrderStatus(const []), 'pending');
      expect(OrderMath.deriveOrderStatus(['ready']), 'pending');
    });
  });
}
