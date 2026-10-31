import 'package:souq_akimi/widgets/ui.dart';

import '../core/l10n.dart';

import 'package:go_router/go_router.dart';

import '../core/feedback.dart';
import '../models/enums.dart';

/// A back arrow that is always safe to press.
///
/// Pushed screens simply pop. A tab root has nothing to pop, so it falls back
/// to [fallback] — that way the control is visible and useful on every screen,
/// instead of throwing GoError("There is nothing to pop").
class SouqBackButton extends StatelessWidget {
  const SouqBackButton({super.key, this.fallback = '/'});

  final String fallback;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: context.tr('Back'),
      icon: const BackButtonIcon(),
      onPressed: () => context.canPop() ? context.pop() : context.go(fallback),
    );
  }
}

/// A small rounded pill, tinted by meaning: pending blue, delivered green,
/// cancelled grey.
class StatusChip extends StatelessWidget {
  const StatusChip({
    super.key,
    required this.label,
    required this.color,
    this.icon,
    this.dense = false,
  });

  final String label;
  final Color color;
  final IconData? icon;
  final bool dense;

  factory StatusChip.order(OrderStatus status, {bool dense = false}) =>
      StatusChip(label: status.label, color: _orderColor(status), dense: dense);

  factory StatusChip.delivery(DeliveryStatus status, {bool dense = false}) =>
      StatusChip(
        label: status.label,
        color: _deliveryColor(status),
        dense: dense,
      );

  factory StatusChip.serviceRequest(
    ServiceRequestStatus status, {
    bool dense = false,
  }) => StatusChip(
    label: status.label,
    color: _requestColor(status),
    dense: dense,
  );

  factory StatusChip.condition(Condition condition, {bool dense = false}) =>
      StatusChip(
        label: condition.label,
        color: condition == Condition.brandNew
            ? const Color(0xFF1B7F5A)
            : const Color(0xFF6B6B6B),
        dense: dense,
      );

  static Color _orderColor(OrderStatus status) => switch (status) {
    OrderStatus.delivered => const Color(0xFF1B7F5A),
    OrderStatus.pending => const Color(0xFF274690),
    OrderStatus.cancelled => const Color(0xFF6B6B6B),
  };

  static Color _deliveryColor(DeliveryStatus status) => switch (status) {
    DeliveryStatus.ready => const Color(0xFF274690),
    DeliveryStatus.delivered => const Color(0xFF1B7F5A),
    DeliveryStatus.cancelled => const Color(0xFF6B6B6B),
  };

  static Color _requestColor(ServiceRequestStatus status) => switch (status) {
    ServiceRequestStatus.pending => const Color(0xFFB7791F),
    ServiceRequestStatus.accepted => const Color(0xFF1B7F5A),
    ServiceRequestStatus.declined => const Color(0xFF8A3B12),
    ServiceRequestStatus.cancelled => const Color(0xFF6B6B6B),
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 8 : 10,
        vertical: dense ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: dense ? 12 : 14, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: dense ? 11 : 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Centred "nothing here yet" placeholder with an optional action.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 86,
                height: 86,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      scheme.primaryContainer,
                      scheme.primary.withValues(alpha: 0.08),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: scheme.primary.withValues(alpha: 0.12),
                  ),
                ),
                child: Icon(icon, size: 38, color: scheme.primary),
              ),
              const SizedBox(height: 18),
              Text(
                title,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (message != null) ...[
                const SizedBox(height: 8),
                Text(
                  message!,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                    height: 1.45,
                  ),
                ),
              ],
              if (action != null) ...[
                const SizedBox(height: 22),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 260),
                  child: action!,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// A compact error panel with a retry button, used for stream errors.
///
/// The message goes through [describeError] so a raw Firestore failure never
/// reaches the student; debug builds still show the real text.
class ErrorRetry extends StatelessWidget {
  const ErrorRetry({super.key, required this.error, this.onRetry, this.title});

  final Object error;
  final VoidCallback? onRetry;

  /// Overrides the default heading for screens with a more specific story.
  final String? title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_outlined, size: 48, color: scheme.error),
            const SizedBox(height: 12),
            Text(
              title ?? 'That did not load',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              describeError(error),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Try again'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A titled section used down the browse and detail screens.
class SectionHeader extends StatelessWidget {
  const SectionHeader({super.key, required this.title, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(4, 22, 4, 10),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 19,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: -0.2,
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// A +/- control that respects the product's stock ceiling.
class QuantityStepper extends StatelessWidget {
  const QuantityStepper({
    super.key,
    required this.quantity,
    required this.max,
    required this.onChanged,
  });

  final int quantity;
  final int max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: quantity > 1 ? () => onChanged(quantity - 1) : null,
            icon: const Icon(Icons.remove),
            visualDensity: VisualDensity.compact,
          ),
          SizedBox(
            width: 36,
            child: Text(
              '$quantity',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          IconButton(
            onPressed: quantity < max ? () => onChanged(quantity + 1) : null,
            icon: const Icon(Icons.add),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}
