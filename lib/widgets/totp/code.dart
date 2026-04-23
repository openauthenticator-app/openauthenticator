import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:open_authenticator/model/totp/decrypted.dart';
import 'package:open_authenticator/widgets/totp/time_based.dart';

/// Displays a TOTP code.
class TotpCode extends TimeBasedTotpWidget {
  /// The text style.
  final TextStyle? textStyle;

  /// Creates a new TOTP code widget instance.
  const TotpCode({
    super.key,
    required super.totp,
    this.textStyle,
  });

  @override
  State<TimeBasedTotpWidget> createState() => _TotpCodeState();
}

/// The TOTP code widget state.
class _TotpCodeState extends TimeBasedTotpWidgetState<TotpCode> {
  /// The current code.
  late String code = currentTimeCode;

  @override
  Widget build(BuildContext context) {
    TextStyle textStyle = widget.textStyle ?? context.theme.typography.md;
    return Container(
      decoration: BoxDecoration(
        color: context.theme.colors.primary.withValues(alpha: 0.15),
        borderRadius: context.theme.style.borderRadius.md,
      ),
      padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 8),
      child: Text(
        code,
        style: textStyle,
      ),
    );
  }

  @override
  void updateState() {
    if (mounted) {
      setState(() => code = currentTimeCode);
    }
  }

  /// Returns the time that corresponds to the current time.
  String get currentTimeCode {
    if (!widget.totp.isDecrypted) {
      return '';
    }
    String code = (widget.totp as DecryptedTotp).generateCode();
    StringBuffer buffer = StringBuffer();
    for (int i = 0; i < code.length; i++) {
      buffer.write(code[i]);
      int nonZeroIndex = i + 1;
      if (nonZeroIndex % 3 == 0 && nonZeroIndex != code.length) {
        buffer.write(' ');
      }
    }
    return buffer.toString();
  }
}
