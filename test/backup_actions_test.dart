import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:open_authenticator/core/backup/backup.dart';
import 'package:open_authenticator/i18n/translations.g.dart';
import 'package:open_authenticator/pages/settings/entries/manage_backups.dart';
import 'package:open_authenticator/themes.dart';
import 'package:open_authenticator/widgets/clickable.dart';
import 'package:open_authenticator/widgets/expandable_tile.dart';

/// Captures bytes passed to a system document picker.
class _DocumentPicker extends FilePickerPlatform {
  /// The payload handed to the selected document provider.
  late final payload = Completer<Uint8List>.sync();

  /// Simulates saving to a document URI without a filesystem path.
  @override
  Future<Uri?> saveFile({
    required String fileName,
    required Uint8List bytes,
    required String mimeType,
    String? dialogTitle,
    String? initialDirectory,
    Function(FilePickerStatus)? onFileSaving,
    WindowsOptions windowsOptions = const WindowsOptions(),
    LinuxOptions linuxOptions = const LinuxOptions(),
    WebOptions webOptions = const WebOptions(),
  }) async {
    payload.complete(bytes);
    return Uri.parse('content://test.documents/export');
  }
}

/// Checks file export and the rectangle passed to the native share sheet.
void main() {
  testWidgets('backup actions export the original bytes and anchor sharing to the selected button', (tester) async {
    final Directory directory = Directory.systemTemp.createTempSync('backup-actions-');
    addTearDown(() => directory.deleteSync(recursive: true));
    final file = File('${directory.path}/1700000000000.bak')..writeAsStringSync('encrypted backup fixture');
    final BackupPath backup = BackupPath.fromPath(path: file.path)!;
    final FilePickerPlatform originalPicker = FilePickerPlatform.instance;
    final picker = _DocumentPicker();
    FilePickerPlatform.instance = picker;
    addTearDown(() => FilePickerPlatform.instance = originalPicker);
    const channel = MethodChannel('dev.fluttercommunity.plus/share');
    Rect? origin;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
      final arguments = call.arguments as Map;
      origin = Rect.fromLTWH(arguments['originX'], arguments['originY'], arguments['originWidth'], arguments['originHeight']);
      return 'fixture';
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          backupStoreProvider.overrideWithBuild((ref, notifier) => [backup]),
        ],
        child: MaterialApp(
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          builder: (context, child) => FTheme(
            data: greenTheme.light.touch,
            child: FToaster(child: child!),
          ),
          home: const Scaffold(body: ManageBackupSettingsEntryWidget()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(translations.settings.backups.manageBackups.title));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: find.byType(ExpandableTile), matching: find.byIcon(FLucideIcons.chevronRight)));
    await tester.pumpAndSettle();
    final Finder share = find.text(translations.settings.backups.manageBackups.button.share);
    final Offset buttonCenter = tester.getCenter(share);
    await tester.tap(share);
    await tester.pumpAndSettle();
    expect(origin, isNotNull);
    expect(origin!.contains(buttonCenter), isTrue);
    final Finder export = find.text(translations.settings.backups.manageBackups.button.export);
    await tester.ensureVisible(export);
    final ClickableButton button = tester.widget(find.ancestor(of: export, matching: find.byType(ClickableButton)));
    final Uint8List? payload = await tester.runAsync(() {
      final Future<Uint8List> exported = picker.payload.future;
      button.onPress!();
      return exported.timeout(const Duration(seconds: 5));
    });
    expect(payload, file.readAsBytesSync());
    await tester.pumpAndSettle();
    expect(find.text(translations.error.noError), findsOneWidget);
  });
}
