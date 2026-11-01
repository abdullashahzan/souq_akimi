import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:souq_akimi/widgets/ui.dart';

import '../../core/feedback.dart';
import '../../core/format.dart';
import '../../core/l10n.dart';
import '../../core/motion.dart';
import '../../models/product.dart';
import '../../models/service.dart';
import '../../providers/admin.dart';
import '../../providers/auth.dart';
import '../../providers/dependencies.dart';
import '../../widgets/ai_button.dart';
import '../../widgets/common.dart';
import '../../widgets/language_button.dart';
import '../../widgets/listing_image.dart';
import '../../widgets/listing_gallery.dart';
import '../../providers/app_control.dart';
import 'admin_management.dart';

/// The marketplace owner's control room: live counts, every listing, and a
/// one-tap announcement to every inbox.
class AdminScreen extends ConsumerWidget {
  const AdminScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final email = ref.watch(authStateProvider).value?.email?.toLowerCase();
    final isAdmin = ref.watch(isAdminProvider);

    if (email == null) {
      return const Scaffold(
        body: EmptyState(
          icon: Icons.lock_outline,
          title: 'Admins only',
          message: 'Sign in with the administrator account to continue.',
        ),
      );
    }
    if (!isAdmin) {
      return const Scaffold(
        body: EmptyState(
          icon: Icons.gpp_bad_outlined,
          title: 'Admins only',
          message: 'This area is for the marketplace admin.',
        ),
      );
    }

    return DefaultTabController(
      length: 6,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Admin dashboard'),
          actions: [
            IconButton(
              tooltip: context.tr('Refresh'),
              icon: const Icon(Icons.refresh),
              onPressed: () {
                ref.invalidate(adminStatsProvider);
                ref.invalidate(adminProductsProvider);
                ref.invalidate(adminServicesProvider);
                ref.invalidate(adminUsersProvider);
                ref.invalidate(adminAccessProvider);
              },
            ),
            const LanguageButton(),
            const SizedBox(width: 4),
          ],
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(child: Text('Overview')),
              Tab(child: Text('Content')),
              Tab(child: Text('Broadcast')),
              Tab(child: Text('Users')),
              Tab(child: Text('Controls')),
              Tab(child: Text('Activity')),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _OverviewTab(),
            _ContentTab(),
            _BroadcastTab(),
            AdminUsersTab(),
            AdminControlsTab(),
            AdminActivityTab(),
          ],
        ),
      ),
    );
  }
}

