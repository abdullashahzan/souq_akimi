import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/app_user.dart';
import 'dependencies.dart';

/// The raw Firebase auth stream.
final authStateProvider = StreamProvider<User?>(
  (ref) => ref.watch(authRepositoryProvider).authStateChanges(),
);

/// The signed-in user's uid, or `null` when browsing as a guest.
///
/// While the auth stream is still resolving, [authStateProvider] has no value —
/// treating that as "signed out" keeps the UI stable during the first frame.
final currentUidProvider = Provider<String?>(
  (ref) => ref.watch(authStateProvider).value?.uid,
);

final isSignedInProvider = Provider<bool>(
  (ref) => ref.watch(currentUidProvider) != null,
);

/// Live profile document for the signed-in user.
final profileProvider = StreamProvider<AppUser>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(AppUser.empty(''));
  return ref.watch(userRepositoryProvider).watch(uid);
});

/// Convenience: the profile or a blank one, never null.
///
/// A `StreamProvider` keeps the previous value while the next account's
/// stream starts, so after a sign-out/sign-in the old profile can still be
/// attached. Rejecting a mismatched `uid` prevents one student's name from
/// leaking into the next student's listing or checkout.
final profileOrEmptyProvider = Provider<AppUser>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return AppUser.empty('');

  final profile = ref.watch(profileProvider).value;
  if (profile != null && profile.uid == uid) return profile;

  final authUser = ref.watch(authStateProvider).value;
  final fallback = (authUser?.displayName?.trim().isNotEmpty ?? false)
      ? authUser!.displayName!.trim()
      : (authUser?.email?.split('@').first ?? '');
  return AppUser.empty(uid).copyWith(username: fallback, displayName: fallback);
});

/// Orchestrates the auth flows and keeps the profile document in step with
/// Firebase Auth. Screens own their own loading state and just await these.
class Session {
  const Session(this.ref);

  final Ref ref;

  Future<void> signIn({required String email, required String password}) async {
    await ref
        .read(authRepositoryProvider)
        .signIn(email: email, password: password);
    await _syncProfile();
  }

  Future<bool> signInWithGoogle() async {
    final changed = await ref.read(authRepositoryProvider).signInWithGoogle();
    if (changed) await _syncProfile();
    return changed;
  }

  Future<void> register({
    required String username,
    required String email,
    required String password,
  }) async {
    await ref
        .read(authRepositoryProvider)
        .register(username: username, email: email, password: password);
    await _syncProfile(username: username);
  }

  Future<void> signOut() => ref.read(authRepositoryProvider).signOut();

  /// Make sure a `users/{uid}` document exists. Also repairs accounts created
  /// before the profile was written (e.g. seeded or legacy users).
  Future<void> _syncProfile({String? username}) async {
    final user = ref.read(authRepositoryProvider).currentUser;
    if (user == null) return;
    final handle = _handleFor(user, username);
    await ref
        .read(userRepositoryProvider)
        .ensureProfile(
          uid: user.uid,
          username: handle,
          email: user.email ?? '',
          displayName: user.displayName ?? handle,
        );
  }

  String _handleFor(User user, String? preferred) {
    final candidates = [
      preferred,
      user.displayName,
      user.email?.split('@').first,
    ];
    for (final candidate in candidates) {
      if (candidate != null && candidate.trim().isNotEmpty) {
        return candidate.trim();
      }
    }
    return 'student';
  }
}

final sessionProvider = Provider<Session>((ref) => Session(ref));
