import 'package:souq_akimi/widgets/ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_config.dart';
import '../../core/format.dart';
import '../../core/feedback.dart';
import '../../core/l10n.dart';
import '../../providers/admin.dart';
import '../../providers/auth.dart';
import '../../providers/catalogue.dart';
import '../../providers/dependencies.dart';
import '../../providers/notifications.dart';
import '../../providers/orders.dart';
import '../../widgets/common.dart';
import '../../widgets/language_button.dart';

/// The student's account: identity, the delivery details checkout remembers,
/// and the doorways to everything they own.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text(
          'You can sign back in with your email and password.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Stay'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(sessionProvider).signOut();
      if (context.mounted) context.go('/login');
    } catch (error) {
      if (context.mounted) showError(error);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(profileProvider);
    final uid = ref.watch(currentUidProvider);
    final signedIn = ref.watch(isSignedInProvider);
    final unread = ref.watch(unreadNotificationCountProvider);
    final listings = ref.watch(myProductsProvider).value?.length ?? 0;
    final services = ref.watch(myServicesProvider).value?.length ?? 0;
    final orders = ref.watch(myOrdersProvider).value?.length ?? 0;
    final sales = ref.watch(mySalesProvider).value?.length ?? 0;
    final theme = Theme.of(context);
    final isAdmin = ref.watch(isAdminProvider);

    if (!signedIn) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Profile'),
          leading: const SouqBackButton(),
        ),
        body: EmptyState(
          icon: Icons.person_outline,
          title: 'You are browsing as a guest',
          message: 'Sign in to buy, sell and keep your delivery details handy.',
          action: FilledButton(
            onPressed: () => context.push('/login'),
            child: const Text('Sign in'),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        leading: const SouqBackButton(),
        actions: const [LanguageButton(), SizedBox(width: 4)],
      ),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => ErrorRetry(
          error: error,
          onRetry: () => ref.invalidate(profileProvider),
        ),
        data: (profile) {
          // Riverpod keeps the previous value while the new account's stream
          // starts; show a spinner rather than the last student's profile.
          if (profile.uid != uid) {
            return const Center(child: CircularProgressIndicator());
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 124),
            children: [
              // ---- Identity ------------------------------------------------
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF093F34), Color(0xFF14897A)],
                    begin: AlignmentDirectional.topStart,
                    end: AlignmentDirectional.bottomEnd,
                  ),
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x260B5D4B),
                      blurRadius: 26,
                      offset: Offset(0, 12),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 32,
                      backgroundColor: Colors.white.withValues(alpha: 0.16),
                      child: Text(
                        profile.name.isEmpty
                            ? '?'
                            : profile.name[0].toUpperCase(),
                        style: theme.textTheme.headlineSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            profile.name,
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            '\u200E@${profile.username} (${profile.salesCount})',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.white.withValues(alpha: 0.8),
                            ),
                          ),
                          Text(
                            profile.email,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: Colors.white.withValues(alpha: 0.65),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ---- Stats ---------------------------------------------------
              Row(
                children: [
                  _Stat(label: 'Listings', value: listings),
                  _Stat(label: 'Services', value: services),
                  _Stat(label: 'Orders', value: orders),
                  _Stat(label: 'Sales', value: profile.salesCount),
                ],
              ),
              const SizedBox(height: 20),

              SectionHeader(title: 'Selling'),
              _LinkTile(
                icon: Icons.inventory_2_outlined,
                title: 'My listings',
                subtitle: context.tr(
                  listings == 1 ? '{count} listing' : '{count} listings',
                  args: {'count': '$listings'},
                ),
                onTap: () => context.push('/my-listings'),
              ),
              _LinkTile(
                icon: Icons.handyman_outlined,
                title: 'My services',
                subtitle: context.tr(
                  '{count} offered',
                  args: {'count': '$services'},
                ),
                onTap: () => context.push('/my-services'),
              ),
              _LinkTile(
                icon: Icons.inbox_outlined,
                title: 'Requests',
                subtitle: 'Briefs sent and received',
                onTap: () => context.push('/requests'),
              ),
              _LinkTile(
                icon: Icons.point_of_sale_outlined,
                title: 'My sales',
                subtitle: context.tr(
                  sales == 1 ? '{count} sale' : '{count} sales',
                  args: {'count': '$sales'},
                ),
                onTap: () => context.push('/sales'),
              ),
              const SizedBox(height: 12),

              SectionHeader(title: 'Buying'),
              _LinkTile(
                icon: Icons.receipt_long_outlined,
                title: 'My orders',
                subtitle: context.tr(
                  orders == 1 ? '{count} order' : '{count} orders',
                  args: {'count': '$orders'},
                ),
                onTap: () => context.push('/orders'),
              ),
              _LinkTile(
                icon: Icons.notifications_outlined,
                title: 'Notifications',
                subtitle: unread > 0
                    ? context.tr(
                        '{count} unread — new orders and updates',
                        args: {'count': '$unread'},
                      )
                    : context.tr('New orders land here'),
                trailing: unread > 0 ? Badge(label: Text('$unread')) : null,
                onTap: () => context.push('/notifications'),
              ),
              const SizedBox(height: 12),

              SectionHeader(title: 'Account'),
              const LanguageTile(),
              _LinkTile(
                icon: Icons.help_outline,
                title: 'Help, privacy and account removal',
                subtitle: 'Support, reporting and download information',
                onTap: () => showDialog<void>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Souq Akimi'),
                    content: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Version 1.0.0 · Cash on delivery only. Never share your delivery code before receiving your item.',
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'For help, abusive listings, unsafe users, or account/data removal, contact the administrator. Include the listing ID or your account email. Never send your password or delivery code.',
                          ),
                          const SizedBox(height: 8),
                          const SelectableText('abdullashahzan@gmail.com'),
                          const SizedBox(height: 12),
                          const Text('Privacy policy'),
                          const SelectableText(
                            'https://github.com/abdullashahzan/souq_akimi/blob/main/docs/privacy.md',
                          ),
                          const SizedBox(height: 12),
                          const Text('Official downloads and updates'),
                          const SelectableText(
                            'https://github.com/abdullashahzan/souq_akimi/releases',
                          ),
                        ],
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Close'),
                      ),
                    ],
                  ),
                ),
              ),
              _LinkTile(
                icon: Icons.local_shipping_outlined,
                title: 'Delivery details',
                subtitle: profile.hasCompleteDeliveryDetails
                    ? '${Format.building(profile.building)} ${profile.roomNumber} · ${profile.phone}'
                    : 'Add a phone, building and room so checkout is prefilled',
                onTap: () => showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  showDragHandle: true,
                  builder: (_) => const Padding(
                    padding: EdgeInsets.all(8),
                    child: _DeliveryDetailsForm(),
                  ),
                ),
              ),
              if (isAdmin) ...[
                const SizedBox(height: 12),
                _LinkTile(
                  icon: Icons.admin_panel_settings_outlined,
                  title: 'Admin dashboard',
                  subtitle: 'Moderate listings and reach every student',
                  onTap: () => context.push('/admin'),
                ),
              ],
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => _signOut(context, ref),
                icon: const Icon(Icons.logout),
                label: const Text('Sign out'),
              ),
              const SizedBox(height: 24),
            ],
          );
        },
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: theme.colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          children: [
            Text(
              '$value',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                color: theme.colorScheme.primary,
              ),
            ),
            Text(label, style: theme.textTheme.labelSmall),
          ],
        ),
      ),
    );
  }
}

