import 'package:souq_akimi/widgets/ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/feedback.dart';
import '../../providers/auth.dart';
import '../../widgets/common.dart';

/// Gate an action behind sign-in. Returns `true` when the user is signed in;
/// otherwise it nudges them to the login screen and returns `false`.
bool requireSignIn(BuildContext context, WidgetRef ref, {String? message}) {
  if (ref.read(isSignedInProvider)) return true;
  showMessage(message ?? 'Please sign in to continue.');
  context.push('/login');
  return false;
}

/// A whole screen that only makes sense for a signed-in student: shows a
/// sign-in prompt instead of an empty shell when browsing as a guest.
class RequireAuth extends ConsumerWidget {
  const RequireAuth({
    super.key,
    required this.child,
    this.title = 'Sign in to continue',
    this.message =
        'Your orders, listings and requests live behind your account.',
  });

  final Widget child;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(isSignedInProvider)) return child;

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: EmptyState(
        icon: Icons.lock_outline,
        title: title,
        message: message,
        action: FilledButton(
          onPressed: () => context.push('/login'),
          child: const Text('Sign in'),
        ),
      ),
    );
  }
}
