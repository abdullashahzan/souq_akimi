import 'package:souq_akimi/widgets/ui.dart';

import '../core/format.dart';
import '../core/l10n.dart';
import '../models/order.dart';
import 'common.dart';

/// One row in "My orders" / "My sales": order number, status pill, what was
/// bought and for how much.
class OrderTile extends StatelessWidget {
  const OrderTile({super.key, required this.order, this.trailing, this.onTap});

  final Order order;

  /// Right-hand side: `null` → the price; a widget → anything else (used by
  /// sales to show the seller's own share).
  final Widget? trailing;

  final VoidCallback? onTap;

  String _summary(BuildContext context) {
    if (order.items.isEmpty) return context.tr('No items');
    final first = order.items.first;
    final extra = order.items.length - 1;
    return extra == 0
        ? '${first.quantity} × ${first.productName}'
        : '${first.quantity} × ${first.productName} +${context.tr('more', args: {'count': '$extra'})}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '#${order.orderNumber}',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  StatusChip.order(order.status, dense: true),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                _summary(context),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const StatusChip(
                    label: 'Cash on delivery',
                    color: Color(0xFF274690),
                    dense: true,
                  ),
                  const Spacer(),
                  trailing ??
                      Text(
                        Format.money(order.total),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                order.createdAt == null
                    ? context.tr(
                        'To {address}',
                        args: {'address': order.deliveryAddress},
                      )
                    : '${Format.dateTime(order.createdAt)} · '
                          '${context.tr('to {address}', args: {'address': order.deliveryAddress})}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
