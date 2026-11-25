import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';
// Used only by the headless store image encoder.
// ignore: depend_on_referenced_packages
import 'package:image/image.dart' as img;
import 'package:jovial_svg/jovial_svg.dart';
import 'package:open_authenticator/utils/platform.dart' as app;

import 'campaign.dart';

/// Loads the same typefaces and icon glyphs the app bundles for release.
Future<void> loadFonts() async {
  final manifest = jsonDecode(await rootBundle.loadString('FontManifest.json')) as List;
  for (final Map<String, dynamic> family in manifest.cast<Map<String, dynamic>>()) {
    final loader = FontLoader(family['family'] as String);
    for (final Map<String, dynamic> font in (family['fonts'] as List).cast<Map<String, dynamic>>()) {
      loader.addFont(rootBundle.load(font['asset'] as String));
    }
    await loader.load();
  }
}

/// Registers the original campaign faces only in the compositor.
Future<void> loadPosterFonts() async {
  const files = {
    'Outfit': 'Outfit.ttf',
    'DM Serif Display': 'DMSerifDisplay-Italic.ttf',
    'DM Mono': 'DMMono-Regular.ttf',
  };
  for (final MapEntry<String, String> entry in files.entries) {
    final File file = File('bin/screenshots/assets/${entry.value}');
    final loader = FontLoader(entry.key)..addFont(file.readAsBytes().then(ByteData.sublistView));
    await loader.load();
  }
}

/// Finishes encoding before replacing an existing output.
Future<void> writePng(File file, ui.Image image) async {
  final ByteData? bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  if (bytes == null) {
    throw StateError('PNG encoding failed for ${file.path}');
  }
  writeOutput(file, bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes));
}

// Store artwork is painted on an opaque background. Encode it as RGB so that
// the delivered file has no alpha channel, even on engines that default to RGBA.
Future<void> _writeStorePng(File file, ui.Image image) async {
  final ByteData? data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  if (data == null) {
    throw StateError('Could not read pixels for ${file.path}');
  }
  final Uint8List rgba = Uint8List.sublistView(data);
  final rgb = img.Image(width: image.width, height: image.height, numChannels: 3);
  final Uint8List pixels = rgb.toUint8List();
  for (int src = 0, dst = 0; src < rgba.length; src += 4, dst += 3) {
    pixels[dst] = rgba[src];
    pixels[dst + 1] = rgba[src + 1];
    pixels[dst + 2] = rgba[src + 2];
  }
  writeOutput(file, img.encodePng(rgb, filter: img.PngFilter.sub));
}

/// Replaces each complete file atomically, including the last successful gallery.
void writeOutput(File file, List<int> bytes) {
  file.parent.createSync(recursive: true);
  final temporary = File('${file.path}.$pid.tmp');
  try {
    temporary.writeAsBytesSync(bytes);
    temporary.renameSync(file.path);
  } finally {
    if (temporary.existsSync()) {
      temporary.deleteSync();
    }
  }
}

Future<ui.Image> _readCapture(Directory output, Capture capture, double ratio) async {
  final file = File('${output.path}/${capturePath(capture)}');
  if (!file.existsSync()) {
    throw StateError('Missing ${file.path}. Generate raw captures first.');
  }
  final ui.Codec codec = await ui.instantiateImageCodec(file.readAsBytesSync());
  try {
    final ui.Image image = (await codec.getNextFrame()).image;
    final ui.Size size = capture.device.size * ratio;
    if (image.width != size.width.ceil() || image.height != size.height.ceil()) {
      image.dispose();
      throw StateError('Dimensions changed for ${file.path}. Recapture with the current configuration.');
    }
    return image;
  } finally {
    codec.dispose();
  }
}

