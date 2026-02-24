import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'package:open_authenticator/app.dart';
import 'package:open_authenticator/i18n/translations.g.dart';
import 'package:open_authenticator/model/backend/user.dart';
import 'package:open_authenticator/model/totp/repository.dart';
import 'package:open_authenticator/model/totp/totp.dart';
import 'package:open_authenticator/pages/intro/slides/slide.dart';
import 'package:open_authenticator/pages/settings/entries/synchronize.dart';
import 'package:open_authenticator/utils/account.dart';
import 'package:open_authenticator/widgets/button_text.dart';
import 'package:open_authenticator/widgets/clickable.dart';

/// The slide that allows the user to login to Firebase.
class LogInIntroPageSlide extends IntroPageSlide {
  /// Creates a new login intro page content instance.
  LogInIntroPageSlide()
    : super(
        name: 'logIn',
      );

  @override
  Widget createWidget(BuildContext context, int remainingSteps) => IntroPageSlideWidget(
    titleWidget: Text(translations.intro.logIn.title),
    slide: this,
    children: [
      IntroPageSlideParagraphWidget(text: translations.intro.logIn.firstParagraph),
      IntroPageSlideParagraphWidget(
        text: translations.intro.logIn.secondParagraph,
        textStyle: const TextStyle(fontStyle: FontStyle.italic),
      ),
      Padding(
        padding: const EdgeInsets.only(bottom: IntroPageSlideParagraphWidget.kDefaultPadding),
        child: _LogInButton(),
      ),
      SynchronizeSettingsEntryWidget.intro(),
      IntroPageSlideParagraphWidget(text: translations.intro.logIn.thirdParagraph),
      IntroPageSlideParagraphWidget(
        text: translations.intro.logIn.fourthParagraph(app: App.appName),
        padding: 0,
      ),
    ],
  );

  @override
  Future<bool> shouldSkip(WidgetRef ref) async {
    List<Totp> totps = await ref.read(totpRepositoryProvider.future);
    return totps.isNotEmpty;
  }
}

/// The log-in button.
class _LogInButton extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    User? user = ref.watch(userProvider).value;
    return user == null
        ? ClickableButton(
            onPress: () => AccountUtils.trySignIn(context),
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
