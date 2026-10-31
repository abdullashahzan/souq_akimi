import 'package:souq_akimi/widgets/ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/feedback.dart';
import '../../core/l10n.dart';
import '../../core/motion.dart';
import '../../models/product.dart';
import '../../providers/catalogue.dart';
import '../../providers/dependencies.dart';
import '../../widgets/common.dart';
import '../../widgets/product_card.dart';

/// The seller's own listings, with edit / pause / remove actions.
class MyListingsScreen extends ConsumerWidget {
  const MyListingsScreen({super.key});

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    Product product,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove listing?'),
        content: Text(
          context.tr(
            '"{name}" will be deleted permanently.',
            args: {'name': product.name},
          ),
        ),
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
    if (confirmed != true) return;
    try {
      await ref.read(productRepositoryProvider).delete(product.id);
      // Photos live in their own `images` documents; drop them with the
      // listing so deleted stock never keeps eating the free 1 GiB.
      await ref.read(imageStoreProvider).deleteAll(product.images);
      if (context.mounted) showMessage('Listing removed.');
    } catch (error) {
      if (context.mounted) showError(error);
    }
  }

  Future<void> _toggleActive(
    BuildContext context,
    WidgetRef ref,
    Product product,
  ) async {
    try {
      await ref
          .read(productRepositoryProvider)
          .update(product.copyWith(isActive: !product.isActive));
      if (context.mounted) {
        showMessage(
          product.isActive
              ? 'Listing paused — it is hidden from buyers.'
              : 'Listing is live again.',
        );
      }
    } catch (error) {
      if (context.mounted) showError(error);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listingsAsync = ref.watch(myProductsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('My listings')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/sell'),
        icon: const Icon(Icons.add),
        label: const Text('New listing'),
      ),
      body: listingsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => ErrorRetry(
          error: error,
          onRetry: () => ref.invalidate(myProductsProvider),
        ),
        data: (products) {
          if (products.isEmpty) {
            return const EmptyState(
              icon: Icons.inventory_2_outlined,
              title: 'No listings yet',
              message: 'Turn the things you no longer need into cash.',
            );
          }
          return LayoutBuilder(
            builder: (context, constraints) {
              final grid = catalogueGridMetrics(
                constraints.maxWidth - 32,
                minColumns: 1,
              );
              return GridView.builder(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                itemCount: products.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: grid.columns,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  mainAxisExtent: grid.extent,
                ),
                itemBuilder: (context, index) {
                  final product = products[index];
                  return FadeSlideIn(
                    index: index,
                    child: Opacity(
                      opacity: product.isActive ? 1 : 0.6,
                      child: ProductCard(
                        product: product,
                        onTap: () => context.push('/product/${product.id}'),
                        trailing: PopupMenuButton<String>(
                          icon: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              // The menu sits on top of the photo; a scrim keeps the
                              // dots readable even against a pale listing image.
                              color: Colors.black.withValues(alpha: 0.35),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.more_vert,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                          onSelected: (value) {
                            switch (value) {
                              case 'edit':
                                context.push('/product/${product.id}/edit');
                              case 'pause':
                                _toggleActive(context, ref, product);
                              case 'delete':
                                _confirmDelete(context, ref, product);
                            }
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                              value: 'edit',
                              child: ListTile(
                                leading: Icon(Icons.edit_outlined),
                                title: Text('Edit'),
                              ),
                            ),
                            PopupMenuItem(
                              value: 'pause',
                              child: ListTile(
                                leading: Icon(
                                  product.isActive
                                      ? Icons.pause_circle_outline
                                      : Icons.play_circle_outline,
                                ),
                                title: Text(
                                  product.isActive ? 'Pause listing' : 'Resume',
                                ),
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'delete',
                              child: ListTile(
                                leading: Icon(Icons.delete_outline),
                                title: Text('Remove'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
