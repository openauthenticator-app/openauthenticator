import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'package:open_authenticator/pages/intro/page.dart';
import 'package:open_authenticator/widgets/clickable.dart';

/// Allows to show the intro page.
class ShowIntroPageSettingsEntryWidget extends ConsumerWidget with FTileMixin {
  /// Creates a new show intro page settings entry widget instance.
  const ShowIntroPageSettingsEntryWidget({
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) => ClickableTile(
    prefix: const Icon(FIcons.chevronFirst),
    title: const Text('Show intro page'),
    subtitle: const Text('Displays the intro page.'),
    onPress: () async {
      await Navigator.pushNamedAndRemoveUntil(context, IntroPage.name, (_) => false);
    },
  );
}
