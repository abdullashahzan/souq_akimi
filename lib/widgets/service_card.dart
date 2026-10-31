import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:souq_akimi/widgets/ui.dart';

import '../core/format.dart';
import '../core/motion.dart';
import '../models/enums.dart';
import '../models/service.dart';
import '../providers/sellers.dart';
import 'listing_image.dart';

/// Icon shown for each service category in list rows and the filter sheet.
IconData serviceCategoryIcon(ServiceCategory category) => switch (category) {
  ServiceCategory.delivery => Icons.delivery_dining_outlined,
  ServiceCategory.homework => Icons.edit_note_outlined,
  ServiceCategory.project => Icons.architecture_outlined,
  ServiceCategory.printing => Icons.print_outlined,
  ServiceCategory.tutoring => Icons.school_outlined,
  ServiceCategory.design => Icons.brush_outlined,
  ServiceCategory.tech => Icons.build_outlined,
  ServiceCategory.other => Icons.handyman_outlined,
};

/// A service listing row: thumbnail, title, category, provider and price.
class ServiceCard extends ConsumerWidget {
  const ServiceCard({
    super.key,
    required this.service,
    this.onTap,
    this.trailing,
  });

  final Service service;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final sales = ref.watch(visibleSellerSalesProvider)[service.providerId];
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
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: SizedBox(
                      width: 88,
                      height: 88,
                      child: service.coverImage.isNotEmpty
                          ? ListingImage(
                              url: service.coverImage,
                              label: service.title,
                              seed: service.id,
                            )
                          : Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    scheme.secondaryContainer,
                                    scheme.secondary.withValues(alpha: 0.35),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                              ),
                              child: Icon(
                                serviceCategoryIcon(service.category),
                                color: scheme.onSecondaryContainer,
                                size: 34,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          service.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            height: 1.25,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: scheme.surfaceContainer,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                serviceCategoryIcon(service.category),
                                size: 13,
                                color: scheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                service.category.label,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 9),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                Format.priceWithUnit(
                                  service.price,
                                  service.priceType.suffix,
                                ),
                                style: theme.textTheme.labelLarge?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: scheme.primary,
                                ),
                              ),
                            ),
                            if (service.providerUsername.isNotEmpty)
                              Flexible(
                                child: Text(
                                  sellerHandle(service.providerUsername, sales),
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
                    ),
                  ),
                  ?trailing,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
