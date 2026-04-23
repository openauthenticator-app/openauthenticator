import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'package:open_authenticator/i18n/translations.g.dart';
import 'package:open_authenticator/model/app_unlock/methods/method.dart';
import 'package:open_authenticator/model/settings/app_unlock_method.dart';
import 'package:open_authenticator/pages/settings/entries/widgets.dart';
import 'package:open_authenticator/utils/result.dart';

/// Allows to configure [saveDerivedKeySettingsEntryProvider].
class SaveDerivedKeySettingsEntryWidget extends CheckboxSettingsEntryWidget<AppUnlockMethodSettingsEntry, String> {
  /// Creates a new save derived key settings entry widget instance.
  SaveDerivedKeySettingsEntryWidget({
    super.key,
    super.icon = FIcons.keyRound,
  }) : super(
         provider: appUnlockMethodSettingsEntryProvider,
         title: translations.settings.security.saveDerivedKey.title,
         subtitle: translations.settings.security.saveDerivedKey.subtitle,
       );

  /// Creates a new save derived key settings entry widget instance for the intro page.
  SaveDerivedKeySettingsEntryWidget.intro({
    Key? key,
  }) : this(
         key: key,
         icon: null,
       );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    AsyncValue<String> unlockMethod = ref.watch(appUnlockMethodSettingsEntryProvider);
    if (!unlockMethod.hasValue || unlockMethod.value == LocalAuthenticationAppUnlockMethod.kMethodId) {
      return const SizedBox.shrink();
    }
    return super.build(context, ref);
  }

  @override
  Future<void> changeValue(BuildContext context, WidgetRef ref, bool newValue) async {
    String newMethod = newValue ? NoneAppUnlockMethod.kMethodId : MasterPasswordAppUnlockMethod.kMethodId;
    Result result = await ref.read(appUnlockMethodSettingsEntryProvider.notifier).changeValueIfUnlockSucceed(newMethod, context);
    if (context.mounted && result is! ResultSuccess) {
      context.handleResult(result);
    }
  }

  @override
  bool isEnabled(String? value) => value != MasterPasswordAppUnlockMethod.kMethodId;
}
