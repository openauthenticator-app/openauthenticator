import 'dart:convert';
import 'dart:ffi' show Abi;
import 'dart:io';

import 'package:args/args.dart';

typedef _Target = ({String description, List<String> hosts, List<String> command});

const _hosts = ['linux', 'macos', 'windows'];
const Map<String, _Target> _targets = {
  'aab': (description: 'Android App Bundle (also: android)', hosts: _hosts, command: ['flutter', 'build', 'appbundle']),
  'apk': (description: 'Android APK', hosts: _hosts, command: ['flutter', 'build', 'apk']),
  'ios': (description: 'iOS application', hosts: ['macos'], command: ['flutter', 'build', 'ios']),
  'ipa': (description: 'iOS archive and IPA export', hosts: ['macos'], command: ['flutter', 'build', 'ipa']),
  'macos': (description: 'macOS application', hosts: ['macos'], command: ['flutter', 'build', 'macos']),
  'windows': (description: 'Windows application', hosts: ['windows'], command: ['flutter', 'build', 'windows']),
  'msix': (description: 'Microsoft Store package', hosts: ['windows'], command: ['dart', 'run', 'msix:create']),
  'linux': (description: 'Linux application bundle', hosts: ['linux'], command: ['flutter', 'build', 'linux']),
  'flatpak': (description: 'Flatpak bundle (x86_64)', hosts: ['linux'], command: ['bash', 'flatpak/build-flutter-app.sh', '--local']),
  'snap': (description: 'Snap package via Docker', hosts: ['linux'], command: ['bash', 'scripts/snap-build.sh']),
};

/// Builds one or more application targets from the repository root.
Future<void> main(List<String> arguments) async {
  final parser = ArgParser()
    ..addFlag('dry-run', negatable: false, help: 'Print the build commands for any host.')
    ..addFlag('list', negatable: false, help: 'List targets and supported build hosts.')
    ..addFlag('help', abbr: 'h', negatable: false, help: 'Show usage and examples.');
  try {
    final int separator = arguments.indexOf('--');
    final ArgResults options = parser.parse(separator < 0 ? arguments : arguments.sublist(0, separator));
    final List<String> extra = separator < 0 ? [] : arguments.sublist(separator + 1);
    if (options.flag('help') || options.flag('list') || arguments.isEmpty) {
      stdout.writeln('dart run open_authenticator:build [options] TARGET... [-- TOOL_OPTIONS...]\n');
      for (final MapEntry<String, _Target> entry in _targets.entries) {
        stdout.writeln('  ${entry.key.padRight(8)} ${entry.value.description.padRight(33)} ${entry.value.hosts.join(', ')}');
      }
      stdout.writeln('\n${parser.usage}\n\nExamples:\n  dart run open_authenticator:build linux aab\n  dart run open_authenticator:build apk -- --debug');
      return;
    }
    final Set<String> names = options.rest.map((name) => name == 'android' ? 'aab' : name).toSet();
    if (names.isEmpty) {
      throw const FormatException('Choose at least one target. Use --list to see the choices.');
    }
    if (extra.isNotEmpty && (names.length != 1 || names.contains('flatpak'))) {
      throw const FormatException('Tool options require a single Flutter, MSIX or Snap target.');
    }
    final bool preview = options.flag('dry-run');
    for (final name in names) {
      final _Target? target = _targets[name];
      if (target == null) {
        throw FormatException('Unknown target "$name". Use --list to see the choices.');
      }
      if (!preview && !target.hosts.contains(Platform.operatingSystem)) {
        throw FormatException('$name requires ${target.hosts.join(' or ')}. This host is ${Platform.operatingSystem}.');
      }
      if (!preview && name == 'flatpak' && Abi.current() != Abi.linuxX64) {
        throw const FormatException('The Flatpak manifest requires an x86_64 Linux host.');
      }
    }
    if (!preview && !File('bin/build.dart').existsSync()) {
      throw const FormatException('Run this command from the Open Authenticator repository root.');
    }
    for (final name in names) {
      final List<String> command = _targets[name]!.command;
      final List<String> args = [...command.skip(1), ...extra];
      if (preview) {
        stdout.writeln([command.first, ...args].map((arg) => arg.contains(RegExp(r'\s')) ? jsonEncode(arg) : arg).join(' '));
        continue;
      }
      stdout.writeln('Building $name…');
      final String? sdk = Platform.environment['FLUTTER_ROOT'];
      final String executable = switch (command.first) {
        'dart' => Platform.resolvedExecutable,
        'flutter' when sdk != null && sdk.isNotEmpty => '$sdk/bin/flutter${Platform.isWindows ? '.bat' : ''}',
        _ => command.first,
      };
      final Process process = await Process.start(executable, args, mode: ProcessStartMode.inheritStdio, runInShell: Platform.isWindows && command.first == 'flutter');
      final int result = await process.exitCode;
      if (result != 0) {
        stderr.writeln('Build failed for $name (exit $result).');
        exitCode = result;
        return;
      }
    }
  } on FormatException catch (error) {
    stderr.writeln(error.message);
    exitCode = 64;
  } on ProcessException catch (error) {
    stderr.writeln('Could not start ${error.executable}: ${error.message}');
    exitCode = 1;
  }
}
