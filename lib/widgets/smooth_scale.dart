import 'package:flutter/material.dart';

/// Huge thanks to `smooth_highlight` library for this.
class SmoothScale extends StatefulWidget {
  /// Scale target widget.
  /// If child has no size, nothing happens.
  final Widget child;

  /// Whether the scale is enabled.
  /// If false, the child does not scale at all. default to true.
  /// Ex. `enabled: count % 2 ==0` means that scale if count is only even.
  final bool enabled;

  /// Whether this scale works also in initState phase.
  /// If true, the scale will be applied to the child in initState phase. default to false.
  final bool useInitialScale;

  /// Triggered when the animation has been finished.
  final VoidCallback? onAnimationFinished;

  /// Creates a new smooth scale widget instance.
  const SmoothScale({
    super.key,
    required this.child,
    this.enabled = true,
    this.useInitialScale = false,
    this.onAnimationFinished,
  });

  @override
  State<SmoothScale> createState() => _SmoothScaleState();
}

/// The smooth highlight wiget state.
class _SmoothScaleState extends State<SmoothScale> with SingleTickerProviderStateMixin {
  /// Whether the widget has been disposed.
  bool disposed = false;

  /// The animation controller.
  late final animationController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 500),
  );

  /// The animation.
  late final Animation<double> animation = animationController
      .drive(
        CurveTween(curve: Curves.easeInOut),
      )
      .drive(
        Tween<double>(
          begin: 1,
          end: 1.03,
        ),
      );

  @override
  void initState() {
    super.initState();
    if (widget.useInitialScale) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        animationController.forward();
      });
    }
    animation.addStatusListener((status) async {
      switch (status) {
        case AnimationStatus.dismissed:
          if (mounted) {
            widget.onAnimationFinished?.call();
          }
          break;
        case AnimationStatus.completed:
          await Future.delayed(const Duration(milliseconds: 200));
          // this is workaround for following error occurs if you use in ListView scroll :
          // `called after AnimationController.dispose() AnimationController methods should not be used after calling dispose.`
          if (!disposed) {
            await animationController.reverse();
          }
          break;
        default:
          break;
      }
    });
  }

  @override
  void didUpdateWidget(covariant SmoothScale oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.enabled) {
      animationController.forward();
    }
  }

  @override
  void dispose() {
    animationController.dispose();
    disposed = true;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.enabled
      ? ScaleTransition(
          scale: animation,
          child: widget.child,
        )
      : widget.child;
}
