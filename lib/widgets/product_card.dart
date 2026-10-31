import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:souq_akimi/widgets/ui.dart';

import '../core/format.dart';
import '../core/motion.dart';
import '../models/product.dart';
import '../providers/sellers.dart';
import 'common.dart';
import 'listing_image.dart';

/// A catalogue tile. Used in the browse grid, search results and "my listings".
class ProductCard extends ConsumerWidget {
  const ProductCard({
    super.key,
    required this.product,
    this.onTap,
    this.trailing,
    this.showSeller = true,
  });

  final Product product;
  final VoidCallback? onTap;

  /// Optional corner action (e.g. an owner menu).
  final Widget? trailing;
  final bool showSeller;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final sales = ref.watch(visibleSellerSalesProvider)[product.sellerId];
    final paused = !product.isActive;
    final soldOut = !paused && !product.isInStock;

    final scheme = theme.colorScheme;
    return PressableScale(
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0D0B1F18),
              blurRadius: 24,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: Card(
          margin: EdgeInsets.zero,
          child: InkWell(
            onTap: onTap,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AspectRatio(
                  aspectRatio: 1,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Shared with the detail screen's gallery, so opening a
                      // listing zooms the same photo into place.
                      Hero(
                        tag: productHeroTag(product.id),
                        child: ListingImage(
                          url: product.coverImage,
                          label: product.name,
                          seed: product.id,
                        ),
                      ),
                      if (paused || soldOut)
                        Container(
                          color: Colors.black.withValues(
                            alpha: paused ? 0.42 : 0.5,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            paused ? 'PAUSED' : 'SOLD OUT',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                      Positioned(
                        top: 10,
                        left: 10,
                        child: StatusChip.condition(product.condition),
                      ),
                      if (trailing != null)
                        PositionedDirectional(top: 0, end: 0, child: trailing!),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 8),
                      LayoutBuilder(
                        builder: (context, constraints) => Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Container(
                              constraints: BoxConstraints(
                                maxWidth: constraints.maxWidth,
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 9,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: scheme.primaryContainer,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                Format.money(product.price),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.labelLarge?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: scheme.onPrimaryContainer,
                                ),
                              ),
                            ),
                            if (product.isInStock && product.stock <= 3)
                              Text(
                                Format.stock(product.stock),
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: scheme.error,
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (showSeller && product.sellerUsername.isNotEmpty) ...[
                        const SizedBox(height: 7),
                        Row(
                          children: [
                            Icon(
                              Icons.person_outline_rounded,
                              size: 13,
                              color: scheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                sellerHandle(product.sellerUsername, sales),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Hero tag shared by a listing's card cover and its detail gallery, so the
/// photo flies between the two instead of blinking.
String productHeroTag(String productId) => 'product-cover-$productId';

/// Column count and cell height for a catalogue grid [width] logical pixels
/// wide. The cover is square, so the cell is one cover plus a fixed text band;
/// this keeps tablets from stretching a two-column card twice as tall as its
/// content.
({int columns, double extent}) catalogueGridMetrics(
  double width, {
  int minColumns = 2,
}) {
  final columns = switch (width) {
    >= 1000 => 4,
    >= 700 => 3,
    _ => minColumns,
  };
  const gap = 12.0;
  final tileWidth = (width - gap * (columns - 1)) / columns;
  return (columns: columns, extent: tileWidth + 156);
}
