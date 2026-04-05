import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'package:intl/intl.dart';
import 'package:open_authenticator/i18n/translations.g.dart';
import 'package:open_authenticator/model/backup.dart';
import 'package:open_authenticator/pages/settings/entries/widgets.dart';
import 'package:open_authenticator/utils/platform.dart';
import 'package:open_authenticator/utils/result.dart';
import 'package:open_authenticator/widgets/button_text.dart';
import 'package:open_authenticator/widgets/centered_circular_progress_indicator.dart';
import 'package:open_authenticator/widgets/clickable.dart';
import 'package:open_authenticator/widgets/dialog/app_dialog.dart';
import 'package:open_authenticator/widgets/dialog/confirmation_dialog.dart';
import 'package:open_authenticator/widgets/dialog/text_input_dialog.dart';
import 'package:open_authenticator/widgets/expandable_tile.dart';
import 'package:open_authenticator/widgets/waiting_overlay.dart';
import 'package:share_plus/share_plus.dart';

/// Allows the user to restore a backup.
class ManageBackupSettingsEntryWidget extends ConsumerWidget with FTileMixin {
  /// Creates a new manage backup settings entry widget instance.
  const ManageBackupSettingsEntryWidget({
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    AsyncValue<List<Backup>> backups = ref.watch(backupStoreProvider);
    int backupCount = backups.value?.length ?? 0;
    return ClickableTile(
      suffix: const RightChevronSuffix(),
      prefix: const Icon(FIcons.clock),
      title: Text(translations.settings.backups.manageBackups.title),
      subtitle: Text(translations.settings.backups.manageBackups.subtitle(n: backupCount)),
      enabled: backups.hasValue,
      onPress: () {
        showFDialog(
          context: context,
          builder: (context, style, animation) => _RestoreBackupDialog(),
        );
      },
    );
  }
}

/// The dialog that allows to restore a backup.
class _RestoreBackupDialog extends ConsumerStatefulWidget {
  @override
  ConsumerState<ConsumerStatefulWidget> createState() => _RestoreBackupDialogState();
}

/// The restore backup dialog state.
class _RestoreBackupDialogState extends ConsumerState<_RestoreBackupDialog> {
  /// The list global key.
  late GlobalKey shareActionKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    AsyncValue<List<Backup>> backups = ref.watch(backupStoreProvider);
    List<Widget> children;
    switch (backups) {
      case AsyncData(:final value):
        children = [
          if (value.isEmpty)
            Text(
              key: shareActionKey,
              translations.settings.backups.manageBackups.subtitle(n: 0),
              textAlign: TextAlign.center,
              style: const TextStyle(fontStyle: FontStyle.italic),
            ),
          for (Backup backup in value)
            ExpandableTile(
              title: Text(
                '${DateFormat.yMd(translations.$meta.locale.underscoreTag).format(backup.dateTime)} ${DateFormat.Hms(translations.$meta.locale.underscoreTag).format(backup.dateTime)}',
              ),
              children: createBackupActions(backup),
            ),
        ];
        break;
      case AsyncError(:final error):
        children = [
          Center(
            child: Text(translations.error.generic.withException(exception: error)),
          ),
        ];
        break;
      default:
        children = [
          const CenteredCircularProgressIndicator(),
        ];
        break;
    }
    return AppDialog(
      title: Text(translations.settings.backups.manageBackups.backupsDialogTitle),
      actions: [
        ClickableButton(
          variant: .secondary,
          onPress: importBackup,
          child: ButtonText(translations.settings.backups.manageBackups.button.import),
        ),
        ClickableButton(
          variant: .secondary,
          onPress: () => Navigator.pop(context),
          child: ButtonText(MaterialLocalizations.of(context).closeButtonLabel),
        ),
      ],
      children: children,
    );
  }

  /// Creates the buttons to interact with a given [backup].
  List<Widget> createBackupActions(Backup backup) => [
    ClickableButton(
      variant: .secondary,
      onPress: () => restoreBackup(backup),
      prefix: const Icon(FIcons.upload),
      child: ButtonText(translations.settings.backups.manageBackups.button.restore),
    ),
    if (currentPlatform != .linux)
      ClickableButton(
        variant: .secondary,
        onPress: () => shareBackup(backup),
        prefix: const Icon(FIcons.share),
        child: ButtonText(translations.settings.backups.manageBackups.button.share),
      ),
    ClickableButton(
      variant: .secondary,
      onPress: () => exportBackup(backup),
      prefix: const Icon(FIcons.arrowUpDown),
      child: ButtonText(translations.settings.backups.manageBackups.button.export),
    ),
    ClickableButton(
      variant: .destructive,
      onPress: () => deleteBackup(backup),
      prefix: const Icon(FIcons.trash),
      child: ButtonText(translations.settings.backups.manageBackups.button.delete),
    ),
  ];

