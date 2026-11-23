import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';

/// Generates the localized store campaign from the repository root.
Future<void> main(List<String> arguments) async {
  final ArgParser parser = ArgParser()
    ..addOption('config', defaultsTo: 'bin/screenshots/config.json', help: 'Campaign JSON file.')
    ..addOption('output', defaultsTo: 'build/screenshots', help: 'Destination directory.')
    ..addOption('locale', help: 'Generate one configured language.')
    ..addOption('format', help: 'Generate one configured store/device format.')
    ..addOption('scene', help: 'Generate one configured scene.')
    ..addOption('theme', allowed: ['light', 'dark'], help: 'Override the configured interface theme.')
    ..addFlag('capture-only', negatable: false, help: 'Only generate the raw application screens.')
    ..addFlag('compose-only', negatable: false, help: 'Reuse the raw screens already in the output directory.')
    ..addFlag('help', abbr: 'h', negatable: false, help: 'Show this help.');
  try {
    final ArgResults args = parser.parse(arguments);
    if (args.flag('help')) {
      stdout.writeln('dart run open_authenticator:screenshots [options]\n${parser.usage}');
      return;
    }
    if (args.rest.isNotEmpty || (args.flag('capture-only') && args.flag('compose-only'))) {
      throw const FormatException('Unexpected arguments or conflicting generation modes. See --help.');
    }
    final String? sdk = Platform.environment['FLUTTER_ROOT'];
    final String flutter = sdk == null ? 'flutter' : '$sdk/bin/flutter${Platform.isWindows ? '.bat' : ''}';
    final Process worker = await Process.start(
      flutter,
      ['test', '--no-pub', '--reporter', 'expanded', '--timeout', '20m', 'bin/screenshots/generate.dart'],
      mode: ProcessStartMode.inheritStdio,
      runInShell: Platform.isWindows,
      environment: {
        'OA_SCREENSHOTS': jsonEncode({
          for (final String option in parser.options.keys) option: args[option],
        }),
      },
    );
    exitCode = await worker.exitCode;
    if (exitCode == 0) {
      stdout.writeln('Screenshots: ${Directory(args.option('output')!).absolute.path}');
    }
  } on Exception catch (error) {
    stderr.writeln(error);
    exitCode = 1;
  }
}