/// Paints the poster at its final resolution. The captured page is independent
/// of the store canvas and may extend beyond its top or bottom edge.
Future<void> compose(Directory output, Poster poster, double ratio, ScalableImage logo) async {
  final Capture? capture = poster.screen;
  final ui.Image? screen = capture == null ? null : await _readCapture(output, capture, ratio);
  final recorder = ui.PictureRecorder();
  try {
    final canvas = Canvas(recorder);
    final Size size = poster.size;
    _background(canvas, poster, size);
    _paintLayout(canvas, poster, screen, logo);
    final ui.Picture picture = recorder.endRecording();
    try {
      final ui.Image image = await picture.toImage(size.width.toInt(), size.height.toInt());
      try {
        await _writeStorePng(File('${output.path}/${poster.path}'), image);
      } finally {
        image.dispose();
      }
    } finally {
      picture.dispose();
    }
  } finally {
    if (recorder.isRecording) {
      recorder.endRecording().dispose();
    }
    screen?.dispose();
  }
}

void _background(Canvas canvas, Poster poster, Size size) {
  final bool portrait = size.height > size.width;
  final bool phone = size.aspectRatio < .6;
  final bool tablet = poster.screen?.device.platform.isMobile == true && !portrait;
  // Radius on each axis at half intensity, measured on the PSD glow layers.
  final (Offset defaultCenter, Size defaultRadius) = switch (poster.layout) {
    Layout.brand => (
      const Offset(.5, .49),
      phone
          ? const Size(.28, .13)
          : portrait
          ? const Size(.21, .16)
          : const Size(.15, .24),
    ),
    Layout.accounts when tablet => (const Offset(.50, .77), const Size(.39, .47)),
    Layout.accounts => (Offset(.5, portrait ? .75 : .98), Size(.62, portrait ? .39 : .51)),
    Layout.setup => (Offset(.5, portrait ? .28 : .08), Size(.64, portrait ? .32 : .42)),
    Layout.sync when portrait => (Offset(phone ? .78 : .67, .61), Size(phone ? .52 : .45, .26)),
    Layout.sync => (const Offset(.20, .50), const Size(.24, .55)),
    Layout.download => (const Offset(.5, .5), const Size(.28, .22)),
    Layout.banner => (const Offset(.51, 1.07), const Size(.37, .65)),
  };
  final Color outer = poster.style.background;
  final Color inner = poster.style.glow;
  final Offset center = poster.style.glowCenter ?? defaultCenter;
  final Size halfRadius = poster.style.glowRadius ?? defaultRadius;
  final double peak = switch (poster.layout) {
    Layout.brand when phone => .81,
    Layout.sync when !portrait => .59,
    _ => 1,
  };
  final Rect bounds = Offset.zero & size;
  canvas.drawRect(bounds, Paint()..color = outer);
  canvas.save();
  canvas.translate(size.width * center.dx, size.height * center.dy);
  canvas.scale(size.width * halfRadius.width, size.height * halfRadius.height);
  // Sample the soft falloff instead of interpolating a single linear ramp.
  const int steps = 24;
  final colors = <Color>[
    for (int i = 0; i < steps; i++) Color.lerp(outer, inner, peak * math.pow(.5, math.pow(3 * i / steps, 2.15)))!,
    outer,
  ];
  final stops = <double>[for (int i = 0; i <= steps; i++) i / steps];
  canvas.drawCircle(Offset.zero, 3, Paint()..shader = ui.Gradient.radial(Offset.zero, 3, colors, stops));
  canvas.restore();
}

