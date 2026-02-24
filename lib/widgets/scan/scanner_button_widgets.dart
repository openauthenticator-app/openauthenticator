import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:open_authenticator/widgets/clickable.dart';

/// The button that allows to switch camera.
class SwitchCameraButton extends StatelessWidget {
  /// The mobile scanner controller instance.
  final MobileScannerController controller;

  /// Creates a new switch camera button instance.
  const SwitchCameraButton({
    required this.controller,
    super.key,
  });

  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
    valueListenable: controller,
    builder: (context, state, child) {
      if (!state.isInitialized || !state.isRunning) {
        return const SizedBox.shrink();
      }

      int? availableCameras = state.availableCameras;

      if (availableCameras != null && availableCameras < 2) {
        return const SizedBox.shrink();
      }

      return ClickableButton.icon(
        variant: .secondary,
        onPress: controller.switchCamera,
        child: const Icon(FIcons.switchCamera),
      );
    },
  );
}

/// The button that allows to toggle the flashlight.
class ToggleFlashlightButton extends StatelessWidget {
  /// The mobile scanner controller instance.
  final MobileScannerController controller;

  /// Creates a new toggle flashlight button instance.
  const ToggleFlashlightButton({
    super.key,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
    valueListenable: controller,
    builder: (context, state, child) => state.isInitialized && state.isRunning
        ? switch (state.torchState) {
            TorchState.auto => ClickableButton.icon(
              variant: .secondary,
              onPress: controller.toggleTorch,
              child: const Icon(FIcons.sparkles),
            ),
            TorchState.off => ClickableButton.icon(
              variant: .secondary,
              onPress: controller.toggleTorch,
              child: const Icon(FIcons.zapOff),
            ),
            TorchState.on => ClickableButton.icon(
              variant: .secondary,
              onPress: controller.toggleTorch,
              child: const Icon(FIcons.zap),
            ),
            TorchState.unavailable => ClickableButton.icon(
              variant: .secondary,
              onPress: null,
              child: const Icon(Icons.flash_off),
            ),
          }
        : const SizedBox.shrink(),
  );
}
