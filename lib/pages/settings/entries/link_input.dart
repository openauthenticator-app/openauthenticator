import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'package:open_authenticator/model/app_links/listener.dart';
import 'package:open_authenticator/widgets/clickable.dart';

/// Allows to input a link from the clipboard.
class LinkInputSettingsEntryWidget extends ConsumerWidget with FTileMixin {
  /// Creates a new link input settings entry widget instance.
  const LinkInputSettingsEntryWidget({
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) => ClickableTile(
    prefix: const Icon(FIcons.link),
    title: const Text('Input link'),
    subtitle: const Text('Inputs an openauthenticator:// link from the clipboard.'),
    onPress: () async {
      ClipboardData? clipboardData = await Clipboard.getData('text/plain');
      if (clipboardData == null || clipboardData.text == null) {
        return;
      }
      Uri? uri = Uri.tryParse(clipboardData.text!);
      if (uri == null || uri.scheme != 'openauthenticator') {
        return;
      }
      ref.read(appLinksListenerProvider.notifier).provideLink(uri);
    },
  );
}
