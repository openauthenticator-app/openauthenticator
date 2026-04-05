import 'package:flutter/material.dart';
import 'package:open_authenticator/i18n/translations.g.dart';
import 'package:open_authenticator/spacing.dart';
import 'package:open_authenticator/widgets/button_text.dart';
import 'package:open_authenticator/widgets/clickable.dart';
import 'package:open_authenticator/widgets/dialog/app_dialog.dart';

/// Shows a waiting dialog.
Future<T> showWaitingOverlay<T>(
  BuildContext context, {
  Future<T>? future,
  String? message,
  Duration? timeout,
  String? timeoutMessage,
  bool Function()? onCancel,
}) async {
  OverlayEntry entry = OverlayEntry(
    builder: (context) => Stack(
      children: [
        const ModalBarrier(
          dismissible: false,
          color: Colors.black54,
        ),
        _WaitingDialog(
          message: message,
          timeout: timeout,
          timeoutMessage: timeoutMessage,
          onCancel: onCancel,
        ),
      ],
    ),
  );
  Overlay.of(context).insert(entry);
  if (future != null) {
    try {
      T result = await future;
      return result;
    } catch (ex) {
      rethrow;
    } finally {
      entry.remove();
    }
  }
  return null as T;
}

/// A waiting dialog, with or without a timeout.
class _WaitingDialog extends StatelessWidget {
  /// The message to display.
  final String? message;

  /// The timeout.
  final Duration? timeout;

  /// Shown when timed out.
  final String? timeoutMessage;

  /// The cancel callback.
  final bool Function()? onCancel;

  /// Creates a new waiting dialog instance.
  const _WaitingDialog({
    this.message,
    this.timeout,
    this.timeoutMessage,
    this.onCancel,
  });

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    child: AppDialog(
      scrollable: false,
      actions: onCancel == null
          ? null
          : [
              ClickableButton(
                variant: .secondary,
                child: ButtonText(MaterialLocalizations.of(context).cancelButtonLabel),
                onPress: () {
                  if (onCancel!()) {
                    Navigator.pop(context);
                  }
                },
              ),
            ],
      children: [
        Row(
          children: [
            const Padding(
              padding: EdgeInsets.only(
                top: kSpace,
                right: kBigSpace,
                bottom: kSpace,
              ),
              child: CircularProgressIndicator(),
            ),
            Expanded(
              child: Text(message ?? translations.miscellaneous.waitingDialogDefaultMessage),
            ),
          ],
        ),
      ],
    ),
  );
}
