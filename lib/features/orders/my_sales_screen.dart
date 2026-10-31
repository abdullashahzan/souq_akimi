import 'package:souq_akimi/widgets/ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/l10n.dart';
import '../../core/motion.dart';
import '../../models/order.dart';
import '../../providers/auth.dart';
import '../../providers/notifications.dart';
import '../../providers/orders.dart';
import '../../widgets/common.dart';
import '../../widgets/order_tile.dart';

/// Orders that contain something the signed-in student is selling.
///
/// "My share" is the sum of the line totals whose `sellerId` is me — the same
/// numbers `placeOrder` splits out into deliveries.
class MySalesScreen extends ConsumerWidget {
  const MySalesScreen({super.key});

  double _myShare(Order order, String uid) => order.items
      .where((item) => item.sellerId == uid)
      .fold(0, (sum, item) => sum + item.lineTotal);

  int _myUnits(Order order, String uid) => order.items
      .where((item) => item.sellerId == uid)
      .fold(0, (sum, item) => sum + item.quantity);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final salesAsync = ref.watch(mySalesProvider);
    final unread = ref.watch(unreadNotificationCountProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My sales'),
        leading: const SouqBackButton(fallback: '/orders'),
        actions: [
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
      body: salesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => ErrorRetry(
          error: error,
          onRetry: () => ref.invalidate(mySalesProvider),
        ),
        data: (orders) {
          if (orders.isEmpty) {
            return EmptyState(
              icon: Icons.point_of_sale_outlined,
              title: 'No sales yet',
              message: 'List an item and buyers will find you through search.',
              action: FilledButton.tonal(
                onPressed: () => context.go('/sell'),
                child: const Text('List an item'),
              ),
            );
          }
          final sellerUid = ref.read(currentUidProvider) ?? '';
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: orders.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final order = orders[index];
              final share = _myShare(order, sellerUid);
              return FadeSlideIn(
                index: index,
                child: OrderTile(
                  order: order,
                  onTap: () => context.push('/sale/${order.orderNumber}'),
                  trailing: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        Format.money(share),
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      Text(
                        context.tr(
                          '{count} of yours',
                          args: {'count': '${_myUnits(order, sellerUid)}'},
                        ),
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
