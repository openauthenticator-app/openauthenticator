import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'package:open_authenticator/i18n/translations.g.dart';
import 'package:open_authenticator/model/settings/storage_type.dart';
import 'package:open_authenticator/pages/settings/entries/widgets.dart';
import 'package:open_authenticator/utils/master_password.dart';
import 'package:open_authenticator/widgets/clickable.dart';

/// Allows to change the user master password.
class ChangeMasterPasswordSettingsEntryWidget extends ConsumerWidget with FTileMixin {
  /// Creates a new change master password settings entry widget instance.
  const ChangeMasterPasswordSettingsEntryWidget({
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    AsyncValue<StorageType> storageType = ref.watch(storageTypeSettingsEntryProvider);
    return ClickableTile(
      prefix: const Icon(FIcons.rectangleEllipsis),
      title: Text(translations.settings.security.changeMasterPassword.title),
      subtitle: Text.rich(
        TextSpan(
          text: translations.settings.security.changeMasterPassword.subtitle.text,
          children: [
            if (storageType.value == StorageType.shared)
              TextSpan(
                text: translations.settings.security.changeMasterPassword.subtitle.sync,
                style: const TextStyle(fontStyle: FontStyle.italic),
              ),
          ],
        ),
      ),
      onPress: () => MasterPasswordUtils.changeMasterPassword(context, ref),
      suffix: const RightChevronSuffix(),
    );
  }
}
