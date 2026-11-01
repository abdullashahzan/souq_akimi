import 'package:cached_network_image/cached_network_image.dart';
import 'package:souq_akimi/widgets/ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositories/image_store.dart';
import '../providers/images.dart';
import '../core/motion.dart';

/// A listing photo with a graceful fallback.
///
/// Two shapes of value reach this widget:
///   * `img:{id}` — a photo stored in Firestore (see [ImageStore]), decoded
///     lazily the first time a card renders it;
///   * a plain URL — seeded demo rows and anything else external.
///
/// Listings created offline (or seeded demo rows) may have no images at all,
/// so an empty value renders a tinted monogram tile instead of a broken-image
/// icon.
class ListingImage extends ConsumerWidget {
  const ListingImage({
    super.key,
    required this.url,
    this.label = '',
    this.fit = BoxFit.cover,
    this.seed,
  });

  final String url;

  /// Used for the fallback monogram (usually the listing name).
  final String label;
  final BoxFit fit;

  /// Stable tint seed (usually the listing id) so a tile keeps its colour.
  final String? seed;

  static const List<Color> _tints = [
    Color(0xFF0F6B5C),
    Color(0xFF274690),
    Color(0xFF8A3B12),
    Color(0xFF6B2D5C),
    Color(0xFF2F6B4F),
    Color(0xFF3B3F8A),
  ];

  Color _tint(BuildContext context) {
    final key = seed ?? label;
    final scheme = Theme.of(context).colorScheme;
    if (key.isEmpty) return scheme.surfaceContainerHighest;
    final index =
        key.codeUnits.fold<int>(0, (sum, unit) => sum + unit) % _tints.length;
    return _tints[index];
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (url.isEmpty) return _fallback(context);

    if (ImageStore.isToken(url)) {
      final photo = ref.watch(listingImageBytesProvider(url));
      if (photo.hasValue) {
        final bytes = photo.value;
        if (bytes == null) return _fallback(context);
        return Image.memory(
          bytes,
          fit: fit,
          gaplessPlayback: true,
          errorBuilder: (context, error, stack) => _fallback(context),
        );
      }
      if (photo.hasError) return _fallback(context);
      return _placeholder(context);
    }

    return CachedNetworkImage(
      imageUrl: url,
      fit: fit,
      fadeInDuration: Motion.reduced(context) ? Duration.zero : Motion.fast,
      placeholder: (context, _) => _placeholder(context),
      errorWidget: (context, _, _) => _fallback(context),
    );
  }

  Widget _placeholder(BuildContext context) =>
      Container(color: Theme.of(context).colorScheme.surfaceContainerHighest);

  Widget _fallback(BuildContext context) {
    final initial = label.trim().isEmpty ? '?' : label.trim()[0].toUpperCase();
    return Container(
      color: _tint(context),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 32,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
