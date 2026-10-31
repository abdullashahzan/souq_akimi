/// A problem worth showing to the user, with a message already phrased for
/// display (rather than a raw platform exception).
class SouqException implements Exception {
  const SouqException(this.message, {this.code});

  final String message;

  /// Backend error code when there is one (`failed-precondition`,
  /// `permission-denied`, …), useful for special-casing.
  final String? code;

  bool get isPermissionDenied => code == 'permission-denied';
  bool get isUnauthenticated => code == 'unauthenticated';

  @override
  String toString() => message;
}
