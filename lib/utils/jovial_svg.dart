import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';
// ignore: depend_on_referenced_packages
import 'package:jovial_misc/io_utils.dart';
import 'package:jovial_svg/jovial_svg.dart';
// ignore: implementation_imports
import 'package:jovial_svg/src/compact.dart';
// ignore: implementation_imports
import 'package:jovial_svg/src/compact_noui.dart';
// ignore: implementation_imports
import 'package:jovial_svg/src/svg_parser.dart';
import 'package:open_authenticator/utils/utils.dart';

/// Contains some useful methods to use with `jovial_svg`.
class JovialSvgUtils {
  /// Compiles a SVG string into an SI file.
  static Future<bool> svgToSi(String svg, File destinationFile) async {
    IOSink ioSink = destinationFile.openWrite();
    try {
      DataOutputSink outputSink = DataOutputSink(ioSink, Endian.big);
      SICompactBuilderNoUI siCompactBuilder = SICompactBuilderNoUI(bigFloats: false, warn: (_) {});
      StringSvgParser(svg, [], siCompactBuilder, warn: (_) {}).parse();
      siCompactBuilder.si.writeToFile(outputSink);
      return true;
    } catch (ex, stackTrace) {
      handleException(ex, stackTrace, sendToSentry: false);
    } finally {
      await ioSink.close();
    }
    return false;
  }
}

/// Allows to load a SI image from a file.
class SIFileSource extends ScalableImageSource {
  /// File file.
  final File file;

  /// The current color.
  final Color? currentColor;

  /// Creates a new SI file source instance.
  SIFileSource({
    required this.file,
    this.currentColor,
  });

  @override
  Future<ScalableImage> get si => createSI();

  @override
  Future<ScalableImage> createSI({bool compact = false}) async {
    ScalableImageCompact scalableImageCompact = ScalableImageCompact.fromBytes(file.readAsBytesSync(), currentColor: currentColor);
    if (compact) {
      return scalableImageCompact;
    } else {
      return scalableImageCompact.toDag();
    }
  }

  @override
  bool operator ==(final Object other) {
    if (other is SIFileSource) {
      return file == other.file && currentColor == other.currentColor;
    } else {
      return false;
    }
  }

  @override
  int get hashCode => 0xf67cd716 ^ Object.hash(file, currentColor);

  @override
  String toString() => '__SIFileSource($file $currentColor)';
}
