import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/app_notification.dart';
import '../core/l10n.dart';
import '../providers/auth.dart';
import '../providers/dependencies.dart';
import '../providers/notifications.dart';
import 'ui.dart';

/// Immediate, accessible foreground alerts. The durable inbox remains the
/// source of truth; dismissing an alert never marks the notification as read.
class NotificationAlerts extends ConsumerStatefulWidget {
  const NotificationAlerts({super.key, required this.child});
  final Widget child;

  @override
  ConsumerState<NotificationAlerts> createState() => _NotificationAlertsState();
}

class _NotificationAlertsState extends ConsumerState<NotificationAlerts> {
  AppNotification? _alert;
  String? _uid;
  Set<String> _seen = {};

  void _receive(List<AppNotification> items, String uid) {
    final prefs = ref.read(sharedPreferencesProvider);
    if (_uid != uid) {
      _uid = uid;
      _seen = (prefs.getStringList('inbox.alerts.$uid') ?? []).toSet();
      _alert = null;
    }
    final fresh = items
        .where((n) => n.userId == uid && !n.read && !_seen.contains(n.id))
        .toList();
    _seen.addAll(items.map((n) => n.id));
    // Bounded local history prevents alerts replaying on reconnect or rebuild.
    final keep = _seen.toList();
    prefs.setStringList(
      'inbox.alerts.$uid',
      keep.length > 300 ? keep.sublist(keep.length - 300) : keep,
    );
    if (fresh.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && ref.read(currentUidProvider) == uid) {
        setState(() => _alert = fresh.first);
      }
    });
  }

  Future<void> _open(AppNotification item) async {
    setState(() => _alert = null);
    final uid = ref.read(currentUidProvider);
    if (uid != item.userId) return;
    // Navigation must not wait for the network when the device is offline.
    ref
        .read(notificationRepositoryProvider)
        .markRead(uid!, item.id)
        .catchError((Object _) {});
    context.push(item.destination);
  }

  @override
  Widget build(BuildContext context) {
    final uid = ref.watch(currentUidProvider);
    ref.listen(notificationsProvider, (_, next) {
      if (uid != null && next.hasValue) _receive(next.value!, uid);
    });
    final item = _alert;
    return Stack(
      children: [
        widget.child,
        if (item != null && item.userId == uid)
          PositionedDirectional(
            top: 0,
            start: 12,
            end: 12,
            child: SafeArea(
              bottom: false,
              child: Semantics(
                liveRegion: true,
                child: Card(
                  elevation: 8,
                  child: ListTile(
                    leading: const Icon(Icons.notifications_active_outlined),
                    title: Text(item.title, maxLines: 2),
                    subtitle: Text(
                      item.body,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: () => _open(item),
                    trailing: IconButton(
                      tooltip: context.tr('Dismiss'),
                      icon: const Icon(Icons.close),
                      onPressed: () => setState(() => _alert = null),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class InboxButton extends ConsumerWidget {
  const InboxButton({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Const buttons must rebuild their tooltip when the app language changes.
    Localizations.localeOf(context);
    final count = ref.watch(unreadNotificationCountProvider);
    return IconButton(
      tooltip: context.tr('Notifications'),
      onPressed: () => context.push('/notifications'),
      icon: Badge(
        isLabelVisible: count > 0,
        label: Text(count > 99 ? '99+' : '$count'),
        child: const Icon(Icons.notifications_outlined),
      ),
    );
  }
}
