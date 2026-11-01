import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/feedback.dart';
import '../core/l10n.dart';
import '../core/motion.dart';
import '../providers/admin.dart';
import '../providers/app_control.dart';
import '../providers/auth.dart';
import '../providers/dependencies.dart';
import '../providers/locale.dart';
import 'ui.dart';

/// Above the root router: launch messages cannot be hidden by tabs, login,
/// inbox alerts or a deep-linked listing. No dialog is queued during build.
class StartupGate extends ConsumerStatefulWidget {
  const StartupGate({super.key, required this.child});
  final Widget child;
  @override
  ConsumerState<StartupGate> createState() => _StartupGateState();
}

class _StartupGateState extends ConsumerState<StartupGate>
    with WidgetsBindingObserver {
  final Set<String> _dismissed = {};
  String? _identity;
  bool _paused = false;
  bool _maintenanceSeen = false;
  bool _saving = false;
  bool _tourFinished = false;
  int _step = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) _paused = true;
    if (state == AppLifecycleState.resumed && _paused) {
      _paused = false;
      setState(() {
        _dismissed.clear();
        _maintenanceSeen = false;
      });
      // Refresh even when no new Firestore event was emitted while backgrounded.
      ref.invalidate(launchMessageProvider);
      ref.invalidate(appControlProvider);
      ref.invalidate(userAccessProvider);
    }
  }

  Future<void> _finish(String identity, String? uid) async {
    setState(() => _saving = true);
    try {
      if (uid != null) {
        await ref.read(userRepositoryProvider).completeOnboarding(uid);
      }
      final saved = await ref
          .read(sharedPreferencesProvider)
          .setBool('onboarding.v1.$identity', true);
      if (!saved) throw StateError('Could not save onboarding.');
      if (mounted && _identity == identity) {
        setState(() => _tourFinished = true);
      }
    } catch (error) {
      if (mounted) showError(error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authStateProvider);
    final uid = ref.watch(currentUidProvider);
    final identity = uid ?? 'guest';
    if (_identity != identity) {
      _identity = identity;
      _step = 0;
      _tourFinished = false;
      _dismissed.clear();
      _maintenanceSeen = false;
    }
    final access = ref.watch(userAccessProvider);
    final message = ref.watch(launchMessageProvider);
    final control = ref.watch(appControlProvider);
    final admin = ref.watch(isAdminProvider);
    final prefs = ref.watch(sharedPreferencesProvider);
    final profile = uid == null ? null : ref.watch(profileProvider);
    Widget? panel;
    if (auth.isLoading || (uid != null && access.isLoading)) {
      panel = const Center(child: CircularProgressIndicator());
    } else if (uid != null && access.hasError && !admin) {
      panel = _StartupPanel(
        icon: Icons.cloud_off_outlined,
        title: 'Connection needed',
        body:
            'We could not check your account access. Reconnect and try again.',
        action: 'Retry',
        onAction: () => ref.invalidate(userAccessProvider),
        secondary: TextButton(
          onPressed: () => ref.read(sessionProvider).signOut(),
          child: const Text('Sign out'),
        ),
      );
    } else if (access.value?.blocked == true && !admin) {
      panel = _StartupPanel(
        icon: Icons.gpp_bad_outlined,
        title: access.value!.status == 'deleted'
            ? 'Account removed'
            : 'Account suspended',
        body: access.value!.reason,
        action: 'Sign out',
        onAction: () => ref.read(sessionProvider).signOut(),
      );
    } else if (message.isLoading) {
      panel = const Center(child: CircularProgressIndicator());
    } else {
      final announcement = message.value;
      if (announcement?.visible == true &&
          !_dismissed.contains(announcement!.id) &&
          (announcement.everyLaunch ||
              prefs.getBool('announcement.$identity.${announcement.id}') !=
                  true)) {
        panel = _StartupPanel(
          icon: Icons.campaign_rounded,
          title: announcement.title,
          body: announcement.body,
          eyebrow: 'A message from Souq Akimi',
          action: 'Got it',
          busy: _saving,
          onAction: () async {
            setState(() => _saving = true);
            try {
              if (!announcement.everyLaunch) {
                final saved = await prefs.setBool(
                  'announcement.$identity.${announcement.id}',
                  true,
                );
                if (!saved) throw StateError('Could not save acknowledgement.');
              }
              if (mounted && _identity == identity) {
                setState(() => _dismissed.add(announcement.id));
              }
            } catch (error) {
              if (mounted) showError(error);
            } finally {
              if (mounted) setState(() => _saving = false);
            }
          },
        );
      } else if (control.value?.maintenance == true &&
          !_maintenanceSeen &&
          !admin) {
        panel = _StartupPanel(
          icon: Icons.construction_rounded,
          title: 'Marketplace maintenance',
          body: control.value!.message.isEmpty
              ? 'New listings, purchases and service requests are temporarily paused. Existing orders can still be managed.'
              : control.value!.message,
          action: 'Continue browsing',
          onAction: () => setState(() => _maintenanceSeen = true),
        );
      } else if (uid != null && profile!.isLoading) {
        panel = const Center(child: CircularProgressIndicator());
      } else if (!_tourFinished &&
          prefs.getBool('onboarding.v1.$identity') != true &&
          !(profile?.value?.uid == uid &&
              profile?.value?.onboardingCompleted == true)) {
        const steps = [
          (
            Icons.storefront_rounded,
            'Welcome to Souq Akimi',
            'Find pre-loved essentials and useful skills from people on your campus.',
          ),
          (
            Icons.photo_library_outlined,
            'Find it. See it. Make it yours.',
            'Browse or search, filter your finds, and tap a photo to enlarge it. Prices are in SAR.',
          ),
          (
            Icons.handshake_outlined,
            'Buy and sell with confidence',
            'Pay cash on delivery. Only share your delivery code after receiving your item. Never share it in advance.',
          ),
          (
            Icons.handyman_outlined,
            'Share your skills',
            'Offer a service or send a request. Track replies in your inbox and keep your contact details up to date.',
          ),
        ];
        final step = steps[_step];
        panel = _StartupPanel(
          key: ValueKey(_step),
          icon: step.$1,
          title: step.$2,
          body: step.$3,
          eyebrow: '${_step + 1} / ${steps.length}',
          action: _step == steps.length - 1 ? 'Start exploring' : 'Next',
          busy: _saving,
          onAction: () => _step == steps.length - 1
              ? _finish(identity, uid)
              : setState(() => _step++),
          secondary: _step > 0
              ? TextButton(
                  onPressed: _saving ? null : () => setState(() => _step--),
                  child: const Text('Back'),
                )
              : null,
        );
      }
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        ExcludeSemantics(
          excluding: panel != null,
          child: ExcludeFocus(
            excluding: panel != null,
            child: IgnorePointer(ignoring: panel != null, child: widget.child),
          ),
        ),
        if (panel != null)
          Positioned.fill(
            child: PopScope(
              canPop: false,
              child: Material(
                color: Theme.of(context).scaffoldBackgroundColor,
                child: SafeArea(
                  child: Column(
                    children: [
                      Align(
                        alignment: AlignmentDirectional.centerEnd,
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              TextButton(
                                onPressed: () => ref
                                    .read(localeProvider.notifier)
                                    .setLanguage(AppLanguage.english),
                                child: const Text('English'),
                              ),
                              TextButton(
                                onPressed: () => ref
                                    .read(localeProvider.notifier)
                                    .setLanguage(AppLanguage.arabic),
                                child: const Text('العربية'),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Expanded(child: panel),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _StartupPanel extends StatelessWidget {
  const _StartupPanel({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    required this.action,
    required this.onAction,
    this.eyebrow,
    this.secondary,
    this.busy = false,
  });
  final IconData icon;
  final String title, body, action;
  final String? eyebrow;
  final VoidCallback onAction;
  final Widget? secondary;
  final bool busy;
  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540),
        child: FadeSlideIn(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                child: Container(
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(36),
                  ),
                  child: Icon(
                    icon,
                    size: 64,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
              const SizedBox(height: 28),
              if (eyebrow != null) ...[
                Text(
                  eyebrow!,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: 12),
              ],
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 16),
              Text(
                context.tr(body),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge
                    ?.copyWith(height: 1.6),
              ),
              const SizedBox(height: 32),
              FilledButton(
                onPressed: busy ? null : onAction,
                child: busy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(action),
              ),
              ?secondary,
            ],
          ),
        ),
      ),
    ),
  );
}
