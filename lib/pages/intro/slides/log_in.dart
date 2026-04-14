import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'package:open_authenticator/app.dart';
import 'package:open_authenticator/i18n/translations.g.dart';
import 'package:open_authenticator/model/backend/user.dart';
import 'package:open_authenticator/pages/intro/slides/slide.dart';
import 'package:open_authenticator/pages/settings/entries/synchronize.dart';
import 'package:open_authenticator/spacing.dart';
import 'package:open_authenticator/utils/account.dart';
import 'package:open_authenticator/widgets/button_text.dart';
import 'package:open_authenticator/widgets/clickable.dart';

/// The log-in intro page.
class LogInIntroPageSlide extends StatelessWidget {
  /// Creates a new log-in intro page instance.
  const LogInIntroPageSlide({
    super.key,
  });

  @override
  Widget build(BuildContext context) => IntroPageSlideWidget(
    titleWidget: Text(translations.intro.logIn.title),
    slide: .logIn,
    children: [
      IntroPageSlideParagraphWidget(
        text: translations.intro.logIn.firstParagraph,
        padding: kBigSpace,
      ),
      IntroPageSlideParagraphWidget(
        text: translations.intro.logIn.secondParagraph,
        textStyle: const TextStyle(fontStyle: FontStyle.italic),
      ),
      Padding(
        padding: const EdgeInsets.only(bottom: kBigSpace),
        child: _LogInButton(),
      ),
      SynchronizeSettingsEntryWidget.intro(),
      IntroPageSlideParagraphWidget(
        text: translations.intro.logIn.thirdParagraph,
        padding: kBigSpace,
      ),
      FAlert(
        title: Text(translations.settings.application.contributorPlan.title),
        subtitle: Text(
          translations.intro.logIn.fourthParagraph(app: App.appName),
        ),
      ),
    ],
  );
}

/// The log-in button.
class _LogInButton extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    User? user = ref.watch(userProvider).value;
    return user == null
        ? ClickableButton(
            onPress: () => AccountUtils.tryRequestSignIn(context),
            prefix: const Icon(FIcons.logIn),
            child: ButtonText(translations.intro.logIn.button.loggedOut),
          )
        : ClickableButton(
            onPress: null,
            prefix: const Icon(FIcons.check),
            child: ButtonText(translations.intro.logIn.button.loggedIn),
          );
  }
}