class _OverviewTab extends ConsumerWidget {
  const _OverviewTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(adminStatsProvider);
    final theme = Theme.of(context);
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(adminStatsProvider);
        await ref.read(adminStatsProvider.future);
      },
      child: stats.when(
        loading: () => ListView(
          padding: const EdgeInsets.all(16),
          children: const [
            _SkeletonStats(),
            SizedBox(height: 20),
            LinearProgressIndicator(),
          ],
        ),
        error: (error, _) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            SizedBox(
              height: 320,
              child: ErrorRetry(
                error: error,
                onRetry: () => ref.invalidate(adminStatsProvider),
              ),
            ),
          ],
        ),
        data: (data) {
          final cards = <Widget>[
            _StatCard(
              icon: Icons.people_outline,
              label: 'Users',
              value: '${data.users}',
              color: const Color(0xFF0F6B5C),
            ),
            _StatCard(
              icon: Icons.inventory_2_outlined,
              label: 'Products',
              value: '${data.products}',
              hint: context.tr(
                '{count} live',
                args: {'count': '${data.activeProducts}'},
              ),
              color: const Color(0xFF2563EB),
            ),
            _StatCard(
              icon: Icons.handyman_outlined,
              label: 'Services',
              value: '${data.services}',
              hint: context.tr(
                '{count} live',
                args: {'count': '${data.activeServices}'},
              ),
              color: const Color(0xFF9A5B13),
            ),
            _StatCard(
              icon: Icons.receipt_long_outlined,
              label: 'Orders',
              value: '${data.orders}',
              color: const Color(0xFF7C3AED),
            ),
            _StatCard(
              icon: Icons.pending_actions_outlined,
              label: 'Pending requests',
              value: '${data.pendingRequests}',
              color: const Color(0xFFB7791F),
            ),
            _StatCard(
              icon: Icons.campaign_outlined,
              label: 'Reach',
              value: '${data.users}',
              hint: 'registered students',
              color: const Color(0xFFDB2777),
            ),
          ];

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 96),
            children: [
              FadeSlideIn(
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0F6B5C), Color(0xFF14897A)],
                      begin: AlignmentDirectional.topStart,
                      end: AlignmentDirectional.bottomEnd,
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.admin_panel_settings_outlined,
                        color: Colors.white,
                        size: 38,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'You are in control',
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Moderate the catalogue and reach every student from one place.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: Colors.white.withValues(alpha: 0.85),
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              LayoutBuilder(
                builder: (context, constraints) {
                  final width = (constraints.maxWidth - 12) / 2;
                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      for (var i = 0; i < cards.length; i++)
                        SizedBox(
                          width: width,
                          child: FadeSlideIn(index: i, child: cards[i]),
                        ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 22),
              const SoftBanner(
                icon: Icons.bolt_outlined,
                text: 'Deleting a listing also removes its stored photos. Order history is kept for both sides.',
              ),
            ],
          );
        },
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.hint,
  });

  final IconData icon;
  final String label;
  final String value;
  final String? hint;
  final Color color;

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
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 21),
            ),
            const SizedBox(height: 10),
            Text(
              value,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(label, style: theme.textTheme.labelMedium),
            if (hint != null)
              Text(
                hint!,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SkeletonStats extends StatelessWidget {
  const _SkeletonStats();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = (constraints.maxWidth - 12) / 2;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (var i = 0; i < 6; i++)
              Container(
                width: width,
                height: 118,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _ContentTab extends ConsumerStatefulWidget {
  const _ContentTab();

  @override
  ConsumerState<_ContentTab> createState() => _ContentTabState();
}

class _ContentTabState extends ConsumerState<_ContentTab> {
  final _search = TextEditingController();
  bool _services = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final products = ref.watch(adminProductsProvider);
    final services = ref.watch(adminServicesProvider);
    final query = _search.text.trim().toLowerCase();
    final theme = Theme.of(context);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
          child: Column(
            children: [
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(
                    value: false,
                    label: Text('Products'),
                    icon: Icon(Icons.inventory_2_outlined),
                  ),
                  ButtonSegment(
                    value: true,
                    label: Text('Services'),
                    icon: Icon(Icons.handyman_outlined),
                  ),
                ],
                selected: {_services},
                onSelectionChanged: (value) =>
                    setState(() => _services = value.first),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _search,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: context.tr('Search users or listings…'),
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: query.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () {
                            _search.clear();
                            setState(() {});
                          },
                        ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _services
              ? services.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (error, _) => ErrorRetry(
                    error: error,
                    onRetry: () => ref.invalidate(adminServicesProvider),
                  ),
                  data: (items) {
                    final filtered = items
                        .where(
                          (s) =>
                              query.isEmpty ||
                              s.title.toLowerCase().contains(query) ||
                              s.providerUsername.toLowerCase().contains(query),
                        )
                        .toList();
                    if (filtered.isEmpty) {
                      return const EmptyState(
                        icon: Icons.handyman_outlined,
                        title: 'No results',
                        message: 'No services match that search.',
                      );
                    }
                    return ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                      itemCount: filtered.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) => FadeSlideIn(
                        index: index,
                        child: _ServiceRow(
                          service: filtered[index],
                          onEdit: () => _edit(service: filtered[index]),
                          onToggle: () => _toggle(service: filtered[index]),
                          onRemove: () => _removeService(filtered[index]),
                        ),
                      ),
                    );
                  },
                )
              : products.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (error, _) => ErrorRetry(
                    error: error,
                    onRetry: () => ref.invalidate(adminProductsProvider),
                  ),
                  data: (items) {
                    final filtered = items
                        .where(
                          (p) =>
                              query.isEmpty ||
                              p.name.toLowerCase().contains(query) ||
                              p.sellerUsername.toLowerCase().contains(query),
                        )
                        .toList();
                    if (filtered.isEmpty) {
                      return const EmptyState(
                        icon: Icons.inventory_2_outlined,
                        title: 'No results',
                        message: 'No products match that search.',
                      );
                    }
                    return ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                      itemCount: filtered.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) => FadeSlideIn(
                        index: index,
                        child: _ProductRow(
                          product: filtered[index],
                          onEdit: () => _edit(product: filtered[index]),
                          onToggle: () => _toggle(product: filtered[index]),
                          onRemove: () => _removeProduct(filtered[index]),
                        ),
                      ),
                    );
                  },
                ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 2, 16, 8),
          child: Text(
            _services
                ? 'Services are removable here. Providers keep their order history.'
                : 'Products are removable here. Stored photos are cleaned up too.',
            textAlign: TextAlign.center,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        TextButton(
          onPressed: () => ref.read(adminUserLimitProvider.notifier).more(),
          child: const Text('Load more listings'),
        ),
      ],
    );
  }

  Future<void> _removeProduct(Product product) async {
    final ok = await _confirm(
      title: 'Remove this listing?',
      body: product.name,
    );
    if (!ok) return;
    try {
      await ref
          .read(adminRepositoryProvider)
          .removeProduct(product, actorUid: ref.read(currentUidProvider)!);
      ref.invalidate(adminStatsProvider);
      if (mounted) showMessage('Listing removed.');
    } catch (error) {
      if (mounted) showError(error);
    }
  }

  Future<void> _edit({Product? product, Service? service}) async {
    final title = TextEditingController(text: product?.name ?? service!.title);
    final description = TextEditingController(
      text: product?.description ?? service!.description,
    );
    final price = TextEditingController(
      text: '${product?.price ?? service!.price}',
    );
    final stock = TextEditingController(text: '${product?.stock ?? 0}');
    final form = GlobalKey<FormState>();
    final ok = await showAdminFormDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit listing'),
        content: SingleChildScrollView(
          child: SizedBox(
            width: 480,
            child: Form(
              key: form,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: title,
                    maxLength: 120,
                    decoration: InputDecoration(labelText: context.tr('Title')),
                    validator: (value) => (value ?? '').trim().isEmpty
                        ? context.tr('Required')
                        : null,
                  ),
                  TextFormField(
                    controller: description,
                    minLines: 3,
                    maxLines: 6,
                    maxLength: 4000,
                    decoration: InputDecoration(
                      labelText: context.tr('Description'),
                    ),
                    validator: (value) => (value ?? '').trim().isEmpty
                        ? context.tr('Required')
                        : null,
                  ),
                  TextFormField(
                    controller: price,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: context.tr('Price (SAR)'),
                    ),
                    validator: (value) {
                      final number = double.tryParse(value ?? '');
                      return number != null &&
                              number.isFinite &&
                              number > 0 &&
                              number <= 1000000
                          ? null
                          : context.tr('Enter a valid price');
                    },
                  ),
                  if (product != null)
                    TextFormField(
                      controller: stock,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: context.tr('Stock'),
                      ),
                      validator: (value) {
                        final number = int.tryParse(value ?? '');
                        return number != null && number >= 0 && number <= 999
                            ? null
                            : context.tr('Use a stock from 0 to 999');
                      },
                    ),
                ],
              ),
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
            child: const Text('Save'),
          ),
        ],
      ),
    );
    final values = (
      title.text,
      description.text,
      double.tryParse(price.text) ?? 0,
      int.tryParse(stock.text) ?? 0,
    );
    title.dispose();
    description.dispose();
    price.dispose();
    stock.dispose();
    if (ok != true || !mounted) return;
    try {
      await ref
          .read(adminRepositoryProvider)
          .editContent(
            id: product?.id ?? service!.id,
            service: service != null,
            title: values.$1,
            description: values.$2,
            price: values.$3,
            stock: values.$4,
            actorUid: ref.read(currentUidProvider)!,
          );
      if (mounted) showMessage('Listing updated.');
    } catch (error) {
      if (mounted) showError(error);
    }
  }

  Future<void> _toggle({Product? product, Service? service}) async {
    try {
      final repo = ref.read(adminRepositoryProvider);
      if (product != null) {
        await repo.setProductActive(
          product.id,
          !product.isActive,
          actorUid: ref.read(currentUidProvider)!,
        );
      }
      if (service != null) {
        await repo.setServiceActive(
          service.id,
          !service.isActive,
          actorUid: ref.read(currentUidProvider)!,
        );
      }
      ref.invalidate(adminStatsProvider);
      if (mounted) showMessage('Listing updated.');
    } catch (error) {
      if (mounted) showError(error);
    }
  }

  Future<void> _removeService(Service service) async {
    final ok = await _confirm(
      title: 'Remove this service?',
      body: service.title,
    );
    if (!ok) return;
    try {
      await ref
          .read(adminRepositoryProvider)
          .removeService(service, actorUid: ref.read(currentUidProvider)!);
      ref.invalidate(adminStatsProvider);
      if (mounted) showMessage('Service removed.');
    } catch (error) {
      if (mounted) showError(error);
    }
  }

  Future<bool> _confirm({required String title, required String body}) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text('$body\n\n${context.tr('This cannot be undone.')}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}

class _ProductRow extends StatelessWidget {
  const _ProductRow({
    required this.product,
    required this.onRemove,
    required this.onToggle,
    required this.onEdit,
  });

  final Product product;
  final VoidCallback onRemove;
  final VoidCallback onToggle;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: () => context.push('/product/${product.id}'),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 58,
                  height: 58,
                  child: PhotoPreview(
                    images: product.images,
                    label: product.name,
                    child: ListingImage(
                      url: product.coverImage,
                      label: product.name,
                      seed: product.id,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      '\u200E@${product.sellerUsername} · ${Format.money(product.price)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        StatusChip(
                          label: product.isActive ? 'Live' : 'Paused',
                          color: product.isActive
                              ? theme.colorScheme.primary
                              : theme.colorScheme.outline,
                          dense: true,
                        ),
                        Text(
                          context.tr(
                            '{count} stock',
                            args: {'count': '${product.stock}'},
                          ),
                          style: theme.textTheme.labelSmall,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: context.tr('Edit listing'),
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined),
              ),
              IconButton(
                tooltip: context.tr(
                  product.isActive ? 'Pause listing' : 'Resume listing',
                ),
                onPressed: onToggle,
                icon: Icon(
                  product.isActive
                      ? Icons.pause_circle_outline
                      : Icons.play_circle_outline,
                ),
              ),
              IconButton(
                tooltip: context.tr('Remove'),
                onPressed: onRemove,
                icon: Icon(
                  Icons.delete_outline,
                  color: theme.colorScheme.error,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ServiceRow extends StatelessWidget {
  const _ServiceRow({
    required this.service,
    required this.onRemove,
    required this.onToggle,
    required this.onEdit,
  });

  final Service service;
  final VoidCallback onRemove;
  final VoidCallback onToggle;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: () => context.push('/service/${service.id}'),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 58,
                  height: 58,
                  child: PhotoPreview(
                    images: service.images,
                    label: service.title,
                    child: ListingImage(
                      url: service.coverImage,
                      label: service.title,
                      seed: service.id,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      service.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      '\u200E@${service.providerUsername} · ${Format.priceWithUnit(service.price, service.priceType.suffix)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 3),
                    StatusChip(
                      label: service.isActive ? 'Live' : 'Paused',
                      color: service.isActive
                          ? theme.colorScheme.primary
                          : theme.colorScheme.outline,
                      dense: true,
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: context.tr('Edit listing'),
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined),
              ),
              IconButton(
                tooltip: context.tr(
                  service.isActive ? 'Pause listing' : 'Resume listing',
                ),
                onPressed: onToggle,
                icon: Icon(
                  service.isActive
                      ? Icons.pause_circle_outline
                      : Icons.play_circle_outline,
                ),
              ),
              IconButton(
                tooltip: context.tr('Remove'),
                onPressed: onRemove,
                icon: Icon(
                  Icons.delete_outline,
                  color: theme.colorScheme.error,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BroadcastTab extends ConsumerStatefulWidget {
  const _BroadcastTab();

  @override
  ConsumerState<_BroadcastTab> createState() => _BroadcastTabState();
}

class _BroadcastTabState extends ConsumerState<_BroadcastTab> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _body = TextEditingController();
  bool _aiBusy = false;
  bool _sending = false;
  bool _everyLaunch = true;

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _draft() async {
    final topic = _title.text.trim().isNotEmpty
        ? _title.text.trim()
        : _body.text.trim();
    if (topic.length < 3) {
      showMessage('Add a title first so AI has something to work with.');
      return;
    }
    setState(() => _aiBusy = true);
    try {
      final result = await ref
          .read(aiAssistantProvider)
          .announcement(topic: topic);
      if (!mounted) return;
      _title.text = result.title;
      _body.text = result.body;
    } catch (error) {
      if (mounted) showError(error);
    } finally {
      if (mounted) setState(() => _aiBusy = false);
    }
  }

  Future<void> _send() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Publish launch message?'),
        content: const Text(
          'This replaces the current launch message for everyone, including guests and future users. The full message appears before they use the app.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Publish'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final uid = ref.read(currentUidProvider);
    if (uid == null) return;
    setState(() => _sending = true);
    try {
      await ref
          .read(adminRepositoryProvider)
          .publishMessage(
            adminUid: uid,
            title: _title.text,
            body: _body.text,
            everyLaunch: _everyLaunch,
          );
      if (!mounted) return;
      _title.clear();
      _body.clear();
      showMessage('Launch message published.');
    } catch (error) {
      if (mounted) showError(error);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final current = ref.watch(launchMessageProvider);
    final working = _aiBusy || _sending;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 96),
      children: [
        Text(
          'Broadcast',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Communicate bugs, fixes and updates before users enter the app. No inbox visit is needed.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        current.when(
          loading: () => const LinearProgressIndicator(),
          error: (error, _) => ErrorRetry(
            error: error,
            onRetry: () => ref.invalidate(launchMessageProvider),
          ),
          data: (message) => message.visible
              ? Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Current launch message'),
                        Text(message.title, style: theme.textTheme.titleMedium),
                        Text(message.body),
                        Text(
                          message.everyLaunch
                              ? 'Shown on every app open'
                              : 'Shown once per user on this device',
                        ),
                        Wrap(
                          spacing: 8,
                          children: [
                            TextButton(
                              onPressed: working
                                  ? null
                                  : () {
                                      _title.text = message.title;
                                      _body.text = message.body;
                                      setState(
                                        () =>
                                            _everyLaunch = message.everyLaunch,
                                      );
                                    },
                              child: const Text('Edit'),
                            ),
                            TextButton(
                              onPressed: working ? null : _withdraw,
                              child: const Text('Withdraw message'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                )
              : const Text('No active launch message'),
        ),
        const SizedBox(height: 16),
        Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _title,
                maxLength: 120,
                onChanged: (_) => setState(() {}),
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: context.tr('Message title'),
                  hintText: context.tr('A small campus update'),
                ),
                validator: (value) => (value ?? '').trim().length >= 3
                    ? null
                    : context.tr('Use at least 3 characters'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _body,
                maxLength: 4000,
                onChanged: (_) => setState(() {}),
                minLines: 4,
                maxLines: 8,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: context.tr('Message'),
                  hintText: context.tr('Write an announcement…'),
                  alignLabelWithHint: true,
                ),
                validator: (value) => (value ?? '').trim().length >= 5
                    ? null
                    : context.tr('Tell buyers a little more'),
              ),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: AiAssistButton(
                  label: 'Draft with AI',
                  loading: _aiBusy,
                  onPressed: _sending ? null : _draft,
                ),
              ),
              const SizedBox(height: 8),
              SwitchListTile.adaptive(
                value: _everyLaunch,
                onChanged: working
                    ? null
                    : (value) => setState(() => _everyLaunch = value),
                title: const Text('Show on every app open'),
                subtitle: const Text(
                  'Turn off to show once per user on each device. Publishing again creates a new acknowledgement.',
                ),
              ),
              Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withValues(
                            alpha: 0.12,
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.campaign_outlined,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _title.text.trim().isEmpty
                                  ? context.tr('Notification title')
                                  : _title.text.trim(),
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _body.text.trim().isEmpty
                                  ? context.tr(
                                      'Your message preview appears here.',
                                    )
                                  : _body.text.trim(),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: working ? null : _send,
                icon: _sending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send_outlined),
                label: const Text('Publish launch message'),
              ),
              const SizedBox(height: 6),
              Text(
                'Visible to guests, existing users and new users until withdrawn. Receiving a new message requires a connection; cached messages remain available offline.',
                textAlign: TextAlign.center,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _withdraw() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Withdraw launch message?'),
        content: const Text(
          'It will stop appearing after devices receive the update.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Withdraw message'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _sending = true);
    try {
      await ref
          .read(adminRepositoryProvider)
          .withdrawMessage(ref.read(currentUidProvider)!);
      if (mounted) showMessage('Launch message withdrawn.');
    } catch (error) {
      if (mounted) showError(error);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }
}
