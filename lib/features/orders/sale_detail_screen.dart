import 'package:souq_akimi/widgets/ui.dart';

import '../../core/l10n.dart';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_config.dart';
import '../../core/feedback.dart';
import '../../core/format.dart';
import '../../models/delivery.dart';
import '../../models/enums.dart';
import '../../providers/auth.dart';
import '../../providers/dependencies.dart';
import '../../providers/orders.dart';
import '../../widgets/common.dart';
import '../../widgets/listing_image.dart';

/// The seller's side of an order: what the buyer ordered from them, where to
/// deliver it, and the one field that completes the delivery — the buyer's
/// 6-digit hand-over code.
class SaleDetailScreen extends ConsumerStatefulWidget {
  const SaleDetailScreen({super.key, required this.orderNumber});

  final String orderNumber;

  @override
  ConsumerState<SaleDetailScreen> createState() => _SaleDetailScreenState();
}

class _SaleDetailScreenState extends ConsumerState<SaleDetailScreen> {
  final _code = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _release(Delivery delivery) async {
    final code = _code.text.trim();
    if (code.length != 6) {
      showMessage('The code is 6 digits.');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _busy = true);
    try {
      final orderStatus = await ref
          .read(orderRepositoryProvider)
          .releaseDelivery(
            orderNumber: widget.orderNumber,
            deliveryId: delivery.id,
            code: code,
          );
      _code.clear();
      if (mounted) {
        showMessage(
          orderStatus == OrderStatus.delivered.value
              ? 'Delivery confirmed. Order complete.'
              : 'Delivery confirmed.',
        );
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
    final uid = ref.watch(currentUidProvider) ?? '';

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

        final allDeliveries = deliveriesAsync.value ?? const <Delivery>[];
        final myItems = order.items
            .where((item) => item.sellerId == uid)
            .toList();
        final forMe = allDeliveries.where((d) => d.sellerId == uid);
        final myDelivery = forMe.isEmpty ? null : forMe.first;
        final theme = Theme.of(context);

        return Scaffold(
          appBar: AppBar(
            title: Text('#${order.orderNumber}'),
            leading: const SouqBackButton(fallback: '/orders'),
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

              // ---- Where to deliver --------------------------------------
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

              // ---- What I sold --------------------------------------------
              SectionHeader(
                title: context.tr(
                  'Your items ({count})',
                  args: {'count': '${myItems.length}'},
                ),
              ),
              Card(
                margin: EdgeInsets.zero,
                child: Column(
                  children: [
                    for (var i = 0; i < myItems.length; i++) ...[
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
                            label: myItems[i].productName,
                            seed: myItems[i].productId,
                          ),
                        ),
                        title: Text(
                          myItems[i].productName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          '${myItems[i].quantity} × '
                          '${Format.money(myItems[i].price)}',
                        ),
                        trailing: Text(
                          Format.money(myItems[i].lineTotal),
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        onTap: () =>
                            context.push('/product/${myItems[i].productId}'),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),

              if (myDelivery == null)
                Card(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'This order does not contain your items (yet).',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                )
              else ...[
                SectionHeader(title: 'Your delivery'),
                _HandoverCard(
                  delivery: myDelivery,
                  busy: _busy,
                  controller: _code,
                  onRelease: () => _release(myDelivery),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _HandoverCard extends StatelessWidget {
  const _HandoverCard({
    required this.delivery,
    required this.busy,
    required this.controller,
    required this.onRelease,
  });

  final Delivery delivery;
  final bool busy;
  final TextEditingController controller;
  final VoidCallback onRelease;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final done = delivery.isDelivered;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    Format.money(delivery.amount),
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                StatusChip.delivery(delivery.status, dense: true),
              ],
            ),
            const SizedBox(height: 14),
            if (done)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF1B7F5A).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Color(0xFF1B7F5A)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Delivered — this order is complete.',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              )
            else if (delivery.canBeReleased) ...[
              Text(
                'Ask the buyer for their 6-digit code when you hand over the '
                'item and collect the cash.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: controller,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                maxLength: 6,
                style: theme.textTheme.headlineSmall?.copyWith(
                  letterSpacing: 12,
                  fontWeight: FontWeight.w800,
                ),
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  counterText: '',
                  hintText: '••••••',
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: busy ? null : onRelease,
                icon: const Icon(Icons.lock_open_outlined, size: 18),
                label: Text(busy ? 'Checking…' : 'Confirm delivery'),
              ),
              if (delivery.attemptsRemaining < AppConfig.otpMaxAttempts) ...[
                const SizedBox(height: 8),
                Text(
                  context.tr(
                    '{count} attempts left before the buyer is asked for a new code.',
                    args: {'count': '${delivery.attemptsRemaining}'},
                  ),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ],
            ] else
              Text(
                'This delivery was cancelled.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
