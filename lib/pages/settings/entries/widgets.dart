import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'package:open_authenticator/i18n/translations.g.dart';
import 'package:open_authenticator/model/settings/entry.dart';
import 'package:open_authenticator/widgets/clickable.dart';
import 'package:open_authenticator/widgets/toast.dart';
import 'package:url_launcher/url_launcher.dart';

/// Allows to configure boolean values.
class BoolSettingsEntryWidget<T extends SettingsEntry<bool>> extends CheckboxSettingsEntryWidget<T, bool> with FTileMixin {
  /// Creates a new bool settings entry widget instance.
  const BoolSettingsEntryWidget({
    super.key,
    required super.provider,
    required super.title,
    super.subtitle,
    super.icon,
  });

  @override
  bool isEnabled(bool? value) => value == true;

  @override
  void changeValue(BuildContext context, WidgetRef ref, bool newValue) => ref.read(provider.notifier).changeValue(newValue);
}

/// A settings entry that can be configured using a checkbox.
abstract class CheckboxSettingsEntryWidget<T extends SettingsEntry<U>, U> extends ConsumerWidget with FTileMixin {
  /// The boolean provider.
  final AsyncNotifierProvider<T, U> provider;

  /// The entry widget title.
  final String title;

  /// The entry widget subtitle.
  final String? subtitle;

  /// The icon.
  final IconData? icon;

  /// Creates a new checkbox settings entry widget instance.
  const CheckboxSettingsEntryWidget({
    super.key,
    required this.provider,
    required this.title,
    this.subtitle,
    this.icon,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    AsyncValue<U> value = ref.watch(provider);
    return switch (value) {
      AsyncData(:final value) => createTile(context, ref, value: value),
      AsyncError() => const SizedBox.shrink(),
      _ => createTile(context, ref, enabled: false),
    };
  }

  /// Creates the list tile widget.
  Widget createTile(BuildContext context, WidgetRef ref, {U? value, bool enabled = true}) => ClickableTile(
    prefix: icon == null ? null : Icon(icon),
    title: Text(title),
    subtitle: buildSubtitle(context, ref, value),
    enabled: enabled,
    onPress: () => changeValue(context, ref, !isEnabled(value)),
    suffix: FCheckbox(
      value: isEnabled(value),
      enabled: enabled,
      onChange: enabled ? (value) => changeValue(context, ref, value) : null,
    ),
  );

  /// Whether the checkbox is enabled.
  bool isEnabled(U? value);

  /// Builds the subtitle widget.
  Widget? buildSubtitle(BuildContext context, WidgetRef ref, U? value) => subtitle == null ? null : Text(subtitle!);

  /// Changes the value.
  void changeValue(BuildContext context, WidgetRef ref, bool newValue);
}

/// A settings entry that allows to open a specific URI.
class UriSettingsEntry extends StatelessWidget with FTileMixin {
  /// The entry widget title.
  final String title;

  /// The entry widget subtitle.
  final String? subtitle;

  /// The icon.
  final IconData? icon;

  /// The URI to open.
  final Uri uri;

  /// Creates a new URI settings entry instance.
  const UriSettingsEntry({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    required this.uri,
  });

  @override
  Widget build(BuildContext context) => FutureBuilder(
    future: canLaunchUrl(uri),
    builder: (context, snapshot) => createTile(context, snapshot.data),
  );

  /// Creates the list tile widget.
  Widget createTile(BuildContext context, bool? canLaunchUri) => ClickableTile(
    prefix: Icon(icon),
    title: Text(title),
    subtitle: subtitle == null ? null : Text(subtitle!),
    onPress: canLaunchUri == null
        ? null
        : (() async {
            if (canLaunchUri) {
              await launchUrl(uri);
              return;
            }
            await Clipboard.setData(ClipboardData(text: uri.toString()));
            if (context.mounted) {
              showSuccessToast(context, text: translations.miscellaneous.urlCopiedToClipboard);
            }
          }),
  );
}

/// The right chevron suffix.
class RightChevronSuffix extends StatelessWidget {
  /// Creates a new right chevron suffix instance.
  const RightChevronSuffix({
    super.key,
  });

  @override
  Widget build(BuildContext context) => const Padding(
    padding: .symmetric(horizontal: 8),
    child: Icon(FIcons.chevronRight),
  );
}
