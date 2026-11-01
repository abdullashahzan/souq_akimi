import 'dart:async';

import 'package:flutter/gestures.dart' show kTouchSlop;
import 'package:flutter/physics.dart';
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
  static const Curve spring = Curves.easeOutBack;

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
    if (Motion.reduced(context)) {
      _timer?.cancel();
      _controller.value = 1;
      _started = true;
      return;
    }
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

class _PressableScaleState extends State<PressableScale> {
  int? _pointer;
  Offset? _origin;
  bool _pressed = false;

  void _release() {
    _pointer = null;
    _origin = null;
    if (_pressed) setState(() => _pressed = false);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (event) {
        if (_pointer != null) return;
        _pointer = event.pointer;
        _origin = event.position;
        setState(() => _pressed = true);
      },
      onPointerMove: (event) {
        if (event.pointer == _pointer &&
            (event.position - _origin!).distance > kTouchSlop) {
          _release();
        }
      },
      onPointerUp: (event) {
        if (event.pointer == _pointer) _release();
      },
      onPointerCancel: (event) {
        if (event.pointer == _pointer) _release();
      },
      child: SpringScale(
        pressed: _pressed,
        scale: widget.scale,
        child: widget.child,
      ),
    );
  }
}

/// A damped spring rather than a repeated elastic loop. Transforms do not alter
/// layout or tap targets. State-driven controls also get keyboard feedback.
class SpringScale extends StatefulWidget {
  const SpringScale({
    super.key,
    required this.child,
    required this.pressed,
    this.enabled = true,
    this.scale = 0.95,
  });
  final Widget child;
  final bool pressed;
  final bool enabled;
  final double scale;

  @override
  State<SpringScale> createState() => _SpringScaleState();
}

class _SpringScaleState extends State<SpringScale>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController.unbounded(vsync: this, value: 1);
  bool _reduced = false;

  void _animate() {
    if (_reduced || !widget.enabled) {
      _controller.stop();
      _controller.value = 1;
      return;
    }
    final target = widget.pressed ? widget.scale : 1.0;
    _controller.animateWith(
      SpringSimulation(
        const SpringDescription(mass: 1, stiffness: 460, damping: 24),
        _controller.value,
        target,
        _controller.velocity,
      ),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduced = Motion.reduced(context);
    _animate();
  }

  @override
  void didUpdateWidget(SpringScale oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pressed != widget.pressed ||
        oldWidget.enabled != widget.enabled ||
        oldWidget.scale != widget.scale) {
      _animate();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    child: widget.child,
    builder: (context, child) {
      final scale = _controller.value.clamp(0.9, 1.04);
      return Transform(
        alignment: Alignment.center,
        transform: Matrix4.diagonal3Values(scale, 1 - (1 - scale) * 0.75, 1),
        child: child,
      );
    },
  );
}

/// Material buttons keep their native semantics, loading/disabled states and
/// ink response; only the label/icon layer squishes while the surface morphs.
Widget springButtonForeground(
  BuildContext context,
  Set<WidgetState> states,
  Widget? child,
) => SpringScale(
  pressed: states.contains(WidgetState.pressed),
  enabled: !states.contains(WidgetState.disabled),
  child: child ?? const SizedBox.shrink(),
);

class FluidPageTransitionsBuilder extends PageTransitionsBuilder {
  const FluidPageTransitionsBuilder();

  @override
  Duration get transitionDuration => Motion.slow;

  @override
  Duration get reverseTransitionDuration => Motion.medium;

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (Motion.reduced(context)) return child;
    final direction = Directionality.of(context) == TextDirection.rtl
        ? -1.0
        : 1.0;
    return FadeTransition(
      opacity: animation.drive(CurveTween(curve: Motion.standard)),
      child: SlideTransition(
        position: animation.drive(
          Tween(
            begin: Offset(0.045 * direction, 0.025),
            end: Offset.zero,
          ).chain(CurveTween(curve: Motion.spring)),
        ),
        child: ScaleTransition(
          scale: animation.drive(
            Tween(
              begin: 0.965,
              end: 1.0,
            ).chain(CurveTween(curve: Motion.spring)),
          ),
          child: ScaleTransition(
            scale: secondaryAnimation.drive(
              Tween(
                begin: 1.0,
                end: 0.985,
              ).chain(CurveTween(curve: Motion.standard)),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

class SouqScrollBehavior extends MaterialScrollBehavior {
  const SouqScrollBehavior();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) =>
      const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics());
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
        child: ScaleTransition(
          scale: animation.drive(
            Tween(begin: 0.9, end: 1.0).chain(CurveTween(curve: Motion.spring)),
          ),
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.02),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        ),
      ),
      child: child,
    );
  }
}
