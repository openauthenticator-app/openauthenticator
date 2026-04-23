import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'package:open_authenticator/i18n/translations.g.dart';
import 'package:open_authenticator/model/app_unlock/methods/method.dart';
import 'package:open_authenticator/model/settings/app_unlock_method.dart';
import 'package:open_authenticator/pages/settings/entries/widgets.dart';
import 'package:open_authenticator/utils/local_authentication/local_authentication.dart';

/// Allows to configure [enableLocalAuthSettingsEntryProvider].
class EnableLocalAuthSettingsEntryWidget extends CheckboxSettingsEntryWidget<AppUnlockMethodSettingsEntry, String> {
  /// Creates a new enable local auth settings entry widget instance.
  EnableLocalAuthSettingsEntryWidget({
    super.key,
  }) : super(
         provider: appUnlockMethodSettingsEntryProvider,
         title: translations.settings.security.enableLocalAuth.title,
         subtitle: translations.settings.security.enableLocalAuth.subtitle,
         icon: FIcons.lock,
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
    String newMethod = newValue ? LocalAuthenticationAppUnlockMethod.kMethodId : NoneAppUnlockMethod.kMethodId;
    ref.read(appUnlockMethodSettingsEntryProvider.notifier).changeValueIfUnlockSucceed(newMethod, context);
  }

  @override
  bool isEnabled(String? value) => value == LocalAuthenticationAppUnlockMethod.kMethodId;
}
