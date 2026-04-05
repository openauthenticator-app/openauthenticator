/// The image type.
enum ImageType {
  /// "SVG" type.
  svg,

  /// "SI" type.
  si,

  /// Any other image.
  other
  ;

  /// Infers an image type from the given [source].
  static ImageType inferFromSource(String source) {
    if (source.endsWith('.svg')) {
      return svg;
    }
    if (source.endsWith('.si')) {
      return si;
    }
    return other;
  }
}
