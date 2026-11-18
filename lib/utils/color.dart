import 'package:material_ui/material_ui.dart';

/// Contains some useful color methods.
extension ColorUtils on Color {
  /// Highlights the color.
  Color highlight({double amount = 0.1}) => computeLuminance() > 0.4 ? darken(amount: amount) : lighten(amount: amount);

  /// Lightens the color.
  Color lighten({double amount = 0.1}) {
    assert(amount >= 0 && amount <= 1, 'The amount must be between 0 and 1.');

    final HSLColor hsl = HSLColor.fromColor(this);
    final HSLColor hslDark = hsl.withLightness((hsl.lightness + amount).clamp(0.0, 1.0));

    return hslDark.toColor();
  }

  /// Darkens the color.
  Color darken({double amount = 0.1}) {
    assert(amount >= 0 && amount <= 1, 'The amount must be between 0 and 1.');

    final HSLColor hsl = HSLColor.fromColor(this);
    final HSLColor hslDark = hsl.withLightness((hsl.lightness - amount).clamp(0.0, 1.0));

    return hslDark.toColor();
  }
}
