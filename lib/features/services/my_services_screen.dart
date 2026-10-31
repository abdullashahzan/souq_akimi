import 'package:souq_akimi/widgets/ui.dart';
import '../../core/l10n.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/feedback.dart';
import '../../core/motion.dart';
import '../../models/service.dart';
import '../../providers/catalogue.dart';
import '../../providers/dependencies.dart';
import '../../widgets/common.dart';
import '../../widgets/service_card.dart';

/// The services the signed-in student offers.
class MyServicesScreen extends ConsumerWidget {
  const MyServicesScreen({super.key});

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    Service service,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove service?'),
        content: Text(
          context.tr(
            '"{name}" will be deleted permanently.',
            args: {'name': service.title},
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
      await ref.read(serviceRepositoryProvider).delete(service.id);
      // Remove its Firestore-hosted cover too: orphaned image documents are
      // pure dead weight on the Spark 1 GiB allowance.
      await ref.read(imageStoreProvider).deleteAll(service.images);
      if (context.mounted) showMessage('Service removed.');
    } catch (error) {
      if (context.mounted) showError(error);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final servicesAsync = ref.watch(myServicesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My services'),
        actions: [
          TextButton(
            onPressed: () => context.push('/requests'),
            child: const Text('Requests'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/sell/service'),
        icon: const Icon(Icons.add),
        label: const Text('Offer a service'),
      ),
      body: servicesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => ErrorRetry(
          error: error,
          onRetry: () => ref.invalidate(myServicesProvider),
        ),
        data: (services) {
          if (services.isEmpty) {
            return const EmptyState(
              icon: Icons.handyman_outlined,
              title: 'No services yet',
              message: 'Offer printouts, tutoring, delivery runs or anything you are good at.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            itemCount: services.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final service = services[index];
              return FadeSlideIn(
                index: index,
                child: Opacity(
                  opacity: service.isActive ? 1 : 0.6,
                  child: ServiceCard(
                    service: service,
                    onTap: () => context.push('/service/${service.id}'),
                    trailing: PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert),
                      onSelected: (value) {
                        switch (value) {
                          case 'edit':
                            context.push('/service/${service.id}/edit');
                          case 'delete':
                            _delete(context, ref, service);
                        }
                      },
                      itemBuilder: (context) => const [
                        PopupMenuItem(
                          value: 'edit',
                          child: ListTile(
                            leading: Icon(Icons.edit_outlined),
                            title: Text('Edit'),
                          ),
                        ),
                        PopupMenuItem(
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
      ),
    );
  }
}
