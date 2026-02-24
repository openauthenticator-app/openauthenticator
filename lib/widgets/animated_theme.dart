import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'package:open_authenticator/utils/brightness_listener.dart';

/// Allows to switch between light and dark themes with an animation.
class AnimatedFTheme extends ConsumerStatefulWidget {
  /// The light theme.
  final FThemeData light;

  /// The dark theme.
  final FThemeData dark;

  /// The child.
  final Widget child;

  /// Creates a new animated theme widget instance.
  const AnimatedFTheme({
    super.key,
    required this.light,
    required this.dark,
    required this.child,
  });

  @override
  ConsumerState<ConsumerStatefulWidget> createState() => _AnimatedFThemeState();
}

/// The animated theme widget state.
class _AnimatedFThemeState extends ConsumerState<AnimatedFTheme> with BrightnessListener {
  @override
  Widget build(BuildContext context) => FTheme(
    data: currentBrightness == .dark ? widget.dark : widget.light,
    child: widget.child,
  );
}
