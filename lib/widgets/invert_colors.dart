import 'package:material_ui/material_ui.dart';

/// Allows to invert the colors of a widget.
class InvertColors extends StatelessWidget {
  /// The child.
  final Widget child;

  /// Creates a new invert colors instance.
  const InvertColors({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) => ColorFiltered(
    colorFilter: const ColorFilter.matrix(
      [
        -1.0, 0.0, 0.0, 0.0, 255.0, //
        0.0, -1.0, 0.0, 0.0, 255.0, //
        0.0, 0.0, -1.0, 0.0, 255.0, //
        0.0, 0.0, 0.0, 1.0, 0.0, //
      ],
    ),
    child: child,
  );
}
