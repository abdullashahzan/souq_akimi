import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../core/ai_config.dart';
import '../../core/souq_exception.dart';

/// Authentication only — creating the `users/{uid}` profile document is the
/// [UserRepository]'s job, orchestrated by the session controller.
class AuthRepository {
  AuthRepository({FirebaseAuth? auth}) : _auth = auth ?? FirebaseAuth.instance;

  final FirebaseAuth _auth;

  Stream<User?> authStateChanges() => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  bool get isSignedIn => _auth.currentUser != null;

  /// Google Sign-In. Returns `false` when the student closed the account
  /// picker; anything else is surfaced as a friendly [SouqException].
  Future<bool> signInWithGoogle() async {
    try {
      final clientId = AiConfig.googleWebClientId.trim();
      final google = GoogleSignIn(
        scopes: const ['email', 'profile'],
        serverClientId: clientId.isEmpty ? null : clientId,
      );
      final account = await google.signIn();
      if (account == null) return false;
      final auth = await account.authentication;
      if (auth.idToken == null && auth.accessToken == null) {
        throw const SouqException(
          'Google sign-in is not available on this device.',
        );
      }
      final credential = GoogleAuthProvider.credential(
        idToken: auth.idToken,
        accessToken: auth.accessToken,
      );
      await _auth.signInWithCredential(credential);
      return true;
    } on PlatformException catch (error) {
      if (error.code == 'sign_in_canceled') return false;
      throw SouqException(
        error.code == 'network_error'
            ? 'No connection. Check your network and try again.'
            : 'Google sign-in could not start. Please try again.',
        code: error.code,
      );
    } on FirebaseAuthException catch (error) {
      throw _map(error);
    }
  }

  Future<void> signIn({required String email, required String password}) async {
    try {
      await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } on FirebaseAuthException catch (error) {
      throw _map(error);
    }
  }

  /// Create the account and set the display name used as the seller handle.
  Future<User> register({
    required String username,
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final user = credential.user;
      if (user == null) {
        throw const SouqException(
          'Could not create your account. Please try again.',
        );
      }
      await user.updateDisplayName(username.trim());
      await user.reload();
      return _auth.currentUser ?? user;
    } on FirebaseAuthException catch (error) {
      throw _map(error);
    }
  }

  Future<void> sendPasswordReset(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (error) {
      throw _map(error);
    }
  }

  Future<void> signOut() => _auth.signOut();

  /// Turn the raw Firebase codes into something a student can act on.
  SouqException _map(FirebaseAuthException error) {
    final message = switch (error.code) {
      'invalid-email' => 'That email address does not look right.',
      'email-already-in-use' =>
        'That email is already registered. Try signing in instead.',
      'weak-password' => 'Please choose a password of at least 6 characters.',
      'user-not-found' ||
      'wrong-password' ||
      'invalid-credential' => 'Email or password is incorrect.',
      'user-disabled' => 'This account has been disabled.',
      'too-many-requests' =>
        'Too many attempts. Please wait a moment and retry.',
      'network-request-failed' =>
        'No connection. Check your network and try again.',
      'requires-recent-login' => 'Please sign in again to continue.',
      'operation-not-allowed' || 'account-exists-with-different-credential' =>
        'Google sign-in is not available for this account yet.',
      _ =>
        error.message?.trim().isNotEmpty == true
            ? error.message!.trim()
            : 'Something went wrong. Please try again.',
    };
    return SouqException(message, code: error.code);
  }
}