void _paintLayout(Canvas canvas, Poster poster, ui.Image? screen, ScalableImage logo) {
  final double w = poster.size.width;
  final double h = poster.size.height;
  final bool portrait = h > w;
  final bool phone = w / h < .6;
  Rect pixels(Rect rect) => Rect.fromLTRB(rect.left * w, rect.top * h, rect.right * w, rect.bottom * h);
  Rect box(Rect? custom, double left, double top, double width, double height) => pixels(custom ?? Rect.fromLTWH(left, top, width, height));
  final Rect? art = poster.artworkBox;
  final Rect? caption = poster.captionBox;
  final app.Platform? platform = poster.screen?.device.platform;
  final bool tablet = !portrait && platform?.isMobile == true;
  Rect textBox;
  switch (poster.layout) {
    case Layout.brand:
      final Rect mark = box(art, .30, .49 - (portrait ? .072 : .108), .40, portrait ? .144 : .216);
      _logo(canvas, logo, mark.center, mark.shortestSide);
      final Rect name = box(caption, .05, portrait ? .09 : .035, .90, portrait ? .235 : .22);
      final Rect tagline = box(poster.subtitleBox, phone ? .035 : .075, .645, phone ? .93 : .85, .29);
      _caption(canvas, poster, name, titleOnly: true);
      _caption(canvas, poster, tagline, subtitleOnly: true);
      return;
    case Layout.accounts:
      final double textHeight = portrait ? .242 : (tablet ? .30 : .21);
      textBox = box(caption, .045, portrait ? .035 : .018, .91, textHeight);
      final double deviceTop = tablet ? .35 : (phone ? .33 : .28);
      final Rect stage = portrait || tablet ? box(art, tablet ? .06 : .09, deviceTop, tablet ? .88 : .82, 1 - deviceTop) : box(art, .10, .26, .80, .675);
      _frame(canvas, screen!, platform!, stage, align: Alignment.topCenter, fit: art == null && (portrait || tablet) ? BoxFit.fitWidth : BoxFit.contain);
    case Layout.setup:
      textBox = box(caption, .045, portrait ? .685 : .754, .91, portrait ? .265 : .215);
      final double inset = phone ? .14 : .11;
      final Rect stage = portrait ? box(art, inset, 0, 1 - 2 * inset, .65) : box(art, .10, .043, .80, .676);
      _frame(canvas, screen!, platform!, stage, align: Alignment.bottomCenter, fit: art == null && portrait ? BoxFit.fitWidth : BoxFit.contain);
    case Layout.sync:
      textBox = portrait ? box(caption, .05, .043, .90, .234) : box(caption, .355, .24, .62, .52);
      // A Mac can enter from the right with its traffic lights still in view.
      // Show the whole companion when its window controls are on the right.
      final bool cropMac = portrait && platform == app.Platform.macOS && art == null;
      final Rect stage;
      if (cropMac) {
        // Keep the centered app title fully beyond the phone poster's right edge.
        stage = box(null, phone ? .325 : .18, .325, .82, .555);
      } else if (portrait) {
        stage = box(art, .055, .32, .89, .56);
      } else {
        stage = box(art, .035, .043, .28, .906);
      }
      _frame(canvas, screen!, platform!, stage, align: cropMac ? Alignment.centerLeft : Alignment.center, fit: cropMac ? BoxFit.fitHeight : BoxFit.contain);
    case Layout.download:
      textBox = box(caption, .035, .28, .93, .40);
    case Layout.banner:
      final Rect mark = box(art, .10, .36, .14, .28);
      _logo(canvas, logo, mark.center, mark.shortestSide);
      textBox = box(caption, .28, .30, .69, .43);
  }
  _caption(canvas, poster, textBox);
}

void _logo(Canvas canvas, ScalableImage logo, Offset center, double diameter) {
  canvas.save();
  canvas.translate(center.dx - diameter / 2, center.dy - diameter / 2);
  canvas.scale(diameter / logo.viewport.width);
  canvas.translate(-logo.viewport.left, -logo.viewport.top);
  logo.paint(canvas);
  canvas.restore();
}

void _frame(Canvas canvas, ui.Image image, app.Platform platform, Rect area, {Alignment align = Alignment.center, BoxFit fit = BoxFit.contain}) {
  final source = Size(image.width.toDouble(), image.height.toDouble());
  final Size output = switch (fit) {
    BoxFit.fitWidth => Size(area.width, area.width / source.aspectRatio),
    BoxFit.fitHeight => Size(area.height * source.aspectRatio, area.height),
    _ => applyBoxFit(BoxFit.contain, source, area.size).destination,
  };
  final Rect rect = align.inscribe(output, area);
  final double radius = switch (platform) {
    app.Platform.iOS || app.Platform.android => rect.shortestSide * (source.aspectRatio < .65 ? .085 : .045),
    app.Platform.macOS => rect.shortestSide * .012,
    _ => 0,
  };
  final frame = RRect.fromRectAndRadius(rect, Radius.circular(radius));
  final RRect outer = platform.isMobile ? frame.inflate(rect.shortestSide * .017) : frame;
  canvas.drawShadow(Path()..addRRect(outer), const Color(0xBB05110C), 12, false);
  if (platform.isMobile) {
    canvas.drawRRect(outer.inflate(1), Paint()..color = const Color(0xFFA8B9AE));
    canvas.drawRRect(outer, Paint()..color = const Color(0xFF18251F));
  }
  canvas.save();
  canvas.clipRRect(frame);
  canvas.drawImageRect(image, Offset.zero & source, rect, Paint()..filterQuality = FilterQuality.high);
  canvas.restore();
}

