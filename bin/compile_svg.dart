import 'dart:io';

/// Hello world !
void main() {
  _exploreDirectory(Directory('assets/svg'), Directory('assets/images'));
}

/// Explores the given [directory] looking for SVG files.
void _exploreDirectory(Directory directory, Directory destination) {
  for (final FileSystemEntity file in directory.listSync()) {
    if (file is Directory) {
      _exploreDirectory(file, Directory('${destination.path}/${file.name}'));
      continue;
    }
    if (file is File && file.path.endsWith('.svg')) {
      _compileSvg(file, destination);
    }
  }
}

/// Compiles the SVG [file] into a SI file.
void _compileSvg(File file, Directory destination) {
  stdout.writeln('Compiling ${file.path} into ${destination.path}...');
  Process.runSync(
    'dart',
    [
      'run',
      'jovial_svg:svg_to_si',
      file.path,
      '--out',
      destination.path,
    ],
  );
  stdout.writeln('Done.');
}

/// Allows to get a directory name.
extension _Name on Directory {
  /// Returns the directory name.
  String get name {
    final List<String> pathSegments = List.of(uri.pathSegments);
    if (pathSegments.isEmpty) {
      return '';
    }
    while (pathSegments.last.isEmpty) {
      pathSegments.removeLast();
    }
    return pathSegments.isEmpty ? '' : pathSegments.last;
  }
}
