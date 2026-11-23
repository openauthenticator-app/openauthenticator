import 'dart:convert';
import 'dart:io';
import 'dart:ui' show Color, Offset, Rect, Size;

import 'package:open_authenticator/i18n/translations.g.dart';
import 'package:open_authenticator/utils/platform.dart' as app;

/// The visual arrangements supported by the compositor.
enum Layout { brand, accounts, setup, sync, download, banner }

/// A logical application viewport and target platform.
typedef Device = ({String id, app.Platform platform, Size size});

/// Raw captures are shared by every composition that requests the same screen.
typedef Capture = ({Device device, AppLocale locale, bool dark, bool setup});

/// The destination relative to the campaign output directory.
String capturePath(Capture capture) => 'sources/${capture.device.id}/${capture.locale.languageCode}/${capture.dark ? 'dark' : 'light'}/${capture.setup ? 'setup' : 'accounts'}.png';

/// All dimensions and colors for a single export.
typedef Style = ({Color background, Color glow, Offset? glowCenter, Size? glowRadius, Color title, Color subtitle, Color accent, double titleScale, double subtitleScale});

/// One localized store image and its application screen dependencies.
typedef Poster = ({String path, Size size, Layout layout, String title, String subtitle, Capture? screen, Rect? captionBox, Rect? subtitleBox, Rect? artworkBox, Style style});

/// A validated selection, computed before any files are written.
class Campaign {
  /// Raw pixel density.
  final double pixelRatio;

  /// Selected store compositions in configuration order.
  final List<Poster> posters;

  Campaign._(this.pixelRatio, this.posters);

  /// Reads the JSON config and resolves the CLI filters.
  factory Campaign.read(Map<String, dynamic> options) {
    final config = jsonDecode(File(options['config'] as String).readAsStringSync()) as Map<String, dynamic>;
    final devices = <String, Device>{
      for (final entry in _entries(config, 'devices'))
        entry.key: (
          id: entry.key,
          platform: app.Platform.values.where((platform) => platform != app.Platform.web).byName(entry.value['platform'] as String),
          size: _size(entry.value),
        ),
    };
    final Map<String, Map<String, dynamic>> formats = Map.fromEntries(_entries(config, 'formats'));
    final Map<String, Map<String, dynamic>> scenes = Map.fromEntries(_entries(config, 'scenes'));
    final List<String> allLocales = AppLocale.values.map((locale) => locale.languageCode).toList();
    final List<String> locales = _ids(config['locales'] ?? allLocales, 'locales');
    _checkIds(locales, allLocales, 'locale');
    final Iterable<String> selectedLocales = _select(locales, options['locale'] as String?, 'locale');
    final Iterable<String> selectedFormats = _select(formats.keys, options['format'] as String?, 'format');
    final Iterable<String> selectedScenes = _select(scenes.keys, options['scene'] as String?, 'scene');
    final posters = <Poster>[];
    for (final id in selectedFormats) {
      final Map<String, dynamic> format = formats[id]!;
      final Size size = _size(format);
      final String shape = size.aspectRatio < .6
          ? 'phone'
          : size.aspectRatio < 1
          ? 'portrait'
          : 'landscape';
      final List<String> ids = _ids(format['scenes'], '$id.scenes');
      _checkIds(ids, scenes.keys, 'scene in $id');
      final String theme = options['theme'] as String? ?? format['theme'] as String? ?? 'light';
      _checkIds([theme], ['light', 'dark'], 'theme in $id');
      for (final language in selectedLocales) {
        final AppLocale locale = AppLocale.values.firstWhere((value) => value.languageCode == language);
        for (final String sceneId in ids.where(selectedScenes.contains)) {
          final Map<String, dynamic> scene = scenes[sceneId]!;
          final Layout layout = Layout.values.byName(scene['layout'] as String);
          final captions = scene['captions'] as Map<String, dynamic>;
          final translation = (captions[language] ?? captions['*']) as Map<String, dynamic>?;
          final caption = <String, dynamic>{...?translation, ...?translation?[shape] as Map<String, dynamic>?};
          if (caption['title'] is! String || caption['subtitle'] is! String) {
            throw FormatException('Missing title or subtitle for $sceneId/$language.');
          }
          final String? deviceField = switch (layout) {
            Layout.accounts || Layout.setup => 'device',
            Layout.sync => 'companion',
            _ => null,
          };
          Capture? screen;
          if (deviceField != null) {
            final Device? device = devices[format[deviceField]];
            if (device == null) {
              throw FormatException('Invalid $deviceField in $id for $sceneId.');
            }
            screen = (device: device, locale: locale, dark: theme == 'dark', setup: layout == Layout.setup);
          }
          posters.add((
            path: 'store/$id/$language/$theme/$sceneId.png',
            size: size,
            layout: layout,
            title: caption['title'] as String,
            subtitle: caption['subtitle'] as String,
            captionBox: _box(scene['captionBox'] ?? format['captionBox'], 'captionBox'),
            subtitleBox: _box(scene['subtitleBox'] ?? format['subtitleBox'], 'subtitleBox'),
            artworkBox: _box(scene['artworkBox'] ?? format['artworkBox'], 'artworkBox'),
            style: _style({
              ...config['style'] as Map<String, dynamic>,
              ...?format['style'] as Map<String, dynamic>?,
              ...?scene['style'] as Map<String, dynamic>?,
            }),
            screen: screen,
          ));
        }
      }
    }
    if (posters.isEmpty) {
      throw const FormatException('The selected format and scene have no images in common.');
    }
    return Campaign._(_positive(config, 'pixelRatio'), posters);
  }
}

