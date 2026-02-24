import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:open_authenticator/app.dart';
import 'package:open_authenticator/i18n/translations.g.dart';
import 'package:open_authenticator/pages/intro/slides/slide.dart';
import 'package:open_authenticator/widgets/title_text.dart';

/// The very first slide shown to the user.
class WelcomeIntroPageSlide extends IntroPageSlide {
  /// Creates a new welcome intro page content instance.
  const WelcomeIntroPageSlide()
    : super(
        name: 'welcome',
      );

  @override
  Widget createWidget(BuildContext context, int remainingSteps) => IntroPageSlideWidget(
    titleWidget: const TitleText(),
    slide: this,
    children: [
      IntroPageSlideParagraphWidget(text: translations.intro.welcome.firstParagraph(app: App.appName)),
      if (remainingSteps > 0)
        IntroPageSlideParagraphWidget(
          text: translations.intro.welcome.secondParagraph,
        ),
      IntroPageSlideParagraphWidget(
        text: translations.intro.welcome.thirdParagraph,
        textStyle: TextStyle(
          fontWeight: FontWeight.bold,
          color: context.theme.colors.primary,
        ),
      ),
    ],
  );
}
