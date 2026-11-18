import 'dart:convert';
import 'dart:io';

import 'package:open_authenticator/core/app_unlock/reason.dart';
import 'package:path/path.dart' as path;

/// Generates the polkit policy file and translations as well.
Future<void> main() async {
  stdout.writeln('Reading translations...');
  final List<String> locales = [];
  final List<FileSystemEntity> files = Directory('lib/i18n').listSync();
  for (final FileSystemEntity file in files) {
    if (file is Directory) {
      locales.add(path.basename(file.path));
    }
  }
  final Map<String, Map> translations = {};
  for (final String locale in locales) {
    final File translationFile = File('lib/i18n/$locale/app_unlock.json');
    translations[locale] = jsonDecode(translationFile.readAsStringSync());
  }

  stdout.writeln('Generating polkit policy file...');
  String policyFileContent = '''<?xml version="1.0" encoding="UTF-8"?>
<policyconfig>
''';
  for (final UnlockReason reason in UnlockReason.values) {
    policyFileContent += '''
  <action id="app.openauthenticator.${reason.name}">
    <description gettext-domain="polkit.app.openauthenticator">${translations["en"]!["authenticationRequired"]}</description>
    <message gettext-domain="polkit.app.openauthenticator">${translations["en"]!["localAuthentication(map)"][reason.name]}</message>
    <defaults>
      <allow_any>auth_self</allow_any>
      <allow_inactive>auth_self</allow_inactive>
      <allow_active>auth_self</allow_active>
    </defaults>
  </action>
''';
  }
  policyFileContent += '</policyconfig>';
  for (final String path in ['snap/meta/polkit/polkit.app.openauthenticator.policy']) {
    final File policyFile = File(path);
    policyFile.parent.createSync(recursive: true);
    policyFile.writeAsStringSync(policyFileContent);
    stdout.writeln('Done : ${policyFile.path}.');
  }

  for (final String locale in locales) {
    if (locale == 'en') {
      continue;
    }
    stdout.writeln('Generating $locale translation...');
    String translationFileContent = '''msgid "${translations["en"]!["authenticationRequired"]}"
msgstr "${translations[locale]!["authenticationRequired"]}"
''';
    for (final UnlockReason reason in UnlockReason.values) {
      translationFileContent += '''

msgid "${translations["en"]!["localAuthentication(map)"][reason.name]}"
msgstr "${translations[locale]!["localAuthentication(map)"][reason.name]}"
''';
    }
    final File translationFile = File('snap/meta/polkit/po/$locale.po');
    translationFile.parent.createSync(recursive: true);
    translationFile.writeAsStringSync(translationFileContent);
    stdout.writeln('Done : ${translationFile.path}.');
  }
}
