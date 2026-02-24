import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'package:open_authenticator/pages/intro/slides/log_in.dart';
import 'package:open_authenticator/pages/intro/slides/password.dart';
import 'package:open_authenticator/pages/intro/slides/welcome.dart';
import 'package:open_authenticator/spacing.dart';
import 'package:open_authenticator/utils/brightness_listener.dart';
import 'package:open_authenticator/widgets/sized_scalable_image.dart';

/// A "slide" of the intro page.
class IntroPageSlide {
  /// The slide name.
  final String name;

  /// Creates a new intro page content instance.
  const IntroPageSlide({
    required this.name,
  });

  /// Whether this page content can be skipped.
  bool get canSkip => true;

  /// Whether this page content should be skipped.
  Future<bool> shouldSkip(WidgetRef ref) => Future.value(false);

  /// Returns the image SVG path.
  String get imagePath => 'assets/images/intro/${name.toLowerCase()}.si';

  /// Triggered when the user clicks on "Next".
  Future<bool> onGoToNextSlide(BuildContext context, WidgetRef ref) => Future.value(true);

  /// Creates the widget for showing this slide.
  Widget createWidget(BuildContext context, int remainingSteps) => IntroPageSlideWidget(
    slide: this,
  );
}

/// Contains all intro page slide types.
enum IntroPageSlideType {
  /// The very first slide shown to the user.
  welcome(create: WelcomeIntroPageSlide.new),

  /// The slide that allows the user to define a master password.
  password(create: PasswordIntroPageSlide.new),

  /// The slide that allows the user to login to Firebase.
  logIn(create: LogInIntroPageSlide.new)
  ;

  /// Allows to create a new intro page slide instance.
  final IntroPageSlide Function() create;

  /// Creates a new intro page slide type instance.
  const IntroPageSlideType({
    required this.create,
  });
}

/// An intro page slide widget.
class IntroPageSlideWidget extends ConsumerStatefulWidget {
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
  ConsumerState<ConsumerStatefulWidget> createState() => IntroPageSlideWidgetState();
}

/// An intro page slide widget state.
class IntroPageSlideWidgetState extends ConsumerState<IntroPageSlideWidget> with TickerProviderStateMixin, BrightnessListener {
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
  Widget build(BuildContext context) => DefaultTextStyle.merge(
    style: TextStyle(color: currentBrightness == Brightness.dark ? Colors.white60 : Colors.grey.shade700),
    textAlign: TextAlign.center,
    child: Center(
      child: ListView(
        padding: EdgeInsets.only(
          top: MediaQuery.sizeOf(context).width <= context.theme.breakpoints.md ? (kBigSpace * 2) : kBigSpace,
          right: kBigSpace,
          left: kBigSpace,
          bottom: kBigSpace,
        ),
        shrinkWrap: true,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: kBigSpace * 2),
            child: DefaultTextStyle.merge(
              child: FadeTransition(
                opacity: _textAnimation,
                child: widget.titleWidget,
              ),
              style: context.theme.typography.xl2,
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: kBigSpace * 2),
            child: FadeScaleTransition(
              animation: _imageAnimation,
              child: SizedBox(
                height: 200,
                child: SizedScalableImage(
                  asset: widget.slide.imagePath,
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
      ),
    ),
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
  /// The paragraph padding.
  static const double kDefaultPadding = 10;

  /// The text span.
  final TextSpan textSpan;

  /// The bottom padding.
  final double padding;

  /// Creates a paragraph text, with a separator.
  IntroPageSlideParagraphWidget({
    Key? key,
    required String text,
    TextStyle? textStyle,
    double padding = kDefaultPadding,
  }) : this.rich(
         key: key,
         textSpan: TextSpan(
           text: text,
           style: (textStyle ?? const TextStyle()).copyWith(
             height: 1.25,
           ),
         ),
         padding: padding,
       );

  /// Creates a paragraph text, with a separator.
  const IntroPageSlideParagraphWidget.rich({
    super.key,
    required this.textSpan,
    this.padding = kDefaultPadding,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: padding),
    child: Text.rich(textSpan),
  );

  /// Returns the same paragraph without padding.
  IntroPageSlideParagraphWidget get withoutPadding => IntroPageSlideParagraphWidget.rich(
    textSpan: textSpan,
    padding: 0,
  );
}
