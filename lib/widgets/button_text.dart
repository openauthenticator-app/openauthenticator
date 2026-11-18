import 'package:forui/forui.dart';
import 'package:material_ui/material_ui.dart';

/// A simple button text.
class ButtonText extends StatelessWidget {
  /// The text.
  final String text;

  /// The max lines.
  final int maxLines;

  /// The overflow strategy.
  final TextOverflow overflow;

  /// The flexible breakpoint.
  final double? flexibleBreakpoint;

  /// Creates a new button text instance.
  const ButtonText(
    this.text, {
    super.key,
    this.maxLines = 1,
    this.overflow = TextOverflow.ellipsis,
    this.flexibleBreakpoint,
  });

  @override
  Widget build(BuildContext context) {
    final Widget child = Text(
      text,
      maxLines: maxLines,
      overflow: overflow,
    );
    return MediaQuery.sizeOf(context).width >= (flexibleBreakpoint ?? context.theme.breakpoints.sm) ? child : Flexible(child: child);
  }
}
