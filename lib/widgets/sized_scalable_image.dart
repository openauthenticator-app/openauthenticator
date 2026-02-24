import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:jovial_svg/jovial_svg.dart';

/// A sized scalable image widget.
class SizedScalableImage extends StatelessWidget {
  /// The width.
  final double? width;

  /// The height.
  final double? height;

  /// The fit parameter to pass to the SVG widget.
  final BoxFit fit;

  /// The padding.
  final EdgeInsetsGeometry? padding;

  /// The asset path.
  final String asset;

  /// The alignment.
  final Alignment alignment;

  /// Whether to put the image widget inside of a container (if both [width] / [height] & [padding] are specified).
  final bool useContainer;

  /// Creates a new sized scalable image widget instance.
  const SizedScalableImage({
    super.key,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
    this.padding,
    required this.asset,
    this.alignment = Alignment.center,
    this.useContainer = false,
  });

  @override
  Widget build(BuildContext context) {
    Widget child = ScalableImageWidget.fromSISource(
      si: ScalableImageSource.fromSI(
        rootBundle,
        asset,
      ),
      fit: fit,
      alignment: alignment,
    );
    if (useContainer) {
      if ((width != null || height != null) && padding != null) {
        child = Container(
          width: width,
          height: height,
          padding: padding,
          child: child,
        );
      }
    } else {
      if (width != null || height != null) {
        child = SizedBox(
          width: width,
          height: height,
          child: child,
        );
      }
      if (padding != null) {
        child = Padding(
          padding: padding!,
          child: child,
        );
      }
    }
    return child;
  }
}
