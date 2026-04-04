import 'package:flutter/material.dart';
import 'package:open_authenticator/spacing.dart';
import 'package:open_authenticator/widgets/sized_scalable_image.dart';
import 'package:open_authenticator/widgets/title_text.dart';

/// Allows to display an image, followed by a text and some actions.
class ImageTextActions extends StatelessWidget {
  /// The image size.
  static const double _kImageSize = 80;

  /// The image.
  final Widget image;

  /// The message to display.
  final String text;

  /// The actions.
  final List<Widget> actions;

  /// Creates a new image text actions instance.
  const ImageTextActions({
    super.key,
    required this.image,
    required this.text,
    this.actions = const [],
  });

  /// Creates a new image text actions instance from an asset.
  const ImageTextActions.asset({
    Key? key,
    required String asset,
    required String text,
    List<Widget> actions = const [],
  }) : this(
         key: key,
         image: const SizedScalableImage(
           height: _kImageSize,
           asset: 'assets/images/home.si',
         ),
         text: text,
         actions: actions,
       );

  /// Creates a new image text actions instance from an icon.
  ImageTextActions.icon({
    Key? key,
    required IconData icon,
    required String text,
    List<Widget> actions = const [],
  }) : this(
         key: key,
         image: AppTitleGradient(
           child: Icon(
             icon,
             size: _kImageSize,
           ),
         ),
         text: text,
         actions: actions,
       );

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: .min,
    children: [
      Padding(
        padding: const EdgeInsets.only(bottom: kBigSpace),
        child: image,
      ),
      Padding(
        padding: EdgeInsets.only(bottom: actions.isEmpty ? 0 : kBigSpace),
        child: Text(
          text,
          textAlign: TextAlign.center,
        ),
      ),
      for (int i = 0; i < actions.length; i++)
        Center(
          child: Padding(
            padding: EdgeInsets.only(bottom: i == actions.length - 1 ? 0 : kSpace),
            child: actions[i],
          ),
        ),
    ],
  );
}
