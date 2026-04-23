import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:open_authenticator/app.dart';
import 'package:open_authenticator/i18n/translations.g.dart';
import 'package:open_authenticator/pages/intro/slides/slide.dart';
import 'package:open_authenticator/widgets/title_text.dart';

/// The welcome intro page slide.
class WelcomeIntroPageSlide extends StatelessWidget {
  /// The number of remaining slides.
  final int remainingSlides;

  /// Creates a new welcome intro page slide instance.
  const WelcomeIntroPageSlide({
    super.key,
    required this.remainingSlides,
  });

  @override
  Widget build(BuildContext context) => IntroPageSlideWidget(
    titleWidget: const TitleText(),
    slide: .welcome,
    children: [
      IntroPageSlideParagraphWidget(
        text: translations.intro.welcome.firstParagraph(app: App.appName),
        textAlign: .center,
      ),
      if (remainingSlides > 0)
        IntroPageSlideParagraphWidget(
          text: translations.intro.welcome.secondParagraph,
          textAlign: .center,
        ),
      IntroPageSlideParagraphWidget(
        text: translations.intro.welcome.thirdParagraph,
        textAlign: .center,
        textStyle: TextStyle(
          fontWeight: .bold,
          color: context.theme.colors.primary,
        ),
      ),
    ],
  );
}
