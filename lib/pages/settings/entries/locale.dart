import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'package:open_authenticator/i18n/translations.g.dart';

/// Allows to change the app locale for debugging purposes.
class LocaleSettingsEntryWidget extends ConsumerWidget with FTileMixin {
  /// Creates a new locale settings entry widget instance.
  const LocaleSettingsEntryWidget({
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) => FSelectMenuTile<AppLocale>.fromMap(
    {
      for (AppLocale locale in AppLocale.values) locale.languageCode: locale,
    },
    selectControl: FMultiValueControl.managedRadio(
      initial: TranslationProvider.of(context).locale,
      onChange: (choices) => LocaleSettings.setLocale(choices.first),
    ),
    prefix: const Icon(FIcons.languages),
    title: const Text('Language'),
    subtitle: const Text('Change the app language.'),
    detailsBuilder: (_, values, _) => Text(values.first.name),
  );
}
