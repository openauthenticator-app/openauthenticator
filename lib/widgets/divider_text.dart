import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:open_authenticator/spacing.dart';
import 'package:open_authenticator/utils/utils.dart';

/// A divider with a text in the middle.
class DividerText extends StatelessWidget {
  /// The left divider.
  final Widget leftDivider;

  /// The text.
  final Widget text;

  /// The right divider.
  final Widget rightDivider;

  /// Creates a new divider text instance.
  const DividerText({
    super.key,
    this.leftDivider = const Divider(),
    required this.text,
    this.rightDivider = const Divider(),
  });

  @override
  Widget build(BuildContext context) => Theme(
    data: Theme.of(context).copyWith(
      dividerTheme: DividerThemeData(
        color: context.theme.colors.background.highlight(),
      ),
    ),
    child: Row(
      children: [
        Flexible(child: leftDivider),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: kSpace),
          child: text,
        ),
        Flexible(child: rightDivider),
      ],
    ),
  );
}