class _LinkTile extends StatelessWidget {
  const _LinkTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary
                .withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(
            icon,
            size: 21,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: trailing ?? const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

/// The buyer's remembered details — prefilling checkout after one save.
class _DeliveryDetailsForm extends ConsumerStatefulWidget {
  const _DeliveryDetailsForm();

  @override
  ConsumerState<_DeliveryDetailsForm> createState() =>
      _DeliveryDetailsFormState();
}

class _DeliveryDetailsFormState extends ConsumerState<_DeliveryDetailsForm> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _room = TextEditingController();
  String? _building;
  bool _loaded = false;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _room.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(profileOrEmptyProvider);
    if (!_loaded && profile.uid.isNotEmpty) {
      _loaded = true;
      _name.text = profile.displayName;
      _phone.text = profile.phone;
      _room.text = profile.roomNumber;
      _building = profile.building.isEmpty
          ? null
          : AppConfig.buildingFor(profile.building).code;
    }

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Delivery details',
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              'Saved once and used to prefill every checkout.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(labelText: context.tr('Full name')),
              validator: (v) => (v ?? '').trim().length >= 2
                  ? null
                  : context.tr('Enter your name'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(labelText: context.tr('Phone')),
              validator: (v) => (v ?? '').trim().length >= 6
                  ? null
                  : context.tr('Enter a phone number'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _building,
              decoration: InputDecoration(labelText: context.tr('Building')),
              hint: Text(context.tr('Choose your hostel block')),
              items: [
                for (final building in AppConfig.hostelBuildings)
                  DropdownMenuItem(
                    value: building.code,
                    child: Text(
                      context.isArabic
                          ? building.arabicLabel
                          : building.englishLabel,
                    ),
                  ),
              ],
              validator: (v) =>
                  (v ?? '').isEmpty ? context.tr('Choose your building') : null,
              onChanged: (value) => setState(() => _building = value),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _room,
              decoration: InputDecoration(labelText: context.tr('Room number')),
              validator: (v) => (v ?? '').trim().isEmpty
                  ? context.tr('Enter your room number')
                  : null,
            ),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: _busy ? null : _save,
              child: Text(_busy ? 'Saving…' : 'Save'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _busy = true);
    try {
      final profile = ref.read(profileOrEmptyProvider);
      await ref
          .read(userRepositoryProvider)
          .saveDeliveryDetails(
            uid: profile.uid,
            displayName: _name.text,
            phone: _phone.text,
            building: _building ?? '',
            roomNumber: _room.text,
          );
      if (!mounted) return;
      // Pop the sheet, then report through the app-level messenger — a bar
      // raised through the sheet's own context dies with the sheet.
      Navigator.of(context).pop();
      showMessage('Delivery details saved.');
    } catch (error) {
      if (!mounted) return;
      setState(() => _busy = false);
      showError(error);
    }
  }
}
