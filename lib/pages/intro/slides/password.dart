import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'package:open_authenticator/i18n/translations.g.dart';
import 'package:open_authenticator/model/app_unlock/methods/method.dart';
import 'package:open_authenticator/model/settings/app_unlock_method.dart';
import 'package:open_authenticator/pages/intro/slides/slide.dart';
import 'package:open_authenticator/spacing.dart';
import 'package:open_authenticator/widgets/clickable.dart';
import 'package:open_authenticator/widgets/form/master_password_form.dart';

/// The password intro page slide.
class PasswordIntroPageSlide extends StatelessWidget {
  /// Called when the password changes.
  final ValueChanged<String?>? onPasswordChanged;

  /// Called when the save derived key checkbox changes.
  final ValueChanged<bool?>? onSaveDerivedKeyChanged;

  /// Whether to save the derived key.
  final bool saveDerivedKey;

  /// Creates a new password intro page slide instance.
  const PasswordIntroPageSlide({
    super.key,
    this.onPasswordChanged,
    this.onSaveDerivedKeyChanged,
    this.saveDerivedKey = true,
  });

  @override
  Widget build(BuildContext context) => IntroPageSlideWidget(
    titleWidget: Text(translations.intro.password.title),
    slide: .password,
    children: [
      IntroPageSlideParagraphWidget(
        text: translations.intro.password.firstParagraph,
        textAlign: .center,
        padding: kBigSpace,
      ),
      Padding(
        padding: const EdgeInsets.only(bottom: kSpace),
        child: FTile.raw(
          child: MasterPasswordForm(onChanged: onPasswordChanged),
        ),
      ),
      Consumer(
        builder: (context, ref, child) {
          String? unlockMethod = ref.watch(appUnlockMethodSettingsEntryProvider).value;
          return {MasterPasswordAppUnlockMethod.kMethodId, LocalAuthenticationAppUnlockMethod.kMethodId}.contains(unlockMethod)
              ? SizedBox.fromSize(
                  size: const Size.fromHeight(kSpace),
                )
              : Padding(
                  padding: const EdgeInsets.only(bottom: kBigSpace),
                  child: ClickableTile(
                    title: Text(translations.settings.security.saveDerivedKey.title),
                    subtitle: Text(translations.settings.security.saveDerivedKey.subtitle),
                    enabled: onSaveDerivedKeyChanged != null,
                    onPress: () => onSaveDerivedKeyChanged?.call(!saveDerivedKey),
                    suffix: FCheckbox(
                      value: saveDerivedKey,
                      enabled: onSaveDerivedKeyChanged != null,
                      onChange: onSaveDerivedKeyChanged,
                    ),
                  ),
                );
        },
      ),
      IntroPageSlideParagraphWidget(
        text: translations.intro.password.secondParagraph,
        textAlign: .center,
        padding: kBigSpace,
      ),
      FAlert(
        variant: .destructive,
        title: Text(MaterialLocalizations.of(context).alertDialogLabel),
        subtitle: Text(translations.intro.password.thirdParagraph),
      ),
    ],
  );
}
