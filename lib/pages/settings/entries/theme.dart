import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'package:open_authenticator/i18n/translations.g.dart';
import 'package:open_authenticator/model/settings/theme.dart';
import 'package:open_authenticator/pages/settings/entries/widgets.dart';
import 'package:open_authenticator/widgets/button_text.dart';
import 'package:open_authenticator/widgets/clickable.dart';
import 'package:open_authenticator/widgets/dialog/app_dialog.dart';

/// Allows to configure [themeSettingsEntryProvider].
class ThemeSettingsEntryWidget extends ConsumerWidget with FTileMixin {
  /// Creates a new theme settings entry widget instance.
  const ThemeSettingsEntryWidget({
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    AsyncValue<ThemeMode> theme = ref.watch(themeSettingsEntryProvider);
    return ClickableTile(
      enabled: theme.hasValue,
      title: Text(translations.settings.application.theme.title),
      subtitle: Text(translations.settings.application.theme.subtitle),
      prefix: Icon(theme.value?.icon),
      suffix: const RightChevronSuffix(),
      onPress: () async {
        ThemeMode? themeMode = await _ThemePickerDialog.show(context);
        if (themeMode != null) {
          await ref.read(themeSettingsEntryProvider.notifier).changeValue(themeMode);
        }
      },
    );
  }
}

/// Allows to configure the theme.
class _ThemePickerDialog extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    AsyncValue<ThemeMode> theme = ref.watch(themeSettingsEntryProvider);
    return AppDialog(
      title: Text(translations.settings.application.theme.title),
      actions: [
        ClickableButton(
          variant: .secondary,
          onPress: () => Navigator.pop(context),
          child: ButtonText(MaterialLocalizations.of(context).closeButtonLabel),
        ),
      ],
      children: [
        for (ThemeMode mode in ThemeMode.values)
          ClickableTile(
            prefix: Icon(mode.icon),
            title: Text(translations.settings.application.theme.themePickerDialog.theme.name[mode.name]!),
            subtitle: Text(translations.settings.application.theme.themePickerDialog.theme.description[mode.name]!),
            suffix: theme.value == mode ? const Icon(FIcons.check) : null,
            onPress: () => Navigator.pop(context, mode),
          ),
      ],
    );
  }

  /// Shows a theme selection dialog.
  static Future<ThemeMode?> show(BuildContext context) => showFDialog<ThemeMode>(
    context: context,
    builder: (context, style, animation) => _ThemePickerDialog(),
  );
}

/// Allows to associate an icon with a theme mode.
extension _Icon on ThemeMode? {
  /// Returns the icon associated with the current theme mode.
  IconData get icon {
    switch (this) {
      case null:
      case ThemeMode.system:
        return FIcons.sunMoon;
      case ThemeMode.dark:
        return FIcons.moon;
      case ThemeMode.light:
        return FIcons.sun;
    }
  }
}
