import 'package:souq_akimi/widgets/ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/feedback.dart';
import '../../models/app_notification.dart';
import '../../providers/auth.dart';
import '../../providers/dependencies.dart';
import '../../providers/notifications.dart';
import '../../widgets/common.dart';

/// The seller's in-app inbox.
///
/// New orders are written here by the buyer's device in the same transaction
/// that creates the order. Only tapping an entry or explicitly choosing
/// "Mark all read" clears it; merely viewing the inbox never loses unread work.
class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  Future<void> _markAllRead() async {
    final uid = ref.read(currentUidProvider);
    if (uid == null) return;
    try {
      await ref.read(notificationRepositoryProvider).markAllRead(uid);
      if (mounted) showMessage('Notifications marked read.');
    } catch (error) {
      if (mounted) showError(error);
    }
  }

  Future<void> _open(AppNotification item) async {
    final uid = ref.read(currentUidProvider);
    if (uid != null && !item.read) {
      ref
          .read(notificationRepositoryProvider)
          .markRead(uid, item.id)
          .catchError((Object _) {});
    }
    if (!mounted) return;
    if (!item.isAnnouncement) context.push(item.destination);
  }

  @override
  Widget build(BuildContext context) {
    final inboxAsync = ref.watch(notificationsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        leading: const SouqBackButton(fallback: '/orders'),
        actions: [
          TextButton(
            onPressed: _markAllRead,
            child: const Text('Mark all read'),
          ),
        ],
      ),
      body: inboxAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => ErrorRetry(
          error: error,
          onRetry: () => ref.invalidate(notificationsProvider),
        ),
        data: (items) {
          if (items.isEmpty) {
            return const EmptyState(
              icon: Icons.notifications_none,
              title: 'No notifications yet',
              message: 'New orders, service requests and campus announcements will appear here.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final item = items[index];
              return _NotificationTile(item: item, onTap: () => _open(item));
            },
          );
        },
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.item, required this.onTap});

  final AppNotification item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        onTap: onTap,
        leading: Stack(
          clipBehavior: Clip.none,
          children: [
            CircleAvatar(
              backgroundColor: theme.colorScheme.primaryContainer,
              child: Icon(switch (item.type) {
                AppNotification.typeAnnouncement => Icons.campaign_outlined,
                AppNotification.typeRequestCompleted ||
                AppNotification.typeServiceRequest ||
                AppNotification.typeRequestAccepted ||
                AppNotification.typeRequestDeclined ||
                AppNotification.typeRequestCancelled => Icons.handyman_outlined,
                _ => Icons.shopping_bag_outlined,
              }, color: theme.colorScheme.onPrimaryContainer),
            ),
            if (!item.read)
              Positioned(
                right: -1,
                top: -1,
                child: Container(
                  width: 11,
                  height: 11,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: theme.colorScheme.error,
                    border: Border.all(
                      color: theme.colorScheme.surface,
                      width: 2,
                    ),
                  ),
                ),
              ),
          ],
        ),
        title: Text(
          item.title,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: item.read ? FontWeight.w600 : FontWeight.w800,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 2),
            Text(item.body, style: theme.textTheme.bodySmall),
            if (item.createdAt != null) ...[
              const SizedBox(height: 4),
              Text(
                Format.relative(item.createdAt!),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}
