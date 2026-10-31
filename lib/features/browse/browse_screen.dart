import 'package:souq_akimi/widgets/ui.dart';

import '../../core/l10n.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_config.dart';
import '../../core/motion.dart';
import '../../data/search/search_engine.dart' show sortChoices;
import '../../models/enums.dart';
import '../../providers/catalogue.dart';
import '../../widgets/common.dart';
import '../../widgets/language_button.dart';
import '../../widgets/notification_alerts.dart';
import '../../widgets/product_card.dart';

/// The catalogue home: a search entry point, quick filters and a grid of every
/// active listing.
class BrowseScreen extends ConsumerWidget {
  const BrowseScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productsAsync = ref.watch(productsProvider);
    final filters = ref.watch(browseFiltersProvider);
    final results = ref.watch(filteredProductsProvider);

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(productsProvider);
          await ref.read(productsProvider.future);
        },
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: SafeArea(
                bottom: false,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: _BrandHeader(
                        onSearch: () => context.push('/search'),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: FadeSlideIn(
                        child: _BrowseHero(
                          onSearch: () => context.push('/search'),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _FilterBar(
                      sort: filters.sort,
                      condition: filters.condition,
                      onSort: (sort) => ref
                          .read(browseFiltersProvider.notifier)
                          .setSort(sort),
                      onCondition: (condition) => ref
                          .read(browseFiltersProvider.notifier)
                          .setCondition(condition),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: SectionHeader(
                        title: 'Latest on campus',
                        trailing: results.isEmpty
                            ? null
                            : Text(
                                context.tr(
                                  results.length == 1
                                      ? '{count} listing'
                                      : '{count} listings',
                                  args: {'count': '${results.length}'},
                                ),
                                style: Theme.of(context).textTheme.labelSmall
                                    ?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                    ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            productsAsync.when(
              loading: () => const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, _) => SliverFillRemaining(
                hasScrollBody: false,
                child: ErrorRetry(
                  error: error,
                  onRetry: () => ref.invalidate(productsProvider),
                ),
              ),
              data: (_) {
                if (results.isEmpty) {
                  return SliverFillRemaining(
                    hasScrollBody: false,
                    child: EmptyState(
                      icon: Icons.storefront_rounded,
                      title: 'Nothing to show yet',
                      message: 'Be the first to list something on campus.',
                      action: FilledButton.icon(
                        onPressed: () => context.go('/sell'),
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('List an item'),
                      ),
                    ),
                  );
                }
                return SliverLayoutBuilder(
                  builder: (context, constraints) {
                    final grid = catalogueGridMetrics(
                      constraints.crossAxisExtent - 32,
                    );
                    return SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 124),
                      sliver: SliverGrid.builder(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: grid.columns,
                          mainAxisSpacing: 14,
                          crossAxisSpacing: 14,
                          mainAxisExtent: grid.extent,
                        ),
                        itemCount: results.length,
                        itemBuilder: (context, index) {
                          final product = results[index];
                          return FadeSlideIn(
                            index: index,
                            child: ProductCard(
                              product: product,
                              onTap: () =>
                                  context.push('/product/${product.id}'),
                            ),
                          );
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _BrandHeader extends StatelessWidget {
  const _BrandHeader({required this.onSearch});

  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0B5D4B), Color(0xFF14897A)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(15),
            boxShadow: const [
              BoxShadow(
                color: Color(0x2E0B5D4B),
                blurRadius: 16,
                offset: Offset(0, 7),
              ),
            ],
          ),
          child: const Icon(
            Icons.storefront_rounded,
            color: Colors.white,
            size: 25,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            context.tr(AppConfig.appNameEnglish),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
        ),
        _HeaderAction(
          icon: Icons.search_rounded,
          tooltip: context.tr('Search'),
          onTap: onSearch,
        ),
        const InboxButton(),
        const LanguageButton(),
        const SizedBox(width: 2),
      ],
    );
  }
}

class _HeaderAction extends StatelessWidget {
  const _HeaderAction({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: scheme.outlineVariant),
        ),
        child: InkWell(
          onTap: onTap,
          customBorder: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          child: SizedBox(
            width: 44,
            height: 44,
            child: Icon(icon, size: 22, color: scheme.onSurface),
          ),
        ),
      ),
    );
  }
}

class _BrowseHero extends StatelessWidget {
  const _BrowseHero({required this.onSearch});

  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF093F34), Color(0xFF0E6A56), Color(0xFF14897A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [
          BoxShadow(
            color: Color(0x300B5D4B),
            blurRadius: 30,
            offset: Offset(0, 16),
          ),
        ],
      ),
      child: Stack(
        children: [
          PositionedDirectional(
            top: -54,
            end: -34,
            child: _Glow(size: 170, opacity: 0.10),
          ),
          PositionedDirectional(
            bottom: -70,
            start: -30,
            child: _Glow(size: 150, opacity: 0.07),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 22, 22, 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Find something great on campus',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    height: 1.15,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  'Buy and sell with students around you.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.76),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 18),
                _SearchEntry(onTap: onSearch, light: true),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Glow extends StatelessWidget {
  const _Glow({required this.size, required this.opacity});

  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: opacity),
      ),
    );
  }
}

class _SearchEntry extends StatelessWidget {
  const _SearchEntry({required this.onTap, this.light = false});

  final VoidCallback onTap;
  final bool light;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Material(
      color: light ? Colors.white : scheme.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(17),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(17),
        child: Container(
          height: 54,
          padding: const EdgeInsetsDirectional.fromSTEB(15, 0, 12, 0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(17),
            border: light
                ? null
                : Border.all(color: theme.colorScheme.outlineVariant),
          ),
          child: Row(
            children: [
              Icon(
                Icons.search_rounded,
                color: light ? scheme.primary : scheme.onSurfaceVariant,
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Text(
                  'Search laptops, textbooks, tutoring…',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: light
                      ? scheme.primary.withValues(alpha: 0.09)
                      : scheme.surfaceContainer,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(
                  Directionality.of(context) == TextDirection.rtl
                      ? Icons.arrow_back_rounded
                      : Icons.arrow_forward_rounded,
                  size: 18,
                  color: scheme.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.sort,
    required this.condition,
    required this.onSort,
    required this.onCondition,
  });

  final ProductSort sort;
  final Condition? condition;
  final ValueChanged<ProductSort> onSort;
  final ValueChanged<Condition?> onCondition;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 8),
            child: ActionChip(
              avatar: const Icon(Icons.swap_vert, size: 18),
              label: Text(sort.label),
              onPressed: () async {
                final picked = await showSortSheet(context, sort);
                if (picked != null) onSort(picked);
              },
            ),
          ),
          for (final value in Condition.values)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 8),
              child: FilterChip(
                label: Text(value.label),
                selected: condition == value,
                labelStyle: TextStyle(
                  color: condition == value
                      ? Theme.of(context).colorScheme.onPrimary
                      : Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.w700,
                ),
                onSelected: (selected) => onCondition(selected ? value : null),
              ),
            ),
        ],
      ),
    );
  }
}

/// Shared sort picker used by the browse and search screens.
Future<ProductSort?> showSortSheet(BuildContext context, ProductSort current) {
  return showModalBottomSheet<ProductSort>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                'Sort by',
                style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
          ),
          for (final option in sortChoices)
            ListTile(
              leading: Icon(
                option == current
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                color: option == current
                    ? Theme.of(context).colorScheme.primary
                    : null,
              ),
              title: Text(option.label),
              onTap: () => Navigator.of(context).pop(option),
            ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}