  /// Allows to import a backup.
  Future<void> importBackup() async {
    Result result = const ResultCancelled();
    try {
      FilePickerResult? filePickerResult = await showWaitingOverlay(
        context,
        future: (() async {
          Directory directory = await BackupStore.getBackupsDirectory(create: true);
          return FilePicker.pickFiles(
            dialogTitle: translations.settings.backups.manageBackups.importBackupDialogTitle,
            initialDirectory: directory.path,
            type: FileType.custom,
            allowedExtensions: ['bak'],
            lockParentWindow: true,
          );
        })(),
      );
      String? backupFilePath = filePickerResult?.files.firstOrNull?.path;
      if (backupFilePath == null || !mounted) {
        return;
      }
      result = await showWaitingOverlay(
        context,
        future: ref.read(backupStoreProvider.notifier).import(File(backupFilePath)),
      );
    } catch (ex, stackTrace) {
      result = ResultError(exception: ex, stackTrace: stackTrace);
    } finally {
      if (mounted) {
        context.handleResult(result);
      }
    }
  }

  /// Asks the user for the given [backup] restoring.
  Future<void> restoreBackup(Backup backup) async {
    String? password = await TextInputDialog.prompt(
      context,
      title: translations.settings.backups.manageBackups.restoreBackupPasswordDialog.title,
      message: translations.settings.backups.manageBackups.restoreBackupPasswordDialog.message,
      password: true,
    );
    if (password == null || !mounted) {
      return;
    }
    Result result = await showWaitingOverlay(
      context,
      future: backup.restore(password),
    );
    if (mounted) {
      context.handleResult(
        result,
        showDialogIfError: (error) => error is! InvalidPasswordException,
      );
      if (result is ResultSuccess) {
        Navigator.pop(context);
      }
    }
  }

  /// Asks the user for the given [backup] share.
  Future<ShareResult> shareBackup(Backup backup) async {
    RenderBox? box = shareActionKey.currentContext?.findRenderObject() as RenderBox?;
    File file = await backup.getBackupPath();
    return await SharePlus.instance.share(
      ShareParams(
        subject: translations.settings.backups.manageBackups.shareBackupDialog.subject,
        text: translations.settings.backups.manageBackups.shareBackupDialog.text,
        sharePositionOrigin: box == null ? Rect.zero : (box.localToGlobal(Offset.zero) & box.size),
        files: [
          XFile(
            file.path,
            mimeType: 'application/json',
          ),
        ],
      ),
    );
  }

  /// Asks the user for the given [backup] export.
  Future<void> exportBackup(Backup backup) async {
    Result result = const ResultCancelled();
    try {
      String? outputFilePath = await showWaitingOverlay(
        context,
        future: (() async {
          Directory directory = await BackupStore.getBackupsDirectory(create: true);
          return FilePicker.saveFile(
            dialogTitle: translations.settings.backups.manageBackups.exportBackupDialogTitle,
            initialDirectory: directory.path,
            fileName: backup.filename,
            bytes: Uint8List(0),
            type: FileType.custom,
            allowedExtensions: ['bak'],
            lockParentWindow: true,
          );
        })(),
      );
      if (outputFilePath == null) {
        return;
      }
      File backupFile = await backup.getBackupPath();
      backupFile.copySync(outputFilePath);
      result = const ResultSuccess();
    } catch (ex, stackTrace) {
      result = ResultError(exception: ex, stackTrace: stackTrace);
    } finally {
      if (mounted) {
        context.handleResult(result);
      }
    }
  }

  /// Asks the user for the given [backup] deletion.
  Future<void> deleteBackup(Backup backup) async {
    bool result = await ConfirmationDialog.ask(
      context,
      title: translations.settings.backups.manageBackups.deleteBackupConfirmationDialog.title,
      message: translations.settings.backups.manageBackups.deleteBackupConfirmationDialog.message,
    );
    if (!result) {
      return;
    }
    Result deleteResult = await backup.delete();
    if (mounted) {
      context.handleResult(deleteResult);
    }
  }
}
