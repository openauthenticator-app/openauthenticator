import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A simple rotation animation widget.
class RotationAnimation extends StatefulWidget {
  /// The child.
  final Widget child;

  /// The duration.
  final Duration duration;

  /// Creates a new rotation animation widget instance.
  const RotationAnimation({
    super.key,
    required this.child,
    this.duration = const Duration(seconds: 1),
  });

  @override
  State<RotationAnimation> createState() => _RotationAnimationState();
}

/// The rotation animation widget state.
class _RotationAnimationState extends State<RotationAnimation> with SingleTickerProviderStateMixin {
  /// The animation controller.
  late final AnimationController controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  )..repeat();

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    child: widget.child,
    builder: (context, child) => Transform.rotate(
      angle: -controller.value * 2.0 * math.pi,
      child: child,
    ),
  );

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }
}