Iterable<MapEntry<String, Map<String, dynamic>>> _entries(Map<String, dynamic> config, String key) {
  final Map<String, Map<String, dynamic>> entries = (config[key] as Map<String, dynamic>).cast<String, Map<String, dynamic>>();
  _ids(entries.keys.toList(), key);
  return entries.entries;
}

List<String> _ids(dynamic input, String name) {
  final List<String> ids = (input as List).cast<String>();
  final id = RegExp(r'^[a-z0-9]+(?:-[a-z0-9]+)*$');
  if (ids.isEmpty || ids.any((value) => !id.hasMatch(value)) || ids.toSet().length != ids.length) {
    throw FormatException('Expected unique lowercase identifiers in $name.');
  }
  return ids;
}

void _checkIds(Iterable<String> ids, Iterable<String> valid, String name) {
  for (final id in ids) {
    if (!valid.contains(id)) {
      throw FormatException('Unknown $name "$id". Choose from ${valid.join(', ')}.');
    }
  }
}

Iterable<String> _select(Iterable<String> ids, String? filter, String name) {
  if (filter == null) {
    return ids;
  }
  _checkIds([filter], ids, name);
  return [filter];
}

double _positive(Map<String, dynamic> values, String key) {
  final Object? value = values[key];
  if (value is! num || !value.isFinite || value <= 0) {
    throw FormatException('Expected a positive number for $key.');
  }
  return value.toDouble();
}

Size _size(Map<String, dynamic> values) {
  if (values['width'] is! int || values['height'] is! int) {
    throw const FormatException('Width and height must be integers.');
  }
  return Size(_positive(values, 'width'), _positive(values, 'height'));
}

Style _style(Map<String, dynamic> values) {
  Color color(String key) {
    final Object? value = values[key];
    if (value is! String || !RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(value)) {
      throw FormatException('Expected #RRGGBB for style.$key.');
    }
    return Color(int.parse('ff${value.substring(1)}', radix: 16));
  }

  Offset? pair(String key, {bool positive = false}) {
    final Object? value = values[key];
    if (value == null) {
      return null;
    }
    if (value case [final num x, final num y] when x.isFinite && y.isFinite && (!positive || x > 0 && y > 0)) {
      return Offset(x.toDouble(), y.toDouble());
    }
    throw FormatException('Expected two ${positive ? 'positive ' : ''}numbers for style.$key.');
  }

  final Offset? radius = pair('glowRadius', positive: true);
  return (
    background: color('background'),
    glow: color('glow'),
    glowCenter: pair('glowCenter'),
    glowRadius: radius == null ? null : Size(radius.dx, radius.dy),
    title: color('title'),
    subtitle: color('subtitle'),
    accent: color('accent'),
    titleScale: _positive(values, 'titleScale'),
    subtitleScale: _positive(values, 'subtitleScale'),
  );
}

Rect? _box(Object? value, String key) {
  if (value == null) {
    return null;
  }
  if (value case [final num x, final num y, final num width, final num height] when x >= 0 && y >= 0 && width > 0 && height > 0 && x + width <= 1 && y + height <= 1) {
    return Rect.fromLTWH(x.toDouble(), y.toDouble(), width.toDouble(), height.toDouble());
  }
  throw FormatException('$key must be [left, top, width, height] within the unit square.');
}
