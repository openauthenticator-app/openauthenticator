import 'dart:io';

import 'package:flutter/material.dart';
import 'package:jovial_svg/jovial_svg.dart';
import 'package:open_authenticator/utils/image_type.dart';
import 'package:open_authenticator/utils/jovial_svg.dart';
import 'package:open_authenticator/utils/utils.dart';

/// Displays a classic image or a vector image.
class SmartImage extends StatelessWidget {
  /// The image key.
  /// Useful when [imageCache] should not be taken into account.
  final Key? imageKey;

  /// The image source.
  final String source;

  /// The width.
  final double? width;

  /// The height.
  final double? height;

  /// How to fit images.
  final BoxFit fit;

  /// The error widget builder.
  final Widget Function(BuildContext context)? errorBuilder;

  /// The image type.
  final ImageType imageType;

  /// The fade-in duration.
  final Duration? fadeInDuration;

  /// Creates a new smart image widget instance.
  SmartImage({
    super.key,
    this.imageKey,
    required this.source,
    this.width,
    this.height,
    this.fit = BoxFit.scaleDown,
    this.errorBuilder,
    ImageType? imageType,
    bool? autoDetectImageType,
    this.fadeInDuration = const Duration(milliseconds: 200),
  }) : imageType = ((autoDetectImageType ?? imageType == null) ? ImageType.inferFromSource(source) : imageType!);

  @override
  Widget build(BuildContext context) {
    if (source.startsWith('http://') || source.startsWith('https://')) {
      if (imageType == ImageType.other) {
        return shouldFadeIn
            ? FadeInImage.memoryNetwork(
                key: imageKey,
                placeholder: kTransparentImage,
                placeholderCacheWidth: _cacheWidth,
                placeholderCacheHeight: _cacheWidth,
                image: source,
                width: width,
                height: height,
                imageCacheWidth: _cacheWidth,
                imageCacheHeight: _cacheHeight,
                fadeInDuration: fadeInDuration!,
                fit: fit,
                imageErrorBuilder: errorBuilder == null ? null : ((context, error, stacktrace) => errorBuilder!(context)),
              )
            : Image.network(
                source,
                key: imageKey,
                width: width,
                height: height,
                cacheWidth: _cacheWidth,
                cacheHeight: _cacheHeight,
                fit: fit,
                errorBuilder: errorBuilder == null ? null : ((context, error, stacktrace) => errorBuilder!(context)),
              );
      }
      return SizedBox(
        width: width,
        height: height,
        child: ScalableImageWidget.fromSISource(
          si: ScalableImageSource.fromSvgHttpUrl(Uri.parse(source)),
          key: imageKey,
          fit: fit,
          onError: errorBuilder,
          onLoading: _vectorLoading,
          switcher: _vectorSwitcher,
        ),
      );
    }
    File file = File(source);
    if (!file.existsSync()) {
      return const SizedBox.shrink();
    }
    return switch (imageType) {
      ImageType.svg => SizedBox(
        width: width,
        height: height,
        child: ScalableImageWidget.fromSISource(
          si: ScalableImageSource.fromSvgFile(file, () => file.readAsString()),
          key: imageKey,
          fit: fit,
          onError: errorBuilder,
          onLoading: _vectorLoading,
          switcher: _vectorSwitcher,
        ),
      ),
      ImageType.si => SizedBox(
        width: width,
        height: height,
        child: ScalableImageWidget.fromSISource(
          si: SIFileSource(file: file),
          key: imageKey,
          fit: fit,
          onError: errorBuilder,
          onLoading: _vectorLoading,
          switcher: _vectorSwitcher,
        ),
      ),
      ImageType.other =>
        shouldFadeIn
            ? FadeInImage(
                key: imageKey,
                placeholder: ResizeImage.resizeIfNeeded(
                  _cacheWidth,
                  _cacheHeight,
                  MemoryImage(kTransparentImage),
                ),
                image: ResizeImage.resizeIfNeeded(
                  _cacheWidth,
                  _cacheHeight,
                  FileImage(file),
                ),
                width: width,
                height: height,
                fadeInDuration: fadeInDuration!,
                fit: fit,
                imageErrorBuilder: errorBuilder == null ? null : ((context, error, stacktrace) => errorBuilder!(context)),
              )
            : Image.file(
                file,
                key: imageKey,
                width: width,
                height: height,
                cacheWidth: _cacheWidth,
                cacheHeight: _cacheHeight,
                fit: fit,
                errorBuilder: errorBuilder == null ? null : ((context, error, stacktrace) => errorBuilder!(context)),
              ),
    };
  }

  /// Whether the image should fade in.
  bool get shouldFadeIn => fadeInDuration != null;

  /// The cache width.
  int? get _cacheWidth => width?.ceil();

  /// The cache height.
  int? get _cacheHeight => height?.ceil();

  /// The vector image switcher.
  Widget Function(BuildContext context, Widget child)? get _vectorSwitcher => shouldFadeIn
      ? ((context, child) => AnimatedSwitcher(
          switchInCurve: Curves.easeIn,
          switchOutCurve: Curves.easeOut,
          duration: fadeInDuration!,
          child: child,
        ))
      : null;

  /// The vector image loading widget.
  Widget Function(BuildContext) get _vectorLoading =>
      (context) => SizedBox(
        width: width ?? 1,
        height: height ?? 1,
      );
}
