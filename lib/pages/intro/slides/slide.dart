import 'dart:async';

import 'package:animations/animations.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'package:open_authenticator/model/app_unlock/methods/method.dart';
import 'package:open_authenticator/model/crypto/derived_key.dart';
import 'package:open_authenticator/model/crypto/salt.dart';
import 'package:open_authenticator/model/settings/app_unlock_method.dart';
import 'package:open_authenticator/model/totp/repository.dart';
import 'package:open_authenticator/spacing.dart';
import 'package:open_authenticator/utils/result/result.dart';
import 'package:open_authenticator/widgets/sized_scalable_image.dart';

/// The current intro page slide provider.
final currentIntroPageSlideProvider = AsyncNotifierProvider.autoDispose<CurrentIntroPageSlideNotifier, CurrentIntroSlideState>(CurrentIntroPageSlideNotifier.new);

/// The current intro page slide notifier.
class CurrentIntroPageSlideNotifier extends AsyncNotifier<CurrentIntroSlideState> {
  @override
  Future<CurrentIntroSlideState> build() async {
    List<IntroPageSlide> slides = [
      for (IntroPageSlide slide in IntroPageSlide.values)
        if (!(await _shouldSkipSlide(slide))) slide,
    ];
    return CurrentIntroSlideState._(
      slides: slides,
      slideIndex: 0,
    );
  }

  /// Returns `true` if the slide should be skipped.
  Future<bool> _shouldSkipSlide(IntroPageSlide slide) async => switch (slide) {
    IntroPageSlide.password => (await ref.read(saltProvider.future)) != null && (await ref.read(derivedKeyProvider.future)) != null,
    IntroPageSlide.logIn => (await ref.read(totpRepositoryProvider.future)).isNotEmpty,
    _ => false,
  };

  /// Goes to the next slide.
  /// Returns `true` if the intro should finish.
  Future<bool> goToNextSlide(BuildContext context) async {
    CurrentIntroSlideState slideState = await future;
    if (slideState.slide == .password) {
      String? password = (slideState as PasswordIntroPageSlideState).password;
      if (password == null) {
        return false;
      }
      if (!slideState.saveDerivedKey) {
        await ref
            .read(appUnlockMethodSettingsEntryProvider.notifier)
            .changeValue(
              MasterPasswordAppUnlockMethod.kMethodId,
              enableResult: ResultSuccess<String>(value: password),
            );
      }
      await ref.read(saltProvider.notifier).generateIfNeeded();
      await ref.read(derivedKeyProvider.notifier).updateFromPassword(password);
    }
    CurrentIntroSlideState? next = slideState._createNextSlideState();
    if (next == null) {
      return true;
    }
    updateState(next);
    return false;
  }

  /// Updates the state.
  void updateState(CurrentIntroSlideState slideState) {
    if (ref.mounted) {
      state = AsyncData(slideState);
    }
  }
}

/// The current intro page slide state.
class CurrentIntroSlideState with EquatableMixin {
  /// The slides to display.
  final List<IntroPageSlide> _slides;

  /// The current slide index.
  final int slideIndex;

  /// Creates a new current intro slide state.
  const CurrentIntroSlideState._({
    required List<IntroPageSlide> slides,
    required this.slideIndex,
  }) : _slides = slides;

  /// Returns the next slide state.
  CurrentIntroSlideState? _createNextSlideState() {
    if (slideIndex == slideCount - 1) {
      return null;
    }
    IntroPageSlide slide = _slides[slideIndex + 1];
    return (slide == .password ? PasswordIntroPageSlideState._ : CurrentIntroSlideState._)(
      slides: _slides,
      slideIndex: slideIndex + 1,
    );
  }

  /// Returns the current slide.
  IntroPageSlide get slide => _slides[slideIndex];

  /// Returns the remaining slide.
  int get remainingSlideCount => _slides.length - slideIndex - 1;

  /// Returns the slide count.
  int get slideCount => _slides.length;

  /// Returns `true` if the user can go to the next slide.
  bool get canGoToNextSlide => true;

  @override
  List<Object?> get props => [slide];
}

/// The password intro page slide state.
class PasswordIntroPageSlideState extends CurrentIntroSlideState {
  /// The password.
  final String? password;

  /// Whether to save the derived key.
  final bool saveDerivedKey;

  /// Creates a new password intro slide state.
  const PasswordIntroPageSlideState._({
    required super.slideIndex,
    required super.slides,
    this.password,
    this.saveDerivedKey = true,
  }) : super._();

  @override
  bool get canGoToNextSlide => password != null;

  @override
  List<Object?> get props => [slide, password, saveDerivedKey];

  /// Overwrites the password.
  PasswordIntroPageSlideState overwritePassword(String? password) => PasswordIntroPageSlideState._(
    slides: _slides,
    slideIndex: slideIndex,
    password: password,
    saveDerivedKey: saveDerivedKey,
  );

