import 'package:flutter/material.dart';
import 'package:open_authenticator/app.dart';

/// The title widget with a nice green color.
class TitleText extends StatelessWidget {
  /// The text to display.
  final String text;

  /// The text align.
  final TextAlign? textAlign;

  /// The text style.
  final TextStyle? textStyle;

  /// Creates a new title widget instance.
  const TitleText({
    super.key,
    this.text = App.appName,
    this.textAlign,
    this.textStyle,
  });

  @override
  Widget build(BuildContext context) {
    List<String> parts = text.split(' ');
    if (parts.length == 1) {
      return _createGradientText(parts.first).child;
    }
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '${parts.first} ',
          ),
          _createGradientText(parts[1]),
          for (int i = 2; i < parts.length; i++)
            TextSpan(
              text: ' ${parts[i]}',
            ),
        ],
      ),
      style: textStyle,
      textAlign: textAlign,
    );
  }

  /// Creates a text with a gradient.
  WidgetSpan _createGradientText(String text) => WidgetSpan(
    child: AppTitleGradient(
      child: Text(
        text,
        style: (textStyle ?? const TextStyle()).copyWith(
          height: 1.275,
          fontWeight: FontWeight.bold,
        ),
      ),
    ),
    alignment: PlaceholderAlignment.middle,
  );
}

/// Displays a widget with the app gradient.
class AppTitleGradient extends StatelessWidget {
  /// The gradient.
  static final LinearGradient gradient = LinearGradient(
    colors: [
      Colors.green.shade300,
      Colors.green.shade400,
      Colors.green.shade500,
      Colors.green.shade500,
      Colors.green.shade600,
      Colors.green.shade800,
    ],
    stops: const [
      0,
      0.021,
      0.293,
      0.554,
      0.796,
      1,
    ],
  );

  /// The child.
  final Widget child;

  /// Creates a new app title gradient instance.
  const AppTitleGradient({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) => ShaderMask(
    blendMode: BlendMode.srcIn,
    shaderCallback: (bounds) => gradient.createShader(
      Rect.fromLTWH(0, 0, bounds.width, bounds.height),
    ),
    child: child,
  );
}
