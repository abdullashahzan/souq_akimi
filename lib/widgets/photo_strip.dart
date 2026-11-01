import 'package:souq_akimi/widgets/ui.dart';

import '../core/l10n.dart';

import '../core/app_config.dart';
import 'listing_image.dart';
import 'listing_gallery.dart';

/// The horizontal gallery editor used by both listing forms.
///
/// Photos are reordered only by which one is first (the cover); the picker
/// enforces the six-photo cap.
class PhotoStrip extends StatelessWidget {
  const PhotoStrip({
    super.key,
    required this.images,
    required this.busy,
    required this.onAdd,
    required this.onRemove,
    this.max = AppConfig.galleryImagesPerListing,
  });

  final List<String> images;
  final bool busy;
  final VoidCallback onAdd;
  final ValueChanged<int> onRemove;
  final int max;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Photos', style: theme.textTheme.titleSmall),
            const Spacer(),
            Text(
              '${images.length}/$max',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 100,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              for (var i = 0; i < images.length; i++)
                Padding(
                  padding: const EdgeInsetsDirectional.only(end: 10),
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: SizedBox(
                          width: 100,
                          height: 100,
                          child: PhotoPreview(
                            images: images,
                            label: context.tr('Photos'),
                            initialIndex: i,
                            child: ListingImage(
                              url: images[i],
                              label: context.tr(
                                'Photo {n}',
                                args: {'n': '${i + 1}'},
                              ),
                              seed: images[i],
                            ),
                          ),
                        ),
                      ),
                      if (i == 0)
                        const Positioned(top: 4, left: 4, child: CoverBadge()),
                      PositionedDirectional(
                        top: 0,
                        end: 0,
                        child: IconButton(
                          tooltip: context.tr('Remove photo'),
                          icon: const Icon(Icons.cancel, color: Colors.black87),
                          onPressed: busy ? null : () => onRemove(i),
                        ),
                      ),
                    ],
                  ),
                ),
              if (images.length < max)
                Semantics(
                  button: true,
                  label: 'Add photos',
                  child: InkWell(
                    onTap: busy ? null : onAdd,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: theme.colorScheme.outlineVariant,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        color: theme.colorScheme.surfaceContainerLow,
                      ),
                      child: busy
                          ? const Center(
                              child: SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            )
                          : const Icon(Icons.add_a_photo_outlined),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Up to {count} photos. The first is the cover.',
          args: {'count': '$max'},
          style: theme.textTheme.labelSmall,
        ),
      ],
    );
  }
}

class CoverBadge extends StatelessWidget {
  const CoverBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Text(
        'Cover',
        style: TextStyle(color: Colors.white, fontSize: 10),
      ),
    );
  }
}
