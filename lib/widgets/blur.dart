import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:forui/forui.dart';

/// Allows to blur a widget. Kudos to "jagritjkh/blur" for the initial implementation.
class Blur extends StatelessWidget {
  /// A widget to display below the blur effect.
  final Widget? below;

  /// A widget to display above the blur effect.
  final Widget? above;

  /// Radius of the child to be blurred.
  final BorderRadius? borderRadius;

  /// Opacity of the blurColor.
  final double colorOpacity;

  /// Widget that can be stacked over blurred widget.
  final Widget? overlay;

  /// Alignment geometry of the overlay.
  final AlignmentGeometry alignment;

  /// Creates a new blur widget instance.
  const Blur({
    super.key,
    this.below,
    this.above,
    this.borderRadius,
    this.colorOpacity = 0.5,
    this.overlay,
    this.alignment = Alignment.center,
  });

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: above == null || below == null,
    child: ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.zero,
      child: Stack(
        children: [
          ?below,
          Positioned.fill(
            child: BackdropFilter(
              filter: context.theme.dialogRouteStyle.barrierFilter?.call(1) ?? ImageFilter.blur(sigmaX: 5, sigmaY: 5),
              child: Container(
                decoration: BoxDecoration(
                  color: context.theme.colors.background.withValues(alpha: colorOpacity),
                ),
                alignment: alignment,
                child: overlay,
              ),
            ),
          ),
          ?above,
        ],
      ),
    ),
  );
}
