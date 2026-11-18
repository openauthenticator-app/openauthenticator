import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:open_authenticator/core/settings/theme.dart';

/// Allows to listen to the platform's brightness.
mixin BrightnessListener<T extends ConsumerStatefulWidget> on ConsumerState<T> {
  /// The current brightness.
  Brightness _currentBrightness = Brightness.light;

  /// The current theme mode.
  ThemeMode _currentThemeMode = ThemeMode.system;

  @override
  void initState() {
    super.initState();
    ref.listenManual(
      themeSettingsEntryProvider,
      onThemeSettingsEntryChange,
      fireImmediately: true,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final Brightness brightness = MediaQuery.platformBrightnessOf(context);
    if (currentBrightness != brightness) {
      onBrightnessChange(brightness);
    }
  }

  /// Triggered when the platform brightness has changed.
  @protected
  void onBrightnessChange(Brightness brightness) {
    void changeBrightness() => _currentBrightness = brightness;
    if (mounted) {
      setState(changeBrightness);
    } else {
      changeBrightness();
    }
  }

  /// Triggered when [themeSettingsEntryProvider] has changed.
  @protected
  void onThemeSettingsEntryChange(AsyncValue<ThemeMode>? previous, AsyncValue<ThemeMode> next) {
    final ThemeMode themeMode = next.value ?? ThemeMode.system;
    void changeThemeMode() => _currentThemeMode = themeMode;
    if (mounted) {
      setState(changeThemeMode);
    } else {
      changeThemeMode();
    }
  }

  /// Returns the current brightness.
  Brightness get currentBrightness => switch (_currentThemeMode) {
    ThemeMode.system => _currentBrightness,
    ThemeMode.light => Brightness.light,
    ThemeMode.dark => Brightness.dark,
  };
}
