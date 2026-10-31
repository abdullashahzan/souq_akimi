import 'dart:math';

import '../core/app_config.dart';

/// The pure, platform-free half of the order flow: order numbers, hand-over
/// codes, money rounding and the rule that derives an order's status from its
/// deliveries.
///
/// The project runs on Firebase's Spark (free) plan, so Cloud Functions cannot
/// be deployed. The transitions happen in client transactions and are
/// *enforced* by `firestore.rules`; everything computable lives here so it
/// stays unit-testable.
class OrderMath {
  const OrderMath._();

  /// `SQ-XXXXXX` — six uppercase base36 characters (the order doc id).
  static const String orderNumberPrefix = 'SQ-';

  static const String _base36 = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ';

  static final Random _secure = Random.secure();

  /// Money is stored in dollars with at most two decimals. Rounding here keeps
  /// line totals and the order total from drifting in float arithmetic.
  static const double _epsilon = 2.220446049250313e-16; // Number.EPSILON

  static double roundMoney(double value) =>
      ((value + _epsilon) * 100).roundToDouble() / 100;

  /// Random uppercase base36 string, used for order numbers.
  static String randomBase36(int length) => List.generate(
    length,
    (_) => _base36[_secure.nextInt(_base36.length)],
    growable: false,
  ).join();

  /// `SQ-XXXXXX`, six uppercase base36 characters.
  static String generateOrderNumber() => '$orderNumberPrefix${randomBase36(6)}';

  /// The buyer's one-time hand-over code: six digits, zero-padded.
  ///
  /// It is generated once by the buyer's device and stored in
  /// `deliverySecrets`, which only the buyer can read — the seller never sees
  /// it until the buyer reads it out at the door.
  static String generateOtp() =>
      _secure.nextInt(1000000).toString().padLeft(6, '0');

  static final RegExp _otpPattern = RegExp(r'^[0-9]{6}$');
  static final RegExp _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  static bool isValidOtp(String code) => _otpPattern.hasMatch(code);

  static bool isValidEmail(String email) => _emailPattern.hasMatch(email);

  /// How many hand-over attempts a seller has left before the buyer must
  /// generate a new code (`DELIVERY_OTP_MAX_ATTEMPTS`).
  static int attemptsRemaining(int used) =>
      (AppConfig.otpMaxAttempts - used).clamp(0, AppConfig.otpMaxAttempts);

  /// Derives an order's status from its deliveries.
  ///
  /// Souq is cartless, so an order normally has exactly one leg; the
  /// multi-seller case stays `pending` until every leg is delivered.
  static String deriveOrderStatus(Iterable<String> deliveryStatuses) {
    final statuses = deliveryStatuses.toList(growable: false);
    if (statuses.isEmpty) return 'pending';
    if (statuses.every((s) => s == 'delivered')) return 'delivered';
    if (statuses.every((s) => s == 'cancelled')) return 'cancelled';
    return 'pending';
  }
}
