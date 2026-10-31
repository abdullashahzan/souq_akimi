import 'package:souq_akimi/widgets/ui.dart';

import '../../core/l10n.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_config.dart';
import '../../core/feedback.dart';
import '../../core/format.dart';
import '../../models/delivery.dart';
import '../../providers/auth.dart';
import '../../providers/dependencies.dart';
import '../../providers/orders.dart';
import '../../widgets/common.dart';
import '../../widgets/listing_image.dart';

/// The buyer's view of one order: the items, where they are going, and the
/// 6-digit hand-over code that completes each seller's delivery.
class OrderDetailScreen extends ConsumerStatefulWidget {
  const OrderDetailScreen({super.key, required this.orderNumber});

  final String orderNumber;

  @override
  ConsumerState<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends ConsumerState<OrderDetailScreen> {
  /// Codes already revealed on this screen, with the time they were fetched,
  /// so re-opening the sheet does not burn a round trip.
  final Map<String, ({String code, DateTime at, int remaining})> _otpCache = {};
  bool _busy = false;

  Future<void> _cancelOrder() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel this order?'),
        content: const Text(
          'The seller will not deliver it, and the items go back on sale. '
          'This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep it'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Cancel order'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await ref.read(orderRepositoryProvider).cancelOrder(widget.orderNumber);
      if (mounted) showMessage('Order cancelled.');
    } catch (error) {
      if (mounted) showError(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _revealCode(Delivery delivery) async {
    final cached = _otpCache[delivery.id];
    final fresh =
        cached != null &&
        DateTime.now().difference(cached.at) < AppConfig.otpSessionLifetime;
    if (fresh) {
      _showCodeSheet(cached.code, cached.remaining, delivery);
      return;
    }

    setState(() => _busy = true);
    try {
      final result = await ref
          .read(orderRepositoryProvider)
          .getDeliveryOtp(
            orderNumber: widget.orderNumber,
            deliveryId: delivery.id,
          );
      final entry = (
        code: result.otp,
        at: DateTime.now(),
        remaining: result.attemptsRemaining,
      );
      _otpCache[delivery.id] = entry;
      if (mounted) _showCodeSheet(entry.code, entry.remaining, delivery);
    } catch (error) {
      if (mounted) showError(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showCodeSheet(String code, int remaining, Delivery delivery) {
    final theme = Theme.of(context);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              context.tr(
                'Show this to @{seller}',
                args: {'seller': delivery.sellerUsername},
              ),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              'They type it into their phone when they hand over the item.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer
                    .withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                code,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.displaySmall
                    ?.copyWith(fontWeight: FontWeight.w800, letterSpacing: 10),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              context.tr(
                '{remaining} of {max} attempts left',
                args: {
                  'remaining': '$remaining',
                  'max': '${AppConfig.otpMaxAttempts}',
                },
              ),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: remaining <= 0
                    ? theme.colorScheme.error
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (remaining <= 0) ...[
              const SizedBox(height: 12),
              Text(
                'That is every try used up. Mint a fresh code and read that '
                'one out instead — the old one stops working.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: _busy ? null : () => _rotateCode(delivery),
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Generate a new code'),
              ),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Done'),
            ),
          ],
        ),
      ),
    );
  }

  /// Mints a new hand-over code after a seller is locked out (five wrong
  /// guesses), then reopens the sheet with the fresh code and reset counter.
  Future<void> _rotateCode(Delivery delivery) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final repository = ref.read(orderRepositoryProvider);
      await repository.rotateDeliveryCode(
        orderNumber: widget.orderNumber,
        deliveryId: delivery.id,
      );
      _otpCache.remove(delivery.id);
      final result = await repository.getDeliveryOtp(
        orderNumber: widget.orderNumber,
        deliveryId: delivery.id,
      );
      _otpCache[delivery.id] = (
        code: result.otp,
        at: DateTime.now(),
        remaining: result.attemptsRemaining,
      );
      if (mounted) {
        Navigator.of(context).pop();
        await Future<void>.delayed(const Duration(milliseconds: 120));
        if (mounted) _revealCode(delivery);
      }
    } catch (error) {
      if (mounted) showError(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final orderAsync = ref.watch(orderProvider(widget.orderNumber));
    final deliveriesAsync = ref.watch(deliveriesProvider(widget.orderNumber));
    final uid = ref.watch(currentUidProvider);

    return orderAsync.when(
      loading: () => Scaffold(
        appBar: AppBar(leading: const SouqBackButton(fallback: '/orders')),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => Scaffold(
        appBar: AppBar(leading: const SouqBackButton(fallback: '/orders')),
        body: ErrorRetry(
          error: error,
          onRetry: () => ref.invalidate(orderProvider(widget.orderNumber)),
        ),
      ),
      data: (order) {
        if (order == null) {
          return Scaffold(
            appBar: AppBar(leading: const SouqBackButton(fallback: '/orders')),
            body: const EmptyState(
              icon: Icons.receipt_long_outlined,
              title: 'Order not found',
              message: 'Check the order number and try again.',
            ),
          );
        }
        final deliveries = deliveriesAsync.value ?? const <Delivery>[];
        final theme = Theme.of(context);
        final canCancel = order.isCancellable && uid == order.userId && !_busy;

        return Scaffold(
          appBar: AppBar(
            title: Text('#${order.orderNumber}'),
            leading: const SouqBackButton(fallback: '/orders'),
            actions: [
              if (canCancel)
                TextButton(
                  onPressed: _cancelOrder,
                  child: const Text('Cancel'),
                ),
              const SizedBox(width: 8),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                children: [
                  StatusChip.order(order.status),
                  const SizedBox(width: 8),
                  const StatusChip(
                    label: 'Cash on delivery',
                    color: Color(0xFF274690),
                    dense: true,
                  ),
                  const Spacer(),
                  Text(
                    Format.dateTime(order.createdAt),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // ---- Where it goes -----------------------------------------
              Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.apartment_outlined,
                            size: 18,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              context.tr(
                                'Deliver to {address}',
                                args: {'address': order.deliveryAddress},
                              ),
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${order.fullName} · ${order.phone}',
                        style: theme.textTheme.bodyMedium,
                      ),
                      if (order.deliveryNotes.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          '"${order.deliveryNotes}"',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // ---- Items ---------------------------------------------------
              SectionHeader(
                title: context.tr(
                  'Items ({count})',
                  args: {'count': '${order.items.length}'},
                ),
              ),
              Card(
                margin: EdgeInsets.zero,
                child: Column(
                  children: [
                    for (var i = 0; i < order.items.length; i++) ...[
                      if (i > 0) const Divider(height: 1),
                      ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                        ),
                        leading: SizedBox(
                          width: 44,
                          height: 44,
                          child: ListingImage(
                            url: '',
                            label: order.items[i].productName,
                            seed: order.items[i].productId,
                          ),
                        ),
                        title: Text(
                          order.items[i].productName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          '${order.items[i].quantity} × '
                          '${Format.money(order.items[i].price)} · '
                          '\u200E@${order.items[i].sellerUsername}',
                        ),
                        trailing: Text(
                          Format.money(order.items[i].lineTotal),
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        onTap: () => context.push(
                          '/product/${order.items[i].productId}',
                        ),
                      ),
                    ],
                    const Divider(height: 1),
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                      ),
                      title: const Text(
                        'Total · cash on delivery',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      trailing: Text(
                        Format.money(order.total),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ---- Deliveries ---------------------------------------------
              SectionHeader(
                title: context.tr(
                  'Deliveries ({count})',
                  args: {'count': '${deliveries.length}'},
                ),
                trailing: deliveries.length > 1
                    ? Text('One per seller', style: theme.textTheme.labelSmall)
                    : null,
              ),
              if (deliveries.isEmpty)
                Card(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'Preparing…',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                )
              else
                for (final delivery in deliveries) ...[
                  _DeliveryCard(
                    delivery: delivery,
                    busy: _busy,
                    onReveal: () => _revealCode(delivery),
                  ),
                  const SizedBox(height: 12),
                ],
            ],
          ),
        );
      },
    );
  }
}

class _DeliveryCard extends StatelessWidget {
  const _DeliveryCard({
    required this.delivery,
    required this.busy,
    required this.onReveal,
  });

  final Delivery delivery;
  final bool busy;
  final VoidCallback onReveal;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '\u200E@${delivery.sellerUsername}',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                StatusChip.delivery(delivery.status, dense: true),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              Format.money(delivery.amount),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            if (delivery.deliveredAt != null) ...[
              const SizedBox(height: 4),
              Text(
                context.tr(
                  'Delivered {date}',
                  args: {'date': Format.dateTime(delivery.deliveredAt)},
                ),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 12),
            // Wrap, not Row: the label is long enough to overflow a narrow
            // phone, and a wrap simply puts the button on its own line.
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (delivery.canBeReleased)
                  FilledButton.icon(
                    onPressed: busy ? null : onReveal,
                    icon: const Icon(Icons.password_outlined, size: 18),
                    label: const Text('Show hand-over code'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
