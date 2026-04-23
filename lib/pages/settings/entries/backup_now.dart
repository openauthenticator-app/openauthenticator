import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'package:open_authenticator/i18n/translations.g.dart';
import 'package:open_authenticator/model/backup.dart';
import 'package:open_authenticator/utils/result.dart';
import 'package:open_authenticator/widgets/clickable.dart';
import 'package:open_authenticator/widgets/dialog/text_input_dialog.dart';
import 'package:open_authenticator/widgets/waiting_overlay.dart';

/// Allows the user to backup everything now.
class BackupNowSettingsEntryWidget extends ConsumerWidget with FTileMixin {
  /// Creates a new backup now settings entry widget instance.
  const BackupNowSettingsEntryWidget({
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) => ClickableTile(
    prefix: const Icon(FIcons.save),
    title: Text(translations.settings.backups.backupNow.title),
    subtitle: Text(translations.settings.backups.backupNow.subtitle),
    onPress: () async {
      String? password = await TextInputDialog.prompt(
        context,
        title: translations.settings.backups.backupNow.passwordDialog.title,
        message: translations.settings.backups.backupNow.passwordDialog.message,
        password: true,
      );
      if (password == null || !context.mounted) {
        return;
      }
      Result<Backup> result = await showWaitingOverlay(
        context,
        future: ref.read(backupStoreProvider.notifier).doBackup(password),
      );
      if (context.mounted) {
        context.handleResult(result);
      }
    },
  );
}
