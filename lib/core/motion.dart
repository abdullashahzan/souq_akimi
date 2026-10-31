import 'dart:async';

import 'package:souq_akimi/widgets/ui.dart';

/// Shared timing for the app's "light" motion.
///
/// Every animation here is short, eased and subtle: nothing should ever make a
/// student wait for the interface, and all of it is skipped when the platform
/// asks for reduced motion (accessibility settings, "remove animations").
class Motion {
  const Motion._();

  /// Press feedback, chip changes.
  static const Duration fast = Duration(milliseconds: 140);

  /// Page and card entrances.
  static const Duration medium = Duration(milliseconds: 260);

  /// Larger surface changes.
  static const Duration slow = Duration(milliseconds: 420);

  /// Added per item when a list enters, so the rows ripple in.
  static const Duration stagger = Duration(milliseconds: 45);

  static const Curve standard = Curves.easeOutCubic;
  static const Curve gentle = Curves.easeInOutCubic;

  /// True when the user (or the OS) asked us not to animate.
  static bool reduced(BuildContext context) =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;
}

/// Fades and lifts its child into place on first build.
///
/// Pass [index] for lists: each row waits a further [stagger] behind the one
/// before it, which reads as a quick ripple rather than a single pop. The
/// delay is capped so the last card of a long grid is never visibly late.
class FadeSlideIn extends StatefulWidget {
  const FadeSlideIn({
    super.key,
    required this.child,
    this.index = 0,
    this.duration = Motion.medium,
    this.stagger = Motion.stagger,
    this.maxStagger = 8,
    this.offset = const Offset(0, 0.06),
  });

  final Widget child;
  final int index;
  final Duration duration;
  final Duration stagger;
  final int maxStagger;

  /// Start offset, as a fraction of the child's size.
  final Offset offset;

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  );
  late final Animation<double> _fade = CurvedAnimation(
    parent: _controller,
    curve: Motion.standard,
  );
  Timer? _timer;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;

    if (Motion.reduced(context)) {
      _controller.value = 1;
      return;
    }
    final steps = widget.index.clamp(0, widget.maxStagger);
    final delay = widget.stagger * steps;
    if (delay == Duration.zero) {
      _controller.forward();
    } else {
      _timer = Timer(delay, () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _fade,
      builder: (context, child) => Opacity(
        opacity: _fade.value,
        child: FractionalTranslation(
          translation: Offset(
            widget.offset.dx * (1 - _fade.value),
            widget.offset.dy * (1 - _fade.value),
          ),
          child: child,
        ),
      ),
      child: widget.child,
    );
  }
}

/// Shrinks its child very slightly while a finger is on it.
///
/// Sits *outside* the child's ink response, so the material highlight and this
/// scale happen together and the layout is untouched (a transform, not a size
/// change — no jumping rows).
class PressableScale extends StatefulWidget {
  const PressableScale({super.key, required this.child, this.scale = 0.97});

  final Widget child;

  /// How far to shrink while pressed. Keep it under ~0.05.
  final double scale;

  @override
  State<PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<PressableScale>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: Motion.fast,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool _enabled = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _enabled = !Motion.reduced(context);
  }

  @override
  Widget build(BuildContext context) {
    if (!_enabled) return widget.child;
    return Listener(
      onPointerDown: (_) => _controller.forward(),
      onPointerUp: (_) => _controller.reverse(),
      onPointerCancel: (_) => _controller.reverse(),
      child: ScaleTransition(
        scale: Tween<double>(
          begin: 1,
          end: widget.scale,
        ).animate(CurvedAnimation(parent: _controller, curve: Motion.standard)),
        child: widget.child,
      ),
    );
  }
}

/// A cross-fade + lift for content that swaps in place (a loading spinner
/// giving way to a grid, one empty state replacing another).
class MotionSwitcher extends StatelessWidget {
  const MotionSwitcher({
    super.key,
    required this.child,
    this.duration = Motion.medium,
  });

  final Widget child;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: Motion.reduced(context) ? Duration.zero : duration,
      switchInCurve: Motion.standard,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.02),
            end: Offset.zero,
          ).animate(animation),
          child: child,
        ),
      ),
      child: child,
    );
  }
}
