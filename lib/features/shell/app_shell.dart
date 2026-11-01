import 'package:souq_akimi/widgets/ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_config.dart';
import '../../core/l10n.dart';
import '../../core/motion.dart';
import '../../providers/auth.dart';
import '../../providers/locale.dart';
import '../../providers/notifications.dart';
import '../../widgets/notification_alerts.dart';

/// The signed-in shell: a floating bottom navigation bar that is present on
/// **every** app screen, plus the "new orders" badge on the Orders tab.
///
/// All app routes live inside this shell (see `router.dart`), so opening a
/// listing, checking out or reading an order never hides the tabs.
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.child, required this.location});

  final Widget child;
  final String location;

  static const List<String> _tabRoutes = [
    '/',
    '/services',
    '/sell',
    '/orders',
    '/profile',
  ];

  /// Which tab should look selected for [path].
  static int indexFor(String path) {
    if (path.startsWith('/services') ||
        path.startsWith('/service/') ||
        path.startsWith('/requests')) {
      return 1;
    }
    if (path.startsWith('/sell') ||
        path.startsWith('/my-listings') ||
        path.startsWith('/offer') ||
        path.startsWith('/my-services')) {
      return 2;
    }
    if (path.startsWith('/orders') ||
        path.startsWith('/sales') ||
        path.startsWith('/order/') ||
        path.startsWith('/sale/') ||
        path.startsWith('/notifications')) {
      return 3;
    }
    if (path.startsWith('/profile') || path.startsWith('/admin')) return 4;
    return 0;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(localeProvider);
    final badge = ref.watch(unreadNotificationCountProvider);
    final serviceBadge = ref.watch(unreadServiceNotificationCountProvider);
    final signedIn = ref.watch(isSignedInProvider);
    // Keep this account's real profile warm for listing handles and defaults.
    // A one-off read in a form may otherwise return the email-based fallback.
    if (signedIn) ref.watch(profileProvider);
    final index = indexFor(location);

    return Scaffold(
      extendBody: false,
      body: signedIn ? NotificationAlerts(child: child) : child,
      bottomNavigationBar: _SouqBottomNav(
        selectedIndex: index,
        orderBadge: signedIn ? badge : 0,
        serviceBadge: signedIn ? serviceBadge : 0,
        onSelected: (next) {
          if (next == index && location == _tabRoutes[next]) return;
          context.go(_tabRoutes[next]);
        },
        items: [
          _NavItem(
            icon: Icons.storefront_outlined,
            selectedIcon: Icons.storefront_rounded,
            label: context.tr('Browse'),
          ),
          _NavItem(
            icon: Icons.handyman_outlined,
            selectedIcon: Icons.handyman_rounded,
            label: context.tr('Services'),
          ),
          _NavItem(
            icon: Icons.add_rounded,
            selectedIcon: Icons.add_rounded,
            label: context.tr('Sell'),
            prominent: true,
          ),
          _NavItem(
            icon: Icons.receipt_long_outlined,
            selectedIcon: Icons.receipt_long_rounded,
            label: context.tr('Orders'),
          ),
          _NavItem(
            icon: Icons.person_outline_rounded,
            selectedIcon: Icons.person_rounded,
            label: context.tr('Profile'),
          ),
        ],
      ),
    );
  }
}

class _NavItem {
  const _NavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    this.prominent = false,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool prominent;
}

class _SouqBottomNav extends StatelessWidget {
  const _SouqBottomNav({
    required this.items,
    required this.selectedIndex,
    required this.orderBadge,
    required this.serviceBadge,
    required this.onSelected,
  });

  final List<_NavItem> items;
  final int selectedIndex;
  final int orderBadge;
  final int serviceBadge;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.only(bottom: 8),
      child: Center(
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 7),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: scheme.outlineVariant.withValues(alpha: 0.75),
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x160B1F18),
                  blurRadius: 30,
                  offset: Offset(0, 12),
                ),
              ],
            ),
            child: LayoutBuilder(
              builder: (context, constraints) => Stack(
                children: [
                  AnimatedPositionedDirectional(
                    duration: Motion.reduced(context)
                        ? Duration.zero
                        : Motion.slow,
                    curve: Motion.spring,
                    start: constraints.maxWidth * selectedIndex / items.length,
                    width: constraints.maxWidth / items.length,
                    top: 0,
                    bottom: 0,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: scheme.primary.withValues(alpha: 0.09),
                        borderRadius: BorderRadius.circular(22),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      for (var i = 0; i < items.length; i++)
                        Expanded(
                          child: _NavButton(
                            item: items[i],
                            selected: selectedIndex == i,
                            badge: i == 1
                                ? serviceBadge
                                : (i == 3 ? orderBadge : 0),
                            onTap: () => onSelected(i),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.item,
    required this.selected,
    required this.badge,
    required this.onTap,
  });

  final _NavItem item;
  final bool selected;
  final int badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final foreground = selected ? scheme.primary : scheme.onSurfaceVariant;
    final icon = selected ? item.selectedIcon : item.icon;

    return Semantics(
      button: true,
      selected: selected,
      label: item.label,
      child: PressableScale(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
          child: AnimatedContainer(
            duration: Motion.reduced(context) ? Duration.zero : Motion.medium,
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(22),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    gradient: item.prominent
                        ? const LinearGradient(
                            colors: [Color(0xFF0B5D4B), Color(0xFF14897A)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : null,
                    color: item.prominent ? null : Colors.transparent,
                    borderRadius: BorderRadius.circular(13),
                    boxShadow: item.prominent
                        ? const [
                            BoxShadow(
                              color: Color(0x330B5D4B),
                              blurRadius: 14,
                              offset: Offset(0, 6),
                            ),
                          ]
                        : null,
                  ),
                  child: Badge(
                    isLabelVisible: badge > 0,
                    label: Text('$badge'),
                    backgroundColor: scheme.error,
                    child: MotionSwitcher(
                      child: Icon(
                        icon,
                        key: ValueKey(icon),
                        size: 23,
                        color: item.prominent ? Colors.white : foreground,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: item.prominent ? scheme.primary : foreground,
                    fontWeight: selected || item.prominent
                        ? FontWeight.w800
                        : FontWeight.w600,
                    fontSize: 10.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A scroll-friendly app title used on tab roots.
class SouqAppBarTitle extends StatelessWidget {
  const SouqAppBarTitle({super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      context.tr(AppConfig.appNameEnglish),
      style: Theme.of(context).textTheme.titleLarge
          ?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.4),
    );
  }
}
