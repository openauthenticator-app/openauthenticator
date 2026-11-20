import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:open_authenticator/core/backup/backup.dart';
import 'package:open_authenticator/i18n/translations.g.dart';
import 'package:open_authenticator/pages/settings/entries/widgets.dart';
import 'package:open_authenticator/utils/platform.dart';
import 'package:open_authenticator/utils/result/handler.dart';
import 'package:open_authenticator/utils/result/result.dart';
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
    final AsyncValue<List<BackupPath>> backups = ref.watch(backupStoreProvider);
    final int backupCount = backups.value?.length ?? 0;
    return ClickableTile(
      suffix: const RightChevronSuffix(),
      prefix: const Icon(FLucideIcons.clock),
      title: Text(translations.settings.backups.manageBackups.title),
      subtitle: Text.rich(
        backupCount == 0
            ? TextSpan(
                text: translations.settings.backups.manageBackups.subtitle.zero,
              )
            : (backupCount == 1 ? translations.settings.backups.manageBackups.subtitle.one : translations.settings.backups.manageBackups.subtitle.more)(
                backups: TextSpan(
                  text: backupCount.toString(),
                  style: const TextStyle(fontStyle: .italic),
                ),
              ),
      ),
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
  /// Lists the available backups and the actions for each file.
  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<BackupPath>> backups = ref.watch(backupStoreProvider);
    List<Widget> children;
    switch (backups) {
      case AsyncData(:final value):
        children = [
          if (value.isEmpty)
            Text(
              translations.settings.backups.manageBackups.subtitle.zero,
              textAlign: TextAlign.center,
              style: const TextStyle(fontStyle: .italic),
            ),
          for (final BackupPath backup in value)
            ExpandableTile(
              key: ValueKey(backup.path),
              title: Text(
                '${DateFormat.yMd(translations.$meta.locale.underscoreTag).format(backup.timestamp)} ${DateFormat.Hms(translations.$meta.locale.underscoreTag).format(backup.timestamp)}',
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
  List<Widget> createBackupActions(BackupPath backup) => [
    ClickableButton(
      variant: .secondary,
      onPress: () => restoreBackup(backup),
      prefix: const Icon(FLucideIcons.upload),
      child: ButtonText(translations.settings.backups.manageBackups.button.restore),
    ),
    if (currentPlatform != .linux)
      Builder(
        builder: (buttonContext) => ClickableButton(
          variant: .secondary,
          onPress: () => shareBackup(buttonContext, backup),
          prefix: const Icon(FLucideIcons.share),
          child: ButtonText(translations.settings.backups.manageBackups.button.share),
        ),
      ),
    ClickableButton(
      variant: .secondary,
      onPress: () => exportBackup(backup),
      prefix: const Icon(FLucideIcons.arrowUpDown),
      child: ButtonText(translations.settings.backups.manageBackups.button.export),
    ),
    ClickableButton(
      variant: .destructive,
      onPress: () => deleteBackup(backup),
      prefix: const Icon(FLucideIcons.trash),
      child: ButtonText(translations.settings.backups.manageBackups.button.delete),
    ),
  ];

  /// Allows to import a backup.
  Future<void> importBackup() async {
    Result result = const ResultCancelled();
    try {
      final List<PlatformFile>? files = await showWaitingOverlay(
        context,
        future: (() async {
          final Directory directory = await BackupPath.getBackupsDirectory();
          return FilePicker.pickFiles(
            dialogTitle: translations.settings.backups.manageBackups.importBackupDialogTitle,
            initialDirectory: await directory.exists() ? directory.path : null,
            type: FileType.custom,
            allowedExtensions: ['bak'],
            windowsOptions: const WindowsOptions(lockParentWindow: true),
            linuxOptions: const LinuxOptions(lockParentWindow: true),
          );
        })(),
      );
      final String? backupFilePath = files?.firstOrNull?.path;
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
        handleResult(context, result);
      }
    }
  }

  /// Asks the user for the given [backup] restoring.
  Future<void> restoreBackup(BackupPath backup) async {
    final String? password = await TextInputDialog.prompt(
      context,
      title: translations.settings.backups.manageBackups.restoreBackupPasswordDialog.title,
      message: translations.settings.backups.manageBackups.restoreBackupPasswordDialog.message,
      password: true,
    );
    if (password == null || !mounted) {
      return;
    }
    final Result result = await showWaitingOverlay(
      context,
      future: ref.read(backupStoreProvider.notifier).restoreBackup(backup, password),
    );
    if (mounted) {
      handleResult(
        context,
        result,
        presentation: result is ResultError && result.exception is InvalidBackupPasswordException ? .successAndErrorToast : .successAndErrorDialog,
      );
      if (result is ResultSuccess) {
        Navigator.pop(context);
      }
    }
  }

  /// Asks the user for the given [backup] share.
  Future<void> shareBackup(BuildContext buttonContext, BackupPath backup) async {
    final box = buttonContext.findRenderObject() as RenderBox;
    try {
      await SharePlus.instance.share(
        ShareParams(
          subject: translations.settings.backups.manageBackups.shareBackupDialog.subject,
          text: translations.settings.backups.manageBackups.shareBackupDialog.text,
          sharePositionOrigin: box.localToGlobal(Offset.zero) & box.size,
          files: [
            XFile(
              backup.path,
              mimeType: 'application/json',
            ),
          ],
        ),
      );
    } catch (ex, stackTrace) {
      if (mounted) {
        handleResult(context, ResultError(exception: ex, stackTrace: stackTrace));
      }
    }
  }

  /// Asks the user for the given [backup] export.
  Future<void> exportBackup(BackupPath backup) async {
    Result result = const ResultCancelled();
    try {
      final Uri? outputFilePath = await showWaitingOverlay(
        context,
        future: (() async => FilePicker.saveFile(
          dialogTitle: translations.settings.backups.manageBackups.exportBackupDialogTitle,
          initialDirectory: backup.file.parent.path,
          fileName: backup.filename,
          bytes: await backup.file.readAsBytes(),
          windowsOptions: const WindowsOptions(lockParentWindow: true),
          linuxOptions: const LinuxOptions(lockParentWindow: true),
        ))(),
      );
      if (outputFilePath == null) {
        return;
      }
      result = const ResultSuccess();
    } catch (ex, stackTrace) {
      result = ResultError(exception: ex, stackTrace: stackTrace);
    } finally {
      if (mounted) {
        handleResult(context, result);
      }
    }
  }

  /// Asks the user for the given [backup] deletion.
  Future<void> deleteBackup(BackupPath backup) async {
    final bool result = await ConfirmationDialog.ask(
      context,
      title: translations.settings.backups.manageBackups.deleteBackupConfirmationDialog.title,
      message: translations.settings.backups.manageBackups.deleteBackupConfirmationDialog.message,
      okButtonVariant: .destructive,
    );
    if (!result) {
      return;
    }
    final Result deleteResult = await ref.read(backupStoreProvider.notifier).deleteBackup(backup);
    if (mounted) {
      handleResult(context, deleteResult);
    }
  }
}
