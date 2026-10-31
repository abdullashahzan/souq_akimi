import 'package:souq_akimi/widgets/ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/motion.dart';
import '../../models/product.dart';
import '../../providers/auth.dart';
import '../../providers/catalogue.dart';
import '../../providers/dependencies.dart';
import '../../core/l10n.dart';
import '../../providers/orders.dart';
import '../../providers/sellers.dart';
import '../../widgets/common.dart';
import '../../widgets/listing_image.dart';
import '../../widgets/product_card.dart';
import '../auth/require_auth.dart';

/// A single listing: swipeable gallery, condition, stock, seller and the
/// one-tap "Buy now" that starts a checkout (Souq has no cart).
class ProductDetailScreen extends ConsumerStatefulWidget {
  const ProductDetailScreen({super.key, required this.productId});

  final String productId;

  @override
  ConsumerState<ProductDetailScreen> createState() =>
      _ProductDetailScreenState();
}

class _ProductDetailScreenState extends ConsumerState<ProductDetailScreen> {
  final _pageController = PageController();
  int _page = 0;
  bool _countedView = false;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final productAsync = ref.watch(productByIdProvider(widget.productId));

    return productAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, _) => Scaffold(
        appBar: AppBar(leading: const SouqBackButton()),
        body: ErrorRetry(
          error: error,
          onRetry: () => ref.invalidate(productByIdProvider(widget.productId)),
        ),
      ),
      data: (product) {
        if (product == null) {
          return Scaffold(
            appBar: AppBar(leading: const SouqBackButton()),
            body: const EmptyState(
              icon: Icons.search_off,
              title: 'Listing not found',
              message: 'It may have been removed by the seller.',
            ),
          );
        }
        if (!_countedView) {
          _countedView = true;
          ref.read(productRepositoryProvider).recordView(product.id);
        }

        final photos = product.images.isNotEmpty
            ? product.images
            : <String>[''];
        final related = ref.watch(relatedProductsProvider(product.id));
        final isOwner = product.isOwnedBy(ref.watch(currentUidProvider) ?? '');
        final seller = ref.watch(sellerProfileProvider(product.sellerId)).value;
        final sellerName = seller?.username.trim().isNotEmpty == true
            ? seller!.username
            : product.sellerUsername;

        return Scaffold(
          appBar: AppBar(
            title: Text(
              product.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            actions: [
              if (isOwner)
                IconButton(
                  tooltip: context.tr('Edit listing'),
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () => context.push('/product/${product.id}/edit'),
                ),
              const SizedBox(width: 4),
            ],
          ),
          bottomNavigationBar: _BuyBar(product: product, isOwner: isOwner),
          body: ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              LayoutBuilder(
                builder: (context, constraints) => SizedBox(
                  height: (constraints.maxWidth * 0.75).clamp(200.0, 360.0),
                  child: Stack(
                    children: [
                      // Flies in from the card's cover (see [productHeroTag]).
                      Hero(
                        tag: productHeroTag(product.id),
                        child: PageView.builder(
                          controller: _pageController,
                          itemCount: photos.length,
                          onPageChanged: (index) =>
                              setState(() => _page = index),
                          itemBuilder: (context, index) => ListingImage(
                            url: photos[index],
                            label: product.name,
                            // Page 0 uses the same tint seed as the card cover so
                            // a photo-less listing does not flicker colour mid
                            // flight.
                            seed: index == 0
                                ? product.id
                                : '${product.id}-$index',
                          ),
                        ),
                      ),
                      if (photos.length > 1)
                        PositionedDirectional(
                          bottom: 10,
                          start: 0,
                          end: 0,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              for (var i = 0; i < photos.length; i++)
                                Container(
                                  width: 8,
                                  height: 8,
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: i == _page
                                        ? Colors.white
                                        : Colors.white.withValues(alpha: 0.4),
                                  ),
                                ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            Format.money(product.price),
                            style: Theme.of(context).textTheme.headlineMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                          ),
                        ),
                        StatusChip.condition(product.condition),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      product.name,
                      style: Theme.of(context).textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          product.isInStock
                              ? Icons.check_circle_outline
                              : Icons.remove_shopping_cart_outlined,
                          size: 18,
                          color: product.isInStock
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.error,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          product.isInStock
                              ? Format.stock(product.stock)
                              : 'Sold out',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(width: 12),
                        Icon(
                          Icons.remove_red_eye_outlined,
                          size: 18,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          context.tr(
                            '{count} views',
                            args: {'count': '${product.viewsCount}'},
                          ),
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (sellerName.isNotEmpty)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          child: Text(sellerName[0].toUpperCase()),
                        ),
                        title: Text(
                          sellerHandle(sellerName, seller?.salesCount),
                        ),
                        subtitle: const Text('Seller on campus'),
                        trailing: Icon(
                          Icons.verified_outlined,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    const Divider(),
                    Text(
                      'Description',
                      style: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      product.description,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        height: 1.5,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (product.tags.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          for (final tag in product.tags)
                            Chip(
                              label: Text(tag),
                              visualDensity: VisualDensity.compact,
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              if (related.isNotEmpty) ...[
                const SectionHeader(title: 'More like this'),
                SizedBox(
                  height: 340,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: related.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 12),
                    itemBuilder: (context, index) {
                      final item = related[index];
                      return FadeSlideIn(
                        index: index,
                        child: SizedBox(
                          width: 170,
                          child: ProductCard(
                            product: item,
                            showSeller: false,
                            onTap: () => context.push('/product/${item.id}'),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _BuyBar extends ConsumerWidget {
  const _BuyBar({required this.product, required this.isOwner});

  final Product product;
  final bool isOwner;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Row(
          children: [
            Expanded(
              child: Text(
                Format.money(product.price),
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: scheme.primary,
                ),
              ),
            ),
            if (isOwner)
              Expanded(
                child: FilledButton(
                  onPressed: () => context.push('/product/${product.id}/edit'),
                  child: const Text('Edit'),
                ),
              )
            else
              Expanded(
                child: FilledButton(
                  onPressed: !product.isInStock
                      ? null
                      : () {
                          if (!requireSignIn(
                            context,
                            ref,
                            message: 'Sign in to buy this item.',
                          )) {
                            return;
                          }
                          ref
                              .read(pendingPurchaseProvider.notifier)
                              .start(product);
                          context.push('/checkout');
                        },
                  child: Text(product.isInStock ? 'Buy now' : 'Sold out'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Quantity selector shown in the checkout sheet when stock is plentiful.
class BuyQuantitySheet extends ConsumerWidget {
  const BuyQuantitySheet({super.key, required this.maxQuantity});

  final int maxQuantity;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = ref.watch(pendingPurchaseProvider);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'How many?',
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 20),
            QuantityStepper(
              quantity: draft.quantity,
              max: maxQuantity,
              onChanged: (q) =>
                  ref.read(pendingPurchaseProvider.notifier).setQuantity(q),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () {
                context.pop();
                context.push('/checkout');
              },
              child: Text(
                context.tr(
                  'Buy {count} for {total}',
                  args: {
                    'count': '${draft.quantity}',
                    'total': Format.money(draft.lineTotal),
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
