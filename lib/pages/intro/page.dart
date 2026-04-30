import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'package:open_authenticator/i18n/translations.g.dart';
import 'package:open_authenticator/model/settings/show_intro.dart';
import 'package:open_authenticator/pages/home/page.dart';
import 'package:open_authenticator/pages/intro/slides/log_in.dart';
import 'package:open_authenticator/pages/intro/slides/password.dart';
import 'package:open_authenticator/pages/intro/slides/slide.dart';
import 'package:open_authenticator/pages/intro/slides/welcome.dart';
import 'package:open_authenticator/spacing.dart';
import 'package:open_authenticator/utils/brightness_listener.dart';
import 'package:open_authenticator/widgets/app_scaffold.dart';
import 'package:open_authenticator/widgets/button_text.dart';
import 'package:open_authenticator/widgets/clickable.dart';
import 'package:open_authenticator/widgets/step_progress_indicator.dart';

/// Shows an intro page, that explains what the app does to the user.
class IntroPage extends ConsumerStatefulWidget {
  /// The intro page name.
  static const String name = '/intro';

  /// Creates a new intro page instance.
  const IntroPage({
    super.key,
  });

  @override
  ConsumerState<IntroPage> createState() => _IntroPageState();
}

/// The intro page state.
class _IntroPageState extends ConsumerState<IntroPage> with BrightnessListener {
  @override
  void onBrightnessChange(Brightness brightness) {
    super.onBrightnessChange(brightness);
    _adaptSystemUiOverlayToBrightness();
  }

  @override
  void onThemeSettingsEntryChange(AsyncValue<ThemeMode>? previous, AsyncValue<ThemeMode> next) {
    super.onThemeSettingsEntryChange(previous, next);
    _adaptSystemUiOverlayToBrightness();
  }

  /// Allows to adapt system UI overlay to the current brightness.
  void _adaptSystemUiOverlayToBrightness() {
    Brightness brightness = currentBrightness;
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: brightness == Brightness.dark ? Brightness.light : Brightness.dark,
        systemNavigationBarIconBrightness: brightness == Brightness.dark ? Brightness.light : Brightness.dark,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    child: AppScaffold.asyncValue(
      center: true,
      asyncValue: ref.watch(currentIntroPageSlideProvider),
      footerBuilder: (slideState) {
        bool hasFinished = slideState.slideIndex == slideState.slideCount - 1;
        return Padding(
          padding: .only(
            top: kSpace,
            right: kBigSpace,
            bottom: kSpace + MediaQuery.paddingOf(context).bottom,
            left: kBigSpace,
          ),
          child: SizedBox(
            width: MediaQuery.sizeOf(context).width,
            child: Row(
              mainAxisSize: .min,
              mainAxisAlignment: .spaceBetween,
              children: [
                StepProgressIndicator(
                  steps: slideState.slideCount,
                  currentStep: slideState.slideIndex + 1,
                ),
                ClickableButton(
                  mainAxisSize: .min,
                  onPress: slideState.canGoToNextSlide
                      ? () async {
                          bool shouldFinish = await ref.read(currentIntroPageSlideProvider.notifier).goToNextSlide(context);
                          if (shouldFinish) {
                            finish();
                          }
                        }
                      : null,
                  prefix: Icon(hasFinished ? FIcons.check : FIcons.chevronRight),
                  child: ButtonText(hasFinished ? translations.intro.button.finish : translations.intro.button.next),
                ),
              ],
            ),
          ),
        );
      },
      builder: (slideState) => [
        PageTransitionSwitcher(
          transitionBuilder: (child, primaryAnimation, secondaryAnimation) => SharedAxisTransition(
            animation: primaryAnimation,
            secondaryAnimation: secondaryAnimation,
            transitionType: SharedAxisTransitionType.horizontal,
            child: child,
          ),
          child: switch (slideState.slide) {
            .welcome => WelcomeIntroPageSlide(
              remainingSlides: slideState.remainingSlideCount,
            ),
            .password => PasswordIntroPageSlide(
              saveDerivedKey: (slideState as PasswordIntroPageSlideState).saveDerivedKey,
              onPasswordChanged: (password) => ref.read(currentIntroPageSlideProvider.notifier).updateState(slideState.overwritePassword(password)),
              onSaveDerivedKeyChanged: (saveDerivedKey) => ref.read(currentIntroPageSlideProvider.notifier).updateState(slideState.overwriteSaveDerivedKey(saveDerivedKey)),
            ),
            .logIn => const LogInIntroPageSlide(),
          },
        ),
      ],
    ),
  );

  /// Finishes the intro.
  Future<void> finish() async {
    SystemChrome.restoreSystemUIOverlays();
    Navigator.pushNamedAndRemoveUntil(context, HomePage.name, (_) => false);
    ref.read(showIntroSettingsEntryProvider.notifier).changeValue(false);
  }
}
