import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:souq_akimi/widgets/ui.dart';

import 'l10n.dart';
import 'souq_exception.dart';

/// The app-level [ScaffoldMessenger].
///
/// Snack bars are raised through this key instead of the calling widget's
/// context. That matters for the "save, close, then report" screens (the
/// payment-method sheet, the delivery-defaults sheet, any dialog): once
/// `Navigator.pop` has run, the popup's own element is on its way out, so a
/// message shown through its context can be lost — or assert
/// ("Looking up a deactivated widget's ancestor is unsafe"). Going through the
/// root messenger is always safe, and the bar outlives the popup.
final GlobalKey<ScaffoldMessengerState> souqMessengerKey =
    GlobalKey<ScaffoldMessengerState>(debugLabel: 'souqMessenger');

ScaffoldMessengerState? _messenger() => souqMessengerKey.currentState;

/// Show a short confirmation at the bottom of the screen.
void showMessage(String message, {Map<String, String>? args}) {
  _messenger()
    ?..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(translate(message, args: args)),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
}

/// Show an error, unwrapping [SouqException] so the user reads the sentence the
/// domain layer wrote rather than a stack trace.
///
/// Anything that is not one of our own exceptions is deliberately reduced to a
/// calm, generic sentence in release builds: users should never be shown a raw
/// Firestore dump (index URLs, internal codes) in production, while developers
/// still get the detail in debug builds.
void showError(Object error) {
  final flavour = describeError(error);

  final context = _messenger()?.context;
  final scheme = context == null ? null : Theme.of(context).colorScheme;
  _messenger()
    ?..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(flavour),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
        backgroundColor: scheme?.error,
        showCloseIcon: true,
      ),
    );
}

/// Turns any thrown object into one sentence a student can act on.
///
/// A [SouqException] already carries a written sentence. Anything else is a
/// platform error (Firestore, Auth, the network) and is mapped onto a calm
/// generic message in release builds — users should never be shown a raw
/// Firestore dump with an index-creation URL — while debug builds keep the
/// original text so problems stay diagnosable.
String describeError(Object error) {
  if (error is SouqException) return translate(error.message);
  final raw = '$error';
  final text = raw.toLowerCase();
  if (text.contains('failed-precondition') && text.contains('index')) {
    return translate(
      'This list is still getting ready. Please try again in a moment.',
    );
  }
  if (text.contains('permission-denied') ||
      text.contains('permission_denied')) {
    return translate('You do not have access to that. Try signing in again.');
  }
  if (text.contains('unavailable') || text.contains('network')) {
    return translate('No connection. Check your internet and try again.');
  }
  if (text.contains('not-found') || text.contains('notfound')) {
    return translate('That item no longer exists.');
  }
  if (text.contains('too-many-requests') || text.contains('quota')) {
    return translate('Too many attempts. Please wait a moment and try again.');
  }
  if (text.contains('requires-recent-login')) {
    return translate('Please sign in again to finish that.');
  }
  if (text.contains('wrong-password') ||
      text.contains('invalid-credential') ||
      text.contains('invalid-login')) {
    return translate('That email and password do not match.');
  }
  return kDebugMode
      ? raw
      : translate('Something went wrong. Please try again.');
}
