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
