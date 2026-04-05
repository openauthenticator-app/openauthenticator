import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:open_authenticator/spacing.dart';

/// The widget to use in decorations.
class FormLabelWithIcon extends StatelessWidget {
  /// The text.
  final String text;

  /// The icon.
  final IconData icon;

  /// Creates a new label widget instance.
  const FormLabelWithIcon({
    super.key,
    required this.text,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: kSpace / 2),
    child: Row(
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2, right: kSpace / 2),
          child: Icon(
            icon,
            color: DefaultTextStyle.of(context).style.color == context.theme.colors.destructive ? context.theme.colors.destructive : context.theme.colors.primary,
            size: 12,
          ),
        ),
        Expanded(
          child: Text(
            text,
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ),
      ],
    ),
  );
}
