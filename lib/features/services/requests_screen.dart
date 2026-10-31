import 'package:souq_akimi/widgets/ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/services.dart';

import '../../core/feedback.dart';
import '../../core/format.dart';
import '../../core/l10n.dart';
import '../../core/motion.dart';
import '../../models/enums.dart';
import '../../models/service.dart';
import '../../providers/dependencies.dart';
import '../../providers/orders.dart';
import '../../widgets/common.dart';
import '../../widgets/notification_alerts.dart';

/// The two sides of the service marketplace: briefs I sent, and briefs
/// other students sent me.
class RequestsScreen extends ConsumerWidget {
  const RequestsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = GoRouterState.of(context).uri.queryParameters['tab'];
    return DefaultTabController(
      initialIndex: tab == 'received' ? 1 : 0,
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Requests'),
          actions: const [InboxButton()],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Sent'),
              Tab(text: 'Received'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _RequestList(
              provider: outgoingRequestsProvider,
              side: _Side.outgoing,
              emptyIcon: Icons.outbox_outlined,
              emptyTitle: 'No requests sent',
              emptyMessage:
                  'Find a service you need and send the provider a brief.',
            ),
            _RequestList(
              provider: incomingRequestsProvider,
              side: _Side.incoming,
              emptyIcon: Icons.inbox_outlined,
              emptyTitle: 'Nothing yet',
              emptyMessage:
                  'When students request your services, they show up here.',
            ),
          ],
        ),
      ),
    );
  }
}

enum _Side { outgoing, incoming }

class _RequestList extends ConsumerWidget {
  const _RequestList({
    required this.provider,
    required this.side,
    required this.emptyIcon,
    required this.emptyTitle,
    required this.emptyMessage,
  });

  final StreamProvider<List<ServiceRequest>> provider;
  final _Side side;
  final IconData emptyIcon;
  final String emptyTitle;
  final String emptyMessage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(provider);

    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) =>
          ErrorRetry(error: error, onRetry: () => ref.invalidate(provider)),
      data: (requests) {
        if (requests.isEmpty) {
          return EmptyState(
            icon: emptyIcon,
            title: emptyTitle,
            message: emptyMessage,
          );
        }
        final focused = GoRouterState.of(context)
            .uri
            .queryParameters['request'];
        final sorted = [...requests]
          ..sort((a, b) {
            if (a.id == focused) return -1;
            if (b.id == focused) return 1;
            return requests.indexOf(a).compareTo(requests.indexOf(b));
          });
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: requests.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, index) => FadeSlideIn(
            index: index,
            child: _RequestTile(
              key: ValueKey(sorted[index].id),
              request: sorted[index],
              side: side,
            ),
          ),
        );
      },
    );
  }
}

class _RequestTile extends ConsumerStatefulWidget {
  const _RequestTile({super.key, required this.request, required this.side});

  final ServiceRequest request;
  final _Side side;

  @override
  ConsumerState<_RequestTile> createState() => _RequestTileState();
}

class _RequestTileState extends ConsumerState<_RequestTile> {
  bool _busy = false;
  ServiceRequest get request => widget.request;
  _Side get side => widget.side;

  Future<void> _act(
    BuildContext context,
    WidgetRef ref,
    ServiceRequestStatus status,
  ) async {
    if (_busy) return;
    if (status != ServiceRequestStatus.accepted) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(switch (status) {
            ServiceRequestStatus.completed => 'Mark this request completed?',
            ServiceRequestStatus.declined => 'Decline this request?',
            _ => 'Cancel this request?',
          }),
          content: const Text('The other student will be notified.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Keep request'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Confirm'),
            ),
          ],
        ),
      );
      if (confirmed != true || !context.mounted) return;
    }
    setState(() => _busy = true);
    try {
      if (side == _Side.incoming) {
        await ref.read(serviceRepositoryProvider).respond(request.id, status);
      } else {
        await ref.read(serviceRepositoryProvider).cancel(request.id);
      }
      if (context.mounted) {
        showMessage(switch (status) {
          ServiceRequestStatus.accepted => 'Request accepted.',
          ServiceRequestStatus.completed => 'Request completed.',
          ServiceRequestStatus.declined => 'Request declined.',
          ServiceRequestStatus.cancelled => 'Request cancelled.',
          ServiceRequestStatus.pending => 'Request sent.',
        });
      }
    } catch (error) {
      if (context.mounted) showError(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final otherParty = side == _Side.incoming
        ? '\u200E@${request.requesterUsername}'
        : '\u200E@${request.providerUsername}';

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        side == _Side.incoming
                            ? context.tr(
                                'For "{title}"',
                                args: {'title': request.serviceTitle},
                              )
                            : request.serviceTitle,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        otherParty,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                StatusChip.serviceRequest(request.status),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              request.message,
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
            ),
            if (side == _Side.incoming &&
                (request.phone.isNotEmpty ||
                    request.building.isNotEmpty ||
                    request.roomNumber.isNotEmpty)) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: theme.colorScheme.outlineVariant),
                ),
                child: Wrap(
                  spacing: 14,
                  runSpacing: 6,
                  children: [
                    if (request.phone.isNotEmpty)
                      _ContactBit(
                        icon: Icons.call_outlined,
                        text: request.phone,
                      ),
                    if (request.building.isNotEmpty)
                      _ContactBit(
                        icon: Icons.apartment_outlined,
                        text: Format.building(request.building),
                      ),
                    if (request.roomNumber.isNotEmpty)
                      _ContactBit(
                        icon: Icons.door_front_door_outlined,
                        text: '${context.tr('Room')} ${request.roomNumber}',
                      ),
                  ],
                ),
              ),
            ],
            if (request.createdAt != null) ...[
              const SizedBox(height: 8),
              Text(
                context.tr(
                  'Sent {date}',
                  args: {'date': Format.dateTime(request.createdAt)},
                ),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (side == _Side.incoming &&
                      request.status == ServiceRequestStatus.accepted)
                    FilledButton.tonal(
                      onPressed: _busy
                          ? null
                          : () => _act(
                              context,
                              ref,
                              ServiceRequestStatus.completed,
                            ),
                      child: const Text('Mark completed'),
                    ),
                  if (request.status == ServiceRequestStatus.pending) ...[
                    if (side == _Side.incoming) ...[
                      FilledButton.tonal(
                        onPressed: _busy
                            ? null
                            : () => _act(
                                context,
                                ref,
                                ServiceRequestStatus.accepted,
                              ),
                        child: const Text('Accept'),
                      ),
                      OutlinedButton(
                        onPressed: _busy
                            ? null
                            : () => _act(
                                context,
                                ref,
                                ServiceRequestStatus.declined,
                              ),
                        child: const Text('Decline'),
                      ),
                    ] else ...[
                      OutlinedButton(
                        onPressed: _busy
                            ? null
                            : () => _act(
                                context,
                                ref,
                                ServiceRequestStatus.cancelled,
                              ),
                        child: const Text('Cancel request'),
                      ),
                    ],
                  ],
                  TextButton(
                    onPressed: () =>
                        context.push('/service/${request.serviceId}'),
                    child: const Text('Open'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ContactBit extends StatelessWidget {
  const _ContactBit({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: () {
        Clipboard.setData(ClipboardData(text: text));
        showMessage('Copied.');
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: theme.colorScheme.primary),
          const SizedBox(width: 4),
          Text(
            text,
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
