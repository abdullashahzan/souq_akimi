import 'package:souq_akimi/widgets/ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n.dart';
import '../../models/enums.dart';
import '../../providers/notifications.dart';
import '../../providers/orders.dart';
import '../../widgets/common.dart';
import '../../widgets/order_tile.dart';

/// Everything the signed-in student has bought, newest first.
class MyOrdersScreen extends ConsumerWidget {
  const MyOrdersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(myOrdersProvider);
    final unread = ref.watch(unreadNotificationCountProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My orders'),
        leading: const SouqBackButton(),
        actions: [
          IconButton(
            tooltip: context.tr('My sales'),
            icon: const Icon(Icons.storefront_outlined),
            onPressed: () => context.push('/sales'),
          ),
          IconButton(
            tooltip: context.tr('Notifications'),
            icon: unread > 0
                ? Badge(
                    label: Text('$unread'),
                    child: const Icon(Icons.notifications_outlined),
                  )
                : const Icon(Icons.notifications_outlined),
            onPressed: () => context.push('/notifications'),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: ordersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => ErrorRetry(
          error: error,
          onRetry: () => ref.invalidate(myOrdersProvider),
        ),
        data: (orders) {
          if (orders.isEmpty) {
            return EmptyState(
              icon: Icons.receipt_long_outlined,
              title: 'No orders yet',
              message: 'Buy something and you can follow its delivery here.',
              action: FilledButton.tonal(
                onPressed: () => context.go('/'),
                child: const Text('Browse the souq'),
              ),
            );
          }
          final active = orders
              .where((o) => o.status == OrderStatus.pending)
              .length;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (active > 0)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    active == 1
                        ? context.tr(
                            '{count} order on the way',
                            args: {'count': '$active'},
                          )
                        : context.tr(
                            '{count} orders on the way',
                            args: {'count': '$active'},
                          ),
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              for (final order in orders) ...[
                OrderTile(
                  order: order,
                  onTap: () => context.push('/order/${order.orderNumber}'),
                ),
                const SizedBox(height: 12),
              ],
            ],
          );
        },
      ),
    );
  }
}
