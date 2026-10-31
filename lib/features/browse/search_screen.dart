import 'package:souq_akimi/widgets/ui.dart';

import '../../core/l10n.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/motion.dart';
import '../../models/product.dart';
import '../../providers/catalogue.dart';
import '../../widgets/common.dart';
import '../../widgets/product_card.dart';
import 'browse_screen.dart';

/// Full-screen search with recent terms, typo correction and the ranked result
/// grid — the mobile face of the Django smart search.
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: ref.read(searchFiltersProvider).query,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    // Drop the query so the wide search window is not kept subscribed (and
    // billed) after the buyer leaves, and the next visit starts clean.
    ref.read(searchFiltersProvider.notifier).reset();
    super.dispose();
  }

  void _onChanged(String value) =>
      ref.read(searchFiltersProvider.notifier).setQuery(value);

  void _remember(String value) {
    if (value.trim().length >= 2) {
      ref.read(recentSearchesProvider.notifier).add(value);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filters = ref.watch(searchFiltersProvider);
    final results = ref.watch(searchResultsProvider);
    final corrected = ref.watch(searchSuggestionsProvider).corrected;
    final recent = ref.watch(recentSearchesProvider).value ?? const <String>[];
    // "Most viewed" only needs a handful of ideas, so borrow the 60-product
    // browse window rather than opening the 300-document search window before
    // the buyer has typed anything.
    final catalogue = ref.watch(productCatalogueProvider);

    final mostViewed = [...catalogue]
      ..sort((a, b) => b.viewsCount.compareTo(a.viewsCount));

    return Scaffold(
      appBar: AppBar(
        leading: const SouqBackButton(),
        title: TextField(
          controller: _controller,
          autofocus: true,
          textInputAction: TextInputAction.search,
          onChanged: _onChanged,
          onSubmitted: _remember,
          decoration: InputDecoration(
            hintText: context.tr('Search the campus…'),
            border: InputBorder.none,
            suffixIcon: filters.query.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _controller.clear();
                      _onChanged('');
                    },
                  ),
          ),
        ),
        actions: [
          IconButton(
            tooltip: context.tr('Sort'),
            icon: const Icon(Icons.swap_vert),
            onPressed: () async {
              final picked = await showSortSheet(context, filters.sort);
              if (picked != null) {
                ref.read(searchFiltersProvider.notifier).setSort(picked);
              }
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          if (filters.query.trim().isEmpty) ...[
            if (recent.isNotEmpty) ...[
              SectionHeader(
                title: 'Recent searches',
                trailing: TextButton(
                  onPressed: () =>
                      ref.read(recentSearchesProvider.notifier).clear(),
                  child: const Text('Clear'),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    for (final term in recent)
                      ActionChip(
                        avatar: const Icon(Icons.history, size: 16),
                        label: Text(term),
                        onPressed: () {
                          _controller.text = term;
                          _onChanged(term);
                        },
                      ),
                  ],
                ),
              ),
            ],
            const SectionHeader(title: 'Most viewed'),
            _ResultGrid(products: mostViewed.take(6).toList()),
          ] else ...[
            if (corrected.isNotEmpty)
              ListTile(
                leading: const Icon(Icons.spellcheck),
                title: Text(
                  context.tr(
                    'Did you mean "{term}"?',
                    args: {'term': corrected},
                  ),
                ),
                onTap: () {
                  _controller.text = corrected;
                  _onChanged(corrected);
                },
              ),
            const SectionHeader(title: 'Results'),
            if (results.isEmpty)
              const Padding(
                padding: EdgeInsets.all(32),
                child: EmptyState(
                  icon: Icons.search_off,
                  title: 'No matches',
                  message: 'Try fewer words, a brand name, or a price like "under 50".',
                ),
              )
            else
              _ResultGrid(products: results),
          ],
        ],
      ),
    );
  }
}

class _ResultGrid extends StatelessWidget {
  const _ResultGrid({required this.products});

  final List<Product> products;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final grid = catalogueGridMetrics(constraints.maxWidth - 32);
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: grid.columns,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            mainAxisExtent: grid.extent,
          ),
          itemCount: products.length,
          itemBuilder: (context, index) {
            final product = products[index];
            return FadeSlideIn(
              index: index,
              child: ProductCard(
                product: product,
                onTap: () => context.push('/product/${product.id}'),
              ),
            );
          },
        );
      },
    );
  }
}
