import 'package:souq_akimi/widgets/ui.dart';
import '../../core/l10n.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../providers/orders.dart';
import '../../widgets/common.dart';

/// The screen right after a successful `placeOrder`: what was ordered, what
/// happens next, and where to find the hand-over code.
class OrderConfirmationScreen extends ConsumerWidget {
  const OrderConfirmationScreen({super.key, required this.orderNumber});

  final String orderNumber;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orderAsync = ref.watch(orderProvider(orderNumber));
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final order = orderAsync.value;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Order placed'),
        leading: const SouqBackButton(),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: scheme.primary.withValues(alpha: 0.12),
              ),
              child: Icon(
                Icons.check_circle_outline,
                size: 56,
                color: scheme.primary,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              context.tr('Order {number}', args: {'number': orderNumber}),
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              order == null
                  ? context.tr('Your order is being written to the ledger.')
                  : order.items.length == 1
                  ? context.tr(
                      '{count} item · {total} cash on delivery',
                      args: {
                        'count': '1',
                        'total': Format.money(order.total),
                      },
                    )
                  : context.tr(
                      '{count} items · {total} cash on delivery',
                      args: {
                        'count': '${order.items.length}',
                        'total': Format.money(order.total),
                      },
                    ),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 28),
            Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'What happens next',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const _Step(
                      icon: Icons.inventory_2_outlined,
                      title: 'The seller prepares your item',
                      body:
                          'They bring it to your hostel room. You can follow '
                          'the delivery from My orders.',
                    ),
                    const _Step(
                      icon: Icons.password_outlined,
                      title: 'Show your 6-digit hand-over code',
                      body:
                          'Open the order, reveal the code and read it to the '
                          'seller when the item arrives.',
                    ),
                    const _Step(
                      icon: Icons.payments_outlined,
                      title: 'Pay cash at the door',
                      body:
                          'Hand over the exact amount when you receive the '
                          'item. Nothing is charged in the app.',
                    ),
                  ],
                ),
              ),
            ),
            const Spacer(),
            FilledButton(
              onPressed: () => context.go('/order/$orderNumber'),
              child: const Text('View order'),
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: () => context.go('/'),
              child: const Text('Keep browsing'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.icon, required this.title, required this.body});

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: theme.colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  body,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