  /// Overwrites the save derived key settings entry.
  PasswordIntroPageSlideState overwriteSaveDerivedKey(bool? saveDerivedKey) => PasswordIntroPageSlideState._(
    slides: _slides,
    slideIndex: slideIndex,
    password: password,
    saveDerivedKey: saveDerivedKey ?? true,
  );
}

/// A "slide" of the intro page.
enum IntroPageSlide {
  /// The very first slide shown to the user.
  welcome,

  /// The slide that allows the user to define a master password.
  password,

  /// The slide that allows the user to login to Firebase.
  logIn,
}

/// An intro page slide widget.
class IntroPageSlideWidget extends StatefulWidget {
  /// The slide instance.
  final IntroPageSlide slide;

  /// The title widget.
  final Widget titleWidget;

  /// The children.
  final List<Widget> children;

  /// Creates a new intro page slide widget instance.
  IntroPageSlideWidget({
    super.key,
    Widget? titleWidget,
    required this.slide,
    this.children = const [],
  }) : titleWidget =
           titleWidget ??
           IntroPageSlideTitleWidget(
             slide: slide,
           );

  @override
  State<StatefulWidget> createState() => IntroPageSlideWidgetState();
}

/// An intro page slide widget state.
class IntroPageSlideWidgetState extends State<IntroPageSlideWidget> with TickerProviderStateMixin {
  /// The image animation controller.
  late final AnimationController _imageAnimationController =
      AnimationController(
          duration: const Duration(seconds: 1),
          vsync: this,
        )
        ..addListener(() {
          if (_imageAnimationController.value >= 0.75 && _textAnimationController.value == 0) {
            _textAnimationController.forward();
          }
        })
        ..forward();

  /// The image animation.
  late final Animation<double> _imageAnimation = CurvedAnimation(
    parent: _imageAnimationController,
    curve: Curves.easeIn,
  );

  /// The text animation controller.
  late final AnimationController _textAnimationController = AnimationController(
    duration: const Duration(milliseconds: 500),
    vsync: this,
  );

  /// The text animation.
  late final Animation<double> _textAnimation = CurvedAnimation(
    parent: _textAnimationController,
    curve: Curves.linear,
  );

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Padding(
        padding: .only(
          top: MediaQuery.paddingOf(context).top,
          bottom: kBigSpace * 2,
        ),
        child: DefaultTextStyle.merge(
          child: FadeTransition(
            opacity: _textAnimation,
            child: widget.titleWidget,
          ),
          style: context.theme.typography.xl3,
        ),
      ),
      Padding(
        padding: const EdgeInsets.only(bottom: kBigSpace * 2),
        child: FadeScaleTransition(
          animation: _imageAnimation,
          child: SizedBox(
            height: 200,
            child: SizedScalableImage(
              asset: 'assets/images/intro/${widget.slide.name}.si',
            ),
          ),
        ),
      ),
      for (int i = 0; i < widget.children.length; i++)
        FadeTransition(
          opacity: _textAnimation,
          child: i == widget.children.length - 1 && widget.children[i] is IntroPageSlideParagraphWidget ? (widget.children[i] as IntroPageSlideParagraphWidget).withoutPadding : widget.children[i],
        ),
    ],
  );

  @override
  void dispose() {
    _imageAnimationController.dispose();
    _textAnimationController.dispose();
    super.dispose();
  }
}

/// A classic title widget.
class IntroPageSlideTitleWidget extends StatelessWidget {
  /// The slide instance.
  final IntroPageSlide slide;

  /// Creates an title widget instance.
  const IntroPageSlideTitleWidget({
    super.key,
    required this.slide,
  });

  @override
  Widget build(BuildContext context) => Text(slide.name);
}

/// A paragraph text, with a separator.
class IntroPageSlideParagraphWidget extends StatelessWidget {
  /// The text span.
  final TextSpan textSpan;

  /// The text alignment.
  final TextAlign? textAlign;

  /// The bottom padding.
  final double padding;

  /// Creates a paragraph text, with a separator.
  IntroPageSlideParagraphWidget({
    Key? key,
    required String text,
    TextStyle? textStyle,
    TextAlign? textAlign = .center,
    double padding = kSpace,
  }) : this.rich(
         key: key,
         textSpan: TextSpan(
           text: text,
           style: textStyle,
         ),
         textAlign: textAlign,
         padding: padding,
       );

  /// Creates a paragraph text, with a separator.
  const IntroPageSlideParagraphWidget.rich({
    super.key,
    required this.textSpan,
    this.textAlign = .center,
    this.padding = kSpace,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: .only(bottom: padding),
    child: Text.rich(
      textSpan,
      textAlign: textAlign,
    ),
  );

  /// Returns the same paragraph without padding.
  IntroPageSlideParagraphWidget get withoutPadding => IntroPageSlideParagraphWidget.rich(
    textSpan: textSpan,
    padding: 0,
    textAlign: textAlign,
  );
}
