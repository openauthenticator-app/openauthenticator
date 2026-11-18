import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:open_authenticator/core/app_unlock/local_authentication/local_authentication.dart';
import 'package:open_authenticator/core/app_unlock/methods/method.dart';
import 'package:open_authenticator/core/settings/app_unlock_method.dart';
import 'package:open_authenticator/flows/app_unlock_interaction.dart';
import 'package:open_authenticator/i18n/translations.g.dart';
import 'package:open_authenticator/pages/settings/entries/widgets.dart';
import 'package:open_authenticator/utils/result/handler.dart';
import 'package:open_authenticator/utils/result/result.dart';

/// Allows to configure [enableLocalAuthSettingsEntryProvider].
class EnableLocalAuthSettingsEntryWidget extends CheckboxSettingsEntryWidget<AppUnlockMethodSettingsEntry, String> {
  /// Creates a new enable local auth settings entry widget instance.
  EnableLocalAuthSettingsEntryWidget({
    super.key,
  }) : super(
         provider: appUnlockMethodSettingsEntryProvider,
         title: translations.settings.security.enableLocalAuth.title,
         subtitle: translations.settings.security.enableLocalAuth.subtitle,
         icon: FLucideIcons.lock,
       );

  @override
  Widget build(BuildContext context, WidgetRef ref) => FutureBuilder(
    future: LocalAuthentication.instance.isSupported(),
    builder: (context, snapshot) {
      if (snapshot.data == null) {
        return createTile(context, ref, enabled: false);
      }
      return snapshot.data == true ? super.build(context, ref) : const SizedBox.shrink();
    },
  );

  @override
  Future<void> changeValue(BuildContext context, WidgetRef ref, bool newValue) async {
    final String newMethod = newValue ? LocalAuthenticationAppUnlockMethod.kMethodId : NoneAppUnlockMethod.kMethodId;
    final Result result = await ref.read(appUnlockMethodSettingsEntryProvider.notifier).changeValueIfUnlockSucceed(context.appUnlockInteraction, newMethod);
    if (context.mounted) {
      handleResult(
        context,
        result,
        presentation: .errorDialog,
      );
    }
  }

  @override
  bool isEnabled(String? value) => value == LocalAuthenticationAppUnlockMethod.kMethodId;
}
