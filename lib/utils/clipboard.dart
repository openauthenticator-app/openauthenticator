import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:open_authenticator/i18n/translations.g.dart';
import 'package:open_authenticator/widgets/toast.dart';

/// Copies text and confirms the result, including when another Windows app holds the clipboard.
Future<void> copyText(BuildContext context, String text, {required String confirmation}) async {
  final data = ClipboardData(text: text);
  try {
    try {
      await Clipboard.setData(data);
    } on PlatformException catch (error) {
      if (error.code != 'Clipboard error') {
        rethrow;
      }
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await Clipboard.setData(data);
    }
    if (context.mounted) {
      showSuccessToast(context, text: confirmation);
    }
  } on PlatformException catch (error) {
    if (context.mounted) {
      showErrorToast(context, text: translations.error.generic.withException(exception: error));
    }
  }
}
