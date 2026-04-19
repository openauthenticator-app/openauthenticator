import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
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
    if (_isHttpSource) {
      return switch (imageType) {
        .svg => SizedBox(
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
        ),
        _ => _buildNetworkRaster(),
      };
    }
    File file = File(source);
    if (!file.existsSync()) {
      return const SizedBox.shrink();
    }
    return switch (imageType) {
      .svg => SizedBox(
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
      .si => SizedBox(
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
      .other =>
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

  /// Whether the source is remote.
  bool get _isHttpSource => source.startsWith('http://') || source.startsWith('https://');

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

  /// Builds a raster network image.
  Widget _buildNetworkRaster() => shouldFadeIn
      ? FadeInImage.memoryNetwork(
          key: imageKey,
          placeholder: kTransparentImage,
          placeholderCacheWidth: _cacheWidth,
          placeholderCacheHeight: _cacheHeight,
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

/// Resolves the image type asynchronously before delegating to [SmartImage].
class ResolvedSmartImage extends StatefulWidget {
  /// The image key.
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

  /// The type hint, if already known.
  final ImageType? imageType;

  /// The fade-in duration.
  final Duration? fadeInDuration;

  /// The widget displayed while resolving.
  final Widget? loading;

  /// Creates a new resolved smart image widget instance.
  const ResolvedSmartImage({
    super.key,
    this.imageKey,
    required this.source,
    this.width,
    this.height,
    this.fit = BoxFit.scaleDown,
    this.errorBuilder,
    this.imageType,
    this.fadeInDuration = const Duration(milliseconds: 200),
    this.loading,
  });

  @override
  State<ResolvedSmartImage> createState() => _ResolvedSmartImageState();
}

/// The resolved smart image widget state.
class _ResolvedSmartImageState extends State<ResolvedSmartImage> {
  /// The resolved type cache.
  static final Map<String, ImageType> _resolvedTypeCache = {};

  /// The resolved type future.
  late Future<ImageType> _resolvedTypeFuture = _resolveType();

  @override
  void didUpdateWidget(covariant ResolvedSmartImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.source != widget.source || oldWidget.imageType != widget.imageType) {
      _resolvedTypeFuture = _resolveType();
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<ImageType>(
    future: _resolvedTypeFuture,
    builder: (context, snapshot) {
      if (snapshot.hasData) {
        return SmartImage(
          imageKey: widget.imageKey,
          source: widget.source,
          width: widget.width,
          height: widget.height,
          fit: widget.fit,
          errorBuilder: widget.errorBuilder,
          imageType: snapshot.data!,
          fadeInDuration: widget.fadeInDuration,
        );
      }
      return widget.loading ??
          SizedBox(
            width: widget.width,
            height: widget.height,
          );
    },
  );

  /// Resolves the image type.
  Future<ImageType> _resolveType() async {
    if (widget.imageType != null) {
      return widget.imageType!;
    }

    ImageType inferred = ImageType.inferFromSource(widget.source);
    if (inferred != .other) {
      return inferred;
    }

    ImageType? cached = _resolvedTypeCache[widget.source];
    if (cached != null) {
      return cached;
    }

    ImageType resolved = await _resolveTypeFromSource(widget.source);
    _resolvedTypeCache[widget.source] = resolved;
    return resolved;
  }

  /// Resolves the image type from the source.
  Future<ImageType> _resolveTypeFromSource(String source) async {
    if (source.startsWith('http://') || source.startsWith('https://')) {
      try {
        http.Response response = await http.head(Uri.parse(source));
        ImageType type = ImageType.inferFromMimeType(response.headers['content-type']);
        if (type != .other) {
          return type;
        }
      } catch (_) {}
      return .other;
    }

    File file = File(source);
    if (!await file.exists()) {
      return .other;
    }
    try {
      List<int> bytes = await file.openRead(0, 512).fold<List<int>>([], (previous, element) => previous..addAll(element));
      String header = String.fromCharCodes(bytes).trimLeft().toLowerCase();
      if (header.startsWith('<?xml') || header.startsWith('<svg')) {
        return .svg;
      }
    } catch (_) {}
    return .other;
  }
}