// Markup travels with the translations, so punctuation and word order retain
// their meaning when a language puts emphasis elsewhere in the sentence.
TextSpan _richText(String text, TextStyle base, Color accent) {
  final parts = <InlineSpan>[];
  int start = 0;
  for (final RegExpMatch match in RegExp(r'\*\*([^*]+)\*\*|\*([^*]+)\*').allMatches(text)) {
    if (start < match.start) {
      parts.add(TextSpan(text: text.substring(start, match.start)));
    }
    final bool bold = match[1] != null;
    parts.add(
      TextSpan(
        text: bold ? match[1] : match[2],
        style: bold
            ? const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontVariations: [ui.FontVariation('wght', 700)])
            : TextStyle(fontFamily: 'DM Serif Display', fontStyle: FontStyle.italic, color: accent),
      ),
    );
    start = match.end;
  }
  parts.add(TextSpan(text: text.substring(start)));
  return TextSpan(style: base, children: parts);
}

void _caption(Canvas canvas, Poster poster, Rect box, {bool titleOnly = false, bool subtitleOnly = false}) {
  final double h = poster.size.height;
  final bool portrait = h > poster.size.width;
  final bool brand = poster.layout == Layout.brand;
  final bool banner = poster.layout == Layout.banner;
  final TextAlign align = banner ? TextAlign.left : TextAlign.center;
  final double headline =
      h *
      (banner
          ? .14
          : brand
          ? (portrait ? .055 : .0833)
          : (portrait ? .0365 : .0556));
  final double detail =
      h *
      (banner
          ? .058
          : brand
          ? (portrait ? .0365 : .0556)
          : (portrait ? .0219 : .0333));
  final Style style = poster.style;
  TextPainter line(String text, TextStyle base) => TextPainter(
    text: _richText(text, base, style.accent),
    textDirection: TextDirection.ltr,
    textAlign: align,
  )..layout(minWidth: box.width, maxWidth: text.contains('\n') ? double.infinity : box.width);
  final lines = <TextPainter>[];
  if (!subtitleOnly) {
    lines.add(
      line(
        poster.title,
        TextStyle(
          fontFamily: 'Outfit',
          fontSize: headline * style.titleScale,
          color: style.title,
          fontVariations: [ui.FontVariation('wght', brand ? 500 : 400)],
          height: brand ? 1 : 1.22,
        ),
      ),
    );
  }
  if (!titleOnly) {
    final TextPainter sub = line(
      poster.subtitle,
      TextStyle(
        fontFamily: brand ? 'Outfit' : 'DM Mono',
        fontSize: detail * style.subtitleScale,
        color: brand ? style.title : style.subtitle,
        height: brand ? 1.30 : 1.45,
      ),
    );
    if (poster.layout == Layout.download) {
      lines.insert(0, sub);
    } else {
      lines.add(sub);
    }
  }
  final double gap = headline * (banner ? .02 : .16);
  final double height = lines.fold<double>(0, (sum, line) => sum + line.height) + gap * (lines.length - 1);
  final double width = lines.fold<double>(box.width, (maxWidth, line) => math.max(maxWidth, line.width));
  final double fit = math.min(box.width / width, box.height / height);
  canvas.save();
  canvas.translate(banner ? box.left : box.center.dx, box.center.dy - fit * height / 2);
  canvas.scale(fit);
  double top = 0;
  for (final line in lines) {
    line.paint(canvas, Offset(banner ? 0 : -line.width / 2, top));
    top += line.height + gap;
    line.dispose();
  }
  canvas.restore();
}
