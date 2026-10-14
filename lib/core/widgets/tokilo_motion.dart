import 'package:flutter/material.dart';

/// Motion replays on viewport entry and sleeps when hidden or backgrounded.
class ViewportMotion extends StatefulWidget {
  const ViewportMotion({super.key, required this.builder, this.loop = false});
  final Widget Function(BuildContext, double) builder;
  final bool loop;

  @override
  State<ViewportMotion> createState() => _ViewportMotionState();
}

class _ViewportMotionState extends State<ViewportMotion>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.loop
        ? const Duration(seconds: 6)
        : const Duration(milliseconds: 550),
  );
  ScrollPosition? _position;
  bool _visible = false;
  bool _scheduled = false;
  bool _resumed = true;
  bool _reduced = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduced = MediaQuery.disableAnimationsOf(context);
    final position = Scrollable.maybeOf(context)?.position;
    if (position != _position) {
      _position?.removeListener(_scheduleVisibilityCheck);
      _position = position;
      _position?.addListener(_scheduleVisibilityCheck);
    }
    _scheduleVisibilityCheck();
  }

  void _scheduleVisibilityCheck() {
    if (_scheduled || !mounted) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      _checkVisibility();
    });
  }

  void _checkVisibility() {
    if (!mounted) return;
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.hasSize || !box.attached) return;
    final top = box.localToGlobal(Offset.zero).dy;
    final visible =
        top < MediaQuery.sizeOf(context).height &&
        top + box.size.height > 0 &&
        TickerMode.valuesOf(context).enabled &&
        _resumed;
    if (_reduced) {
      _controller.stop();
      _controller.value = widget.loop ? .5 : 1;
    } else if (visible && (!_visible || !_controller.isAnimating)) {
      if (widget.loop) {
        _controller.repeat(reverse: true);
      } else if (_controller.value < 1) {
        _controller.forward();
      }
    } else if (!visible) {
      _controller.stop();
      if (!widget.loop) _controller.value = 0;
    }
    _visible = visible;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _resumed = state == AppLifecycleState.resumed;
    _checkVisibility();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _position?.removeListener(_scheduleVisibilityCheck);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    builder: (context, _) => widget.builder(context, _controller.value),
  );
}

class ScrollReveal extends StatelessWidget {
  const ScrollReveal({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => ViewportMotion(
    builder: (context, value) {
      final progress = Curves.easeOutCubic.transform(value);
      return Opacity(
        opacity: .25 + .75 * progress,
        child: Transform.translate(
          offset: Offset(0, 18 * (1 - progress)),
          child: child,
        ),
      );
    },
  );
}
