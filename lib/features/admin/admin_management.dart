import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/app_config.dart';
import '../../core/feedback.dart';
import '../../core/l10n.dart';
import '../../models/app_control.dart';
import '../../providers/admin.dart';
import '../../providers/app_control.dart';
import '../../providers/auth.dart';
import '../../providers/dependencies.dart';
import '../../widgets/common.dart';
import '../../widgets/ai_button.dart';
import '../../widgets/ui.dart';

/// Keep caller-owned form controllers alive until the reverse transition has
/// removed the dialog's overlay, not merely until Navigator.pop completes.
Future<T?> showAdminFormDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
}) async {
  final route = DialogRoute<T>(context: context, builder: builder);
  final result = await Navigator.of(
    context,
    rootNavigator: true,
  ).push<T>(route);
  await route.completed;
  return result;
}

class AdminUsersTab extends ConsumerStatefulWidget {
  const AdminUsersTab({super.key});
  @override
  ConsumerState<AdminUsersTab> createState() => _AdminUsersTabState();
}

class _AdminUsersTabState extends ConsumerState<AdminUsersTab> {
  String _query = '';
  bool _busy = false;

  Future<void> _moderate(AdminUser user, String status) async {
    final reason = TextEditingController();
    final confirm = TextEditingController();
    final form = GlobalKey<FormState>();
    final ok = await showAdminFormDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          status == 'deleted'
              ? 'Remove user from marketplace?'
              : status == 'active'
              ? 'Restore user access?'
              : 'Suspend user?',
        ),
        content: SingleChildScrollView(
          child: Form(
            key: form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('@${user.username.isEmpty ? user.uid : user.username}'),
                const SizedBox(height: 12),
                Text(
                  status == 'deleted'
                      ? 'This blocks the user and permanently removes their marketplace profile, listings, services, photos and inbox. Order/request history is retained. Their Firebase login must be deleted separately using the trusted admin tool.'
                      : status == 'active'
                      ? 'Access will be restored. Listings stay paused until reviewed.'
                      : 'The user will be blocked from marketplace actions and their listings will be paused.',
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: reason,
                  maxLength: 1000,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: context.tr('Reason shown to user'),
                  ),
                  validator: (value) => (value ?? '').trim().isEmpty
                      ? context.tr('A moderation reason is required.')
                      : null,
                ),
                if (status == 'deleted')
                  TextFormField(
                    controller: confirm,
                    decoration: InputDecoration(
                      labelText: context.tr('Type DELETE to confirm'),
                    ),
                    validator: (value) => value == 'DELETE'
                        ? null
                        : context.tr('Type DELETE to confirm'),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (form.currentState!.validate()) Navigator.pop(context, true);
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    final note = reason.text;
    reason.dispose();
    confirm.dispose();
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(adminRepositoryProvider)
          .moderateUser(
            user: user,
            actorUid: ref.read(currentUidProvider)!,
            status: status,
            reason: note,
          );
      ref.invalidate(adminStatsProvider);
      if (mounted) showMessage('User access updated.');
    } catch (error) {
      if (mounted) showError(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final users = ref.watch(adminUsersProvider);
    final access = ref.watch(adminAccessProvider);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            onChanged: (value) =>
                setState(() => _query = value.trim().toLowerCase()),
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: context.tr('Search username, email or UID'),
            ),
          ),
        ),
        if (_busy) const LinearProgressIndicator(),
        Expanded(
          child: users.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => ErrorRetry(
              error: error,
              onRetry: () => ref.invalidate(adminUsersProvider),
            ),
            data: (items) => access.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => ErrorRetry(
                error: error,
                onRetry: () => ref.invalidate(adminAccessProvider),
              ),
              data: (states) {
                final combined = [
                  ...items,
                  for (final uid in states.keys.where(
                    (uid) => !items.any((user) => user.uid == uid),
                  ))
                    AdminUser(uid, const {}),
                ];
                final filtered = combined
                    .where(
                      (user) => '${user.username} ${user.email} ${user.uid}'
                          .toLowerCase()
                          .contains(_query),
                    )
                    .toList();
                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
                  children: [
                    const SoftBanner(
                      icon: Icons.security_outlined,
                      text: 'Suspension is reversible. Removal is permanent. The administrator account is protected.',
                    ),
                    const SizedBox(height: 12),
                    for (final user in filtered)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                user.username.isEmpty
                                    ? user.uid
                                    : '@${user.username}',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              if (user.email.isNotEmpty)
                                SelectableText(user.email),
                              SelectableText(
                                user.uid,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              const SizedBox(height: 8),
                              Text(states[user.uid]?.status ?? 'active'),
                              if ((states[user.uid]?.reason ?? '').isNotEmpty)
                                Text(states[user.uid]!.reason),
                              if (user.uid == ref.watch(currentUidProvider) ||
                                  user.uid == AppConfig.adminUid)
                                const Text('Protected administrator')
                              else
                                Wrap(
                                  spacing: 8,
                                  children: [
                                    if (states[user.uid]?.status != 'deleted')
                                      TextButton.icon(
                                        onPressed: _busy
                                            ? null
                                            : () => _moderate(
                                                user,
                                                states[user.uid]?.status ==
                                                        'suspended'
                                                    ? 'active'
                                                    : 'suspended',
                                              ),
                                        icon: Icon(
                                          states[user.uid]?.status ==
                                                  'suspended'
                                              ? Icons.lock_open
                                              : Icons.block,
                                        ),
                                        label: Text(
                                          states[user.uid]?.status ==
                                                  'suspended'
                                              ? 'Restore access'
                                              : 'Suspend',
                                        ),
                                      ),
                                    TextButton.icon(
                                      onPressed: _busy
                                          ? null
                                          : () => _moderate(user, 'deleted'),
                                      icon: const Icon(
                                        Icons.person_remove_outlined,
                                      ),
                                      label: Text(
                                        states[user.uid]?.status == 'deleted'
                                            ? 'Retry removal cleanup'
                                            : 'Remove user',
                                      ),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                      ),
                    if (filtered.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(24),
                        child: Text('No results'),
                      ),
                    TextButton(
                      onPressed: () =>
                          ref.read(adminUserLimitProvider.notifier).more(),
                      child: const Text('Load more users'),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class AdminControlsTab extends ConsumerStatefulWidget {
  const AdminControlsTab({super.key});
  @override
  ConsumerState<AdminControlsTab> createState() => _AdminControlsTabState();
}

class AdminActivityTab extends ConsumerStatefulWidget {
  const AdminActivityTab({super.key});
  @override
  ConsumerState<AdminActivityTab> createState() => _AdminActivityTabState();
}

class _AdminActivityTabState extends ConsumerState<AdminActivityTab> {
  bool _requests = false;
  String _query = '';
  @override
  Widget build(BuildContext context) {
    final records = _requests
        ? ref.watch(adminRequestsProvider)
        : ref.watch(adminOrdersProvider);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: false, label: Text('Orders')),
                  ButtonSegment(value: true, label: Text('Service requests')),
                ],
                selected: {_requests},
                onSelectionChanged: (value) =>
                    setState(() => _requests = value.first),
              ),
              const SizedBox(height: 12),
              TextField(
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  hintText: context.tr('Search loaded activity'),
                ),
                onChanged: (value) =>
                    setState(() => _query = value.toLowerCase().trim()),
              ),
            ],
          ),
        ),
        Expanded(
          child: records.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => ErrorRetry(
              error: error,
              onRetry: () {
                if (_requests) {
                  ref.invalidate(adminRequestsProvider);
                } else {
                  ref.invalidate(adminOrdersProvider);
                }
              },
            ),
            data: (items) => ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
              children: [
                const SoftBanner(
                  icon: Icons.receipt_long_outlined,
                  text: 'Inspect marketplace activity here. Order totals, delivery codes and transaction history cannot be overwritten from the dashboard.',
                ),
                for (final item in items.where(
                  (item) => item.toString().toLowerCase().contains(_query),
                ))
                  Card(
                    child: ExpansionTile(
                      title: Text('${item['_documentId']}'),
                      subtitle: Text('${item['status'] ?? ''}'),
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: SelectableText(
                            const JsonEncoder.withIndent(
                              '  ',
                              _recordValue,
                            ).convert(item),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  ),
                if (items.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('No activity yet'),
                  ),
                TextButton(
                  onPressed: () =>
                      ref.read(adminUserLimitProvider.notifier).more(),
                  child: const Text('Load more activity'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

Object? _recordValue(Object? value) =>
    value is Timestamp ? value.toDate().toIso8601String() : '$value';

class _AdminControlsTabState extends ConsumerState<AdminControlsTab> {
  final _message = TextEditingController();
  bool _busy = false;
  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  Future<void> _setMaintenance(bool enabled) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          enabled ? 'Pause new marketplace activity?' : 'Reopen marketplace?',
        ),
        content: const Text(
          'This controls new listings, purchases, photo uploads and service requests. Existing orders and requests can still be completed. Admin access is retained.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(adminRepositoryProvider)
          .setMaintenance(
            enabled: enabled,
            message: _message.text,
            actorUid: ref.read(currentUidProvider)!,
          );
      if (mounted) showMessage('Marketplace controls updated.');
    } catch (error) {
      if (mounted) showError(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final control = ref.watch(appControlProvider);
    final audit = ref.watch(adminAuditProvider);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Application controls',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 12),
        control.when(
          loading: () => const LinearProgressIndicator(),
          error: (error, _) => ErrorRetry(
            error: error,
            onRetry: () => ref.invalidate(appControlProvider),
          ),
          data: (value) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                value.maintenance
                    ? 'New activity is paused'
                    : 'Marketplace is open',
              ),
              if (value.message.isNotEmpty) Text(value.message),
              const SizedBox(height: 12),
              TextField(
                controller: _message,
                maxLength: 2000,
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: context.tr('Maintenance message (optional)'),
                ),
              ),
              FilledButton.icon(
                onPressed: _busy
                    ? null
                    : () => _setMaintenance(!value.maintenance),
                icon: Icon(value.maintenance ? Icons.play_arrow : Icons.pause),
                label: Text(
                  value.maintenance
                      ? 'Reopen marketplace'
                      : 'Pause new activity',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Recent admin activity',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const Text(
          'The latest 50 audit entries. Order and request history is protected from destructive edits.',
        ),
        audit.when(
          loading: () => const LinearProgressIndicator(),
          error: (error, _) => Text('$error'),
          data: (items) => Column(
            children: [
              for (final item in items)
                ListTile(
                  leading: const Icon(Icons.history),
                  title: Text('${item['action']}'),
                  subtitle: Text(
                    '${item['targetId'] ?? ''}\n${item['reason'] ?? ''}',
                  ),
                  isThreeLine: true,
                ),
            ],
          ),
        ),
      ],
    );
  }
}
