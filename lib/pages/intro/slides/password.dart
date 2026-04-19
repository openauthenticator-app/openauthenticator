import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:open_authenticator/i18n/translations.g.dart';
import 'package:open_authenticator/pages/intro/slides/slide.dart';
import 'package:open_authenticator/pages/settings/entries/save_derived_key.dart';
import 'package:open_authenticator/spacing.dart';
import 'package:open_authenticator/widgets/form/master_password_form.dart';

/// The password intro page slide.
class PasswordIntroPageSlide extends StatelessWidget {
  /// Called when the password changes.
  final ValueChanged<String?>? onPasswordChanged;

  /// Creates a new password intro page slide instance.
  const PasswordIntroPageSlide({
    super.key,
    this.onPasswordChanged,
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
      Padding(
        padding: const EdgeInsets.only(bottom: kBigSpace),
        child: SaveDerivedKeySettingsEntryWidget.intro(),
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
