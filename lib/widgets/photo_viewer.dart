import 'package:flutter/services.dart';

import '../core/l10n.dart';
import '../core/motion.dart';
import 'listing_image.dart';
import 'ui.dart';

/// A full-screen route above the tab shell, never a clipped gallery dialog.
/// Empty placeholders cannot open a meaningless zoom view.
Future<void> showPhotoViewer(
  BuildContext context, {
  required List<String> images,
  required String label,
  int initialIndex = 0,
  ValueChanged<int>? onPageChanged,
}) async {
  final photos = images
      .asMap()
      .entries
      .where((entry) => entry.value.isNotEmpty)
      .toList();
  if (photos.isEmpty) return;
  final selected = photos.indexWhere((entry) => entry.key == initialIndex);
  final reduced = Motion.reduced(context);
  await Navigator.of(context, rootNavigator: true).push<void>(
    PageRouteBuilder(
      fullscreenDialog: true,
      transitionDuration: reduced ? Duration.zero : Motion.slow,
      reverseTransitionDuration: reduced ? Duration.zero : Motion.medium,
      pageBuilder: (_, _, _) => PhotoViewer(
        images: photos.map((entry) => entry.value).toList(),
        label: label,
        initialIndex: selected < 0 ? 0 : selected,
        onPageChanged: (index) => onPageChanged?.call(photos[index].key),
      ),
      transitionsBuilder: (_, animation, _, child) => FadeTransition(
        opacity: animation.drive(CurveTween(curve: Motion.standard)),
        child: ScaleTransition(
          scale: animation.drive(
            Tween(
              begin: 0.93,
              end: 1.0,
            ).chain(CurveTween(curve: Motion.spring)),
          ),
          child: child,
        ),
      ),
    ),
  );
}

/// Explicit close/zoom/previous/next controls complement pinch, double tap,
/// horizontal paging, Android back and keyboard shortcuts.
class PhotoViewer extends StatefulWidget {
  const PhotoViewer({
    super.key,
    required this.images,
    required this.label,
    this.initialIndex = 0,
    this.onPageChanged,
  }) : assert(images.length > 0),
       assert(initialIndex >= 0 && initialIndex < images.length);
  final List<String> images;
  final String label;
  final int initialIndex;
  final ValueChanged<int>? onPageChanged;

  @override
  State<PhotoViewer> createState() => _PhotoViewerState();
}

class _PhotoViewerState extends State<PhotoViewer> {
  late final _pages = PageController(initialPage: widget.initialIndex);
  late final _keys = List.generate(
    widget.images.length,
    (_) => GlobalKey<_ZoomablePhotoState>(),
  );
  late int _page = widget.initialIndex;
  bool _zoomed = false;

