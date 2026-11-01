import '../core/l10n.dart';
import '../core/motion.dart';
import 'listing_image.dart';
import 'photo_viewer.dart';
import 'ui.dart';

/// Tappable photography without changing the surrounding card's destination.
class PhotoPreview extends StatelessWidget {
  const PhotoPreview({
    super.key,
    required this.images,
    required this.label,
    required this.child,
    this.initialIndex = 0,
    this.onPageChanged,
  });
  final List<String> images;
  final String label;
  final Widget child;
  final int initialIndex;
  final ValueChanged<int>? onPageChanged;

  @override
  Widget build(BuildContext context) {
    if (images.isEmpty || images.every((image) => image.isEmpty)) return child;
    return Semantics(
      button: true,
      label: context.tr('View photo'),
      child: Tooltip(
        message: context.tr('View full-screen'),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => showPhotoViewer(
            context,
            images: images,
            label: label,
            initialIndex: initialIndex,
            onPageChanged: onPageChanged,
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Shared swipeable product/service gallery with a clear enlargement affordance.
class ListingGallery extends StatefulWidget {
  const ListingGallery({
    super.key,
    required this.images,
    required this.label,
    required this.seed,
    this.heroTag,
    this.placeholder,
  });
  final List<String> images;
  final String label;
  final String seed;
  final String? heroTag;
  final Widget? placeholder;

  @override
  State<ListingGallery> createState() => _ListingGalleryState();
}

class _ListingGalleryState extends State<ListingGallery> {
  final _pages = PageController();
  int _page = 0;

  @override
  void didUpdateWidget(ListingGallery oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.seed != oldWidget.seed || _page >= widget.images.length) {
      _page = 0;
      if (_pages.hasClients) _pages.jumpToPage(0);
    }
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _sync(int index) {
    if (!mounted || index >= widget.images.length) return;
    if (_pages.hasClients) _pages.jumpToPage(index);
  }

  @override
  Widget build(BuildContext context) {
    final photos = widget.images.isEmpty ? const [''] : widget.images;
    final page = _page.clamp(0, photos.length - 1);
    Widget gallery = PageView.builder(
      controller: _pages,
      physics: const BouncingScrollPhysics(),
      itemCount: photos.length,
      onPageChanged: (index) => setState(() => _page = index),
      itemBuilder: (context, index) => PhotoPreview(
        images: widget.images,
        label: widget.label,
        initialIndex: index,
        onPageChanged: _sync,
        child: photos[index].isEmpty && widget.placeholder != null
            ? widget.placeholder!
            : ListingImage(
                url: photos[index],
                label: widget.label,
                seed: index == 0 ? widget.seed : '${widget.seed}-$index',
              ),
      ),
    );
    if (widget.heroTag != null) {
      gallery = Hero(tag: widget.heroTag!, child: gallery);
    }
    return LayoutBuilder(
      builder: (context, constraints) => SizedBox(
        height: (constraints.maxWidth * 0.75).clamp(220.0, 380.0),
        child: Stack(
          fit: StackFit.expand,
          children: [
            gallery,
            if (widget.images.any((image) => image.isNotEmpty))
              PositionedDirectional(
                top: 12,
                end: 12,
                child: IconButton.filledTonal(
                  tooltip: context.tr('View full-screen'),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.white.withValues(alpha: 0.9),
                    foregroundColor: const Color(0xFF103F35),
                  ),
                  onPressed: () => showPhotoViewer(
                    context,
                    images: widget.images,
                    label: widget.label,
                    initialIndex: page,
                    onPageChanged: _sync,
                  ),
                  icon: const Icon(Icons.open_in_full_rounded, size: 21),
                ),
              ),
            if (photos.length > 1)
              PositionedDirectional(
                bottom: 14,
                start: 0,
                end: 0,
                child: IgnorePointer(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            for (var i = 0; i < photos.length; i++)
                              AnimatedContainer(
                                duration: Motion.reduced(context)
                                    ? Duration.zero
                                    : Motion.medium,
                                curve: Motion.spring,
                                width: i == page ? 22 : 7,
                                height: 7,
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: i == page
                                      ? Colors.white
                                      : Colors.white54,
                                  borderRadius: BorderRadius.circular(99),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
