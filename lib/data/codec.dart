import 'package:cloud_firestore/cloud_firestore.dart';

/// Small, forgiving decoders for Firestore payloads.
///
/// Firestore documents are schemaless, so any field may be missing, `null`, or
/// an `int` where a `double` is expected. These helpers keep the model
/// factories readable and stop a half-written document from crashing the app.
class Codec {
  const Codec._();

  static String str(Object? value, [String fallback = '']) =>
      value is String ? value : fallback;

  static double dbl(Object? value, [double fallback = 0]) => switch (value) {
    num v => v.toDouble(),
    String v => double.tryParse(v) ?? fallback,
    _ => fallback,
  };

  static int integer(Object? value, [int fallback = 0]) => switch (value) {
    num v => v.toInt(),
    String v => int.tryParse(v) ?? fallback,
    _ => fallback,
  };

  static bool boolean(Object? value, [bool fallback = false]) =>
      value is bool ? value : fallback;

  static List<String> strings(Object? value) {
    if (value is! List) return const [];
    return value
        .whereType<Object?>()
        .map((e) => str(e))
        .where((e) => e.isNotEmpty)
        .toList();
  }

  static List<Map<String, dynamic>> maps(Object? value) {
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map((e) => e.map((k, v) => MapEntry('$k', v)))
        .toList();
  }

  /// Accepts a Firestore [Timestamp], a [DateTime], epoch millis, or an ISO
  /// string, and returns a `DateTime` (or `null`).
  static DateTime? date(Object? value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  /// Encodes a `DateTime` as a Firestore [Timestamp] for writes.
  static Timestamp? stamp(DateTime? value) =>
      value == null ? null : Timestamp.fromDate(value);
}
