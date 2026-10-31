import 'package:souq_akimi/widgets/ui.dart';

import '../../core/l10n.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/motion.dart';
import '../../models/enums.dart';
import '../../providers/catalogue.dart';
import '../../widgets/common.dart';
import '../../widgets/language_button.dart';
import '../../widgets/service_card.dart';

/// Browse services other students offer: printouts, tutoring, delivery runs…
class ServicesScreen extends ConsumerStatefulWidget {
  const ServicesScreen({super.key});

  @override
  ConsumerState<ServicesScreen> createState() => _ServicesScreenState();
}

class _ServicesScreenState extends ConsumerState<ServicesScreen> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final servicesAsync = ref.watch(servicesProvider);
    final filters = ref.watch(serviceFiltersProvider);
    final results = ref.watch(filteredServicesProvider);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFF4C76A), Color(0xFFE3A33B)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x2EE3A33B),
                          blurRadius: 16,
                          offset: Offset(0, 7),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.handyman_rounded,
                      color: Color(0xFF3A2A06),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Campus services',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.4,
                              ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          'Homework help, printouts, delivery runs and more',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                  ),
                  _ServiceHeaderAction(
                    icon: Icons.inbox_outlined,
                    tooltip: context.tr('My requests'),
                    onTap: () => context.push('/requests'),
                  ),
                  const SizedBox(width: 8),
                  const LanguageButton(),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: TextField(
                controller: _controller,
                onChanged: (value) =>
                    ref.read(serviceFiltersProvider.notifier).setQuery(value),
                decoration: InputDecoration(
                  hintText: context.tr('Search services…'),
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: filters.query.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.clear_rounded),
                          onPressed: () {
                            _controller.clear();
                            ref
                                .read(serviceFiltersProvider.notifier)
                                .setQuery('');
                          },
                        ),
                ),
              ),
            ),
            SizedBox(
              height: 52,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  Padding(
                    padding: const EdgeInsetsDirectional.only(end: 8),
                    child: FilterChip(
                      label: const Text('All'),
                      selected: filters.category == null,
                      labelStyle: TextStyle(
                        color: filters.category == null
                            ? Theme.of(context).colorScheme.onPrimary
                            : Theme.of(context).colorScheme.onSurface,
                        fontWeight: FontWeight.w700,
                      ),
                      onSelected: (_) => ref
                          .read(serviceFiltersProvider.notifier)
                          .setCategory(null),
                    ),
                  ),
                  for (final category in ServiceCategory.values)
                    Padding(
                      padding: const EdgeInsetsDirectional.only(end: 8),
                      child: FilterChip(
                        avatar: Icon(
                          serviceCategoryIcon(category),
                          size: 16,
                          color: filters.category == category
                              ? Theme.of(context).colorScheme.onPrimary
                              : Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        label: Text(category.label),
                        selected: filters.category == category,
                        labelStyle: TextStyle(
                          color: filters.category == category
                              ? Theme.of(context).colorScheme.onPrimary
                              : Theme.of(context).colorScheme.onSurface,
                          fontWeight: FontWeight.w700,
                        ),
                        onSelected: (selected) => ref
                            .read(serviceFiltersProvider.notifier)
                            .setCategory(selected ? category : null),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: servicesAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => ErrorRetry(
                  error: error,
                  onRetry: () => ref.invalidate(servicesProvider),
                ),
                data: (_) {
                  if (results.isEmpty) {
                    return EmptyState(
                      icon: Icons.handyman_rounded,
                      title: 'No services found',
                      message: 'Offer your own skills and other students will find you.',
                      action: FilledButton.icon(
                        onPressed: () => context.push('/sell/service'),
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('Offer a service'),
                      ),
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 124),
                    itemCount: results.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 14),
                    itemBuilder: (context, index) {
                      final service = results[index];
                      return FadeSlideIn(
                        index: index,
                        child: ServiceCard(
                          service: service,
                          onTap: () => context.push('/service/${service.id}'),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ServiceHeaderAction extends StatelessWidget {
  const _ServiceHeaderAction({
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
