import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:open_authenticator/i18n/translations.g.dart';
import 'package:open_authenticator/widgets/clickable.dart';

/// Creates the SnackBar and shows it.
FToasterEntry showSuccessToast(BuildContext context, {required String text}) => _showToast(
  context,
  background: context.theme.colors.primary,
  foreground: context.theme.colors.primaryForeground,
  title: translations.miscellaneous.toast.success,
  text: text,
  icon: FIcons.check,
);

/// Creates the SnackBar and shows it.
FToasterEntry showErrorToast(BuildContext context, {required String text}) => _showToast(
  context,
  background: context.theme.colors.destructive,
  foreground: context.theme.colors.destructiveForeground,
  title: translations.miscellaneous.toast.error,
  text: text,
  icon: FIcons.circleAlert,
);

/// Creates the SnackBar and shows it.
FToasterEntry _showToast(
  BuildContext context, {
  required String title,
  required String text,
  Color? background,
  Color? foreground,
  required IconData icon,
}) => showFToast(
  context: context,
  style: .delta(
    decoration: .delta(
      color: background,
    ),
    titleTextStyle: .delta(
      color: foreground,
    ),
    descriptionTextStyle: .delta(
      color: foreground,
    ),
    iconStyle: .delta(
      color: foreground,
    ),
  ),
  title: Text(title),
  description: Text(text),
  icon: Icon(icon),
  suffixBuilder: (context, entry) => ClickableButton.icon(
    variant: .ghost,
    style: .delta(
      decoration: .delta(
        [
          .all(
            .delta(color: background),
          ),
        ],
      ),
    ),
    onPress: entry.dismiss,
    child: Icon(FIcons.x, color: foreground),
  ),
  duration: const Duration(seconds: 1),
);