  void _move(int delta) {
    final next = (_page + delta).clamp(0, widget.images.length - 1);
    if (next == _page) return;
    _keys[_page].currentState?.reset();
    if (Motion.reduced(context)) {
      _pages.jumpToPage(next);
    } else {
      _pages.animateToPage(
        next,
        duration: Motion.medium,
        curve: Motion.standard,
      );
    }
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () =>
            Navigator.of(context).pop(),
        const SingleActivator(LogicalKeyboardKey.arrowRight): () =>
            _move(rtl ? -1 : 1),
        const SingleActivator(LogicalKeyboardKey.arrowLeft): () =>
            _move(rtl ? 1 : -1),
      },
      child: Focus(
        autofocus: true,
        child: Theme(
          data: Theme.of(context).copyWith(
            iconButtonTheme: IconButtonThemeData(
              style: ButtonStyle(
                foregroundColor: WidgetStateProperty.resolveWith(
                  (states) => states.contains(WidgetState.disabled)
                      ? Colors.white30
                      : Colors.white,
                ),
                foregroundBuilder: springButtonForeground,
              ),
            ),
          ),
          child: AnnotatedRegion<SystemUiOverlayStyle>(
            value: SystemUiOverlayStyle.light,
            child: Scaffold(
              backgroundColor: const Color(0xFF0B1511),
              body: SafeArea(
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
                      child: Row(
                        children: [
                          IconButton(
                            tooltip: context.tr('Close'),
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.close_rounded),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              widget.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(color: Colors.white),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Semantics(
                            liveRegion: true,
                            child: Text(
                              '${_page + 1} / ${widget.images.length}',
                              style: const TextStyle(color: Colors.white70),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: PageView.builder(
                        controller: _pages,
                        physics: _zoomed
                            ? const NeverScrollableScrollPhysics()
                            : const BouncingScrollPhysics(),
                        itemCount: widget.images.length,
                        onPageChanged: (index) {
                          setState(() {
                            _page = index;
                            _zoomed = false;
                          });
                          widget.onPageChanged?.call(index);
                        },
                        itemBuilder: (context, index) => _ZoomablePhoto(
                          key: _keys[index],
                          url: widget.images[index],
                          label: widget.label,
                          onZoomChanged: (zoomed) {
                            if (mounted &&
                                index == _page &&
                                zoomed != _zoomed) {
                              setState(() => _zoomed = zoomed);
                            }
                          },
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 12, 8, 16),
                      child: Row(
                        children: [
                          if (widget.images.length > 1)
                            IconButton(
                              tooltip: context.tr('Previous photo'),
                              onPressed: _page > 0 ? () => _move(-1) : null,
                              icon: const Icon(Icons.arrow_back_rounded),
                            ),
                          Expanded(
                            child: Text(
                              'Pinch or double-tap to zoom',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: Colors.white70),
                            ),
                          ),
                          IconButton(
                            tooltip: context.tr(
                              _zoomed ? 'Reset zoom' : 'Zoom in',
                            ),
                            onPressed: () =>
                                _keys[_page].currentState?.toggleZoom(),
                            icon: Icon(
                              _zoomed
                                  ? Icons.zoom_out_rounded
                                  : Icons.zoom_in_rounded,
                            ),
                          ),
                          if (widget.images.length > 1)
                            IconButton(
                              tooltip: context.tr('Next photo'),
                              onPressed: _page < widget.images.length - 1
                                  ? () => _move(1)
                                  : null,
                              icon: const Icon(Icons.arrow_forward_rounded),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ZoomablePhoto extends StatefulWidget {
  const _ZoomablePhoto({
    super.key,
    required this.url,
    required this.label,
    required this.onZoomChanged,
  });
  final String url;
  final String label;
  final ValueChanged<bool> onZoomChanged;

  @override
  State<_ZoomablePhoto> createState() => _ZoomablePhotoState();
}

class _ZoomablePhotoState extends State<_ZoomablePhoto>
    with SingleTickerProviderStateMixin {
  final _transform = TransformationController();
  late final _controller = AnimationController(
    vsync: this,
    duration: Motion.medium,
  )..addListener(_tick);
  Animation<Matrix4>? _animation;
  Offset? _tap;
  bool _zoomed = false;

  @override
  void initState() {
    super.initState();
    _transform.addListener(_changed);
  }

  void _changed() {
    final zoomed = _transform.value.getMaxScaleOnAxis() > 1.01;
    if (zoomed != _zoomed) {
      _zoomed = zoomed;
      widget.onZoomChanged(zoomed);
    }
  }

  void _tick() {
    if (_animation != null) _transform.value = _animation!.value;
  }

  void reset() => _setTransform(Matrix4.identity());

  void toggleZoom([Offset? position]) {
    if (_zoomed) {
      reset();
      return;
    }
    final size = context.size ?? Size.zero;
    final focal = position ?? Offset(size.width / 2, size.height / 2);
    _setTransform(
      Matrix4.diagonal3Values(3, 3, 1)
        ..setTranslationRaw(-focal.dx * 2, -focal.dy * 2, 0),
    );
  }

  void _setTransform(Matrix4 target) {
    _controller.stop();
    if (Motion.reduced(context)) {
      _transform.value = target;
      return;
    }
    _animation = Matrix4Tween(
      begin: _transform.value.clone(),
      end: target,
    ).chain(CurveTween(curve: Motion.standard)).animate(_controller);
    _controller.forward(from: 0);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (Motion.reduced(context) && _controller.isAnimating) {
      _controller.value = 1;
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _transform.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
    onDoubleTapDown: (details) => _tap = details.localPosition,
    onDoubleTap: () => toggleZoom(_tap),
    child: InteractiveViewer(
      transformationController: _transform,
      minScale: 1,
      maxScale: 4,
      onInteractionStart: (_) => _controller.stop(),
      child: SizedBox.expand(
        child: ListingImage(
          url: widget.url,
          label: widget.label,
          fit: BoxFit.contain,
        ),
      ),
    ),
  );
}
