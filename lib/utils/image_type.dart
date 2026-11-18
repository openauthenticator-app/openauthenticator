import 'package:flutter/foundation.dart';

/// The image type.
enum ImageType {
  /// "SVG" type.
  svg,

  /// "SI" type.
  si,

  /// Any other image.
  other;

  /// Infers an image type from the given [source].
  static ImageType inferFromSource(String source) {
    final String normalized = normalizeSource(source);
    if (normalized.endsWith('.svg')) {
      return svg;
    }
    if (normalized.endsWith('.si')) {
      return si;
    }
    return other;
  }

  /// Infers an image type from a MIME type.
  static ImageType inferFromMimeType(String? mimeType) {
    if (mimeType == null) {
      return other;
    }
    final String normalized = mimeType.toLowerCase();
    if (normalized.contains('image/svg+xml')) {
      return svg;
    }
    return other;
  }

  /// Normalizes a source to infer its type more reliably.
  static String normalizeSource(String source) {
    final Uri? uri = Uri.tryParse(source);
    if (uri == null) {
      return source.toLowerCase();
    }
    final String path = uri.path.isEmpty ? source : uri.path;
    return path.toLowerCase();
  }
}

/// A simple transparent image. Represented as a Uint8List, which was originally extracted from the Flutter codebase.
Uint8List kTransparentImage = Uint8List.fromList([
  0x89,
  0x50,
  0x4E,
  0x47,
  0x0D,
  0x0A,
  0x1A,
  0x0A,
  0x00,
  0x00,
  0x00,
  0x0D,
  0x49,
  0x48,
  0x44,
  0x52,
  0x00,
  0x00,
  0x00,
  0x01,
  0x00,
  0x00,
  0x00,
  0x01,
  0x08,
  0x06,
  0x00,
  0x00,
  0x00,
  0x1F,
  0x15,
  0xC4,
  0x89,
  0x00,
  0x00,
  0x00,
  0x0A,
  0x49,
  0x44,
  0x41,
  0x54,
  0x78,
  0x9C,
  0x63,
  0x00,
  0x01,
  0x00,
  0x00,
  0x05,
  0x00,
  0x01,
  0x0D,
  0x0A,
  0x2D,
  0xB4,
  0x00,
  0x00,
  0x00,
  0x00,
  0x49,
  0x45,
  0x4E,
  0x44,
  0xAE,
  0x42,
  0x60,
  0x82,
]);
