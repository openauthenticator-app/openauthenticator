import 'dart:async';
import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:open_authenticator/utils/result/reporter.dart';
import 'package:open_authenticator/widgets/centered_circular_progress_indicator.dart';
import 'package:open_authenticator/widgets/scan/scanner_button_widgets.dart';
import 'package:open_authenticator/widgets/scan/scanner_error_widget.dart';

/// A QR code scanner widget.
class QrCodeScanner extends StatefulWidget {
  /// Triggered when a barcode has been scanned.
  final Future<bool> Function(String barcodeValue)? onScan;

  /// Triggered when an error occurred.
  final Function(Object ex, StackTrace stackTrace)? onError;

  /// The placeholder builder.
  final WidgetBuilder placeholderBuilder;

  /// Creates a new barcode scanner instance.
  const QrCodeScanner({
    super.key,
    this.onScan,
    this.onError,
    this.placeholderBuilder = _defaultPlaceholderBuilder,
  });

  @override
  State<StatefulWidget> createState() => _QrCodeScannerState();

  /// The default placeholder builder.
  static Widget _defaultPlaceholderBuilder(BuildContext context) => const CenteredCircularProgressIndicator();
}

/// The QR code scanner state.
class _QrCodeScannerState extends State<QrCodeScanner> {
  /// The mobile scanner controller.
  final MobileScannerController controller = MobileScannerController(
    formats: const [
      BarcodeFormat.qrCode,
    ],
  );

  /// Whether a barcode callback is stopping or restarting the camera.
  bool _handlingScan = false;

  /// Builds the scanner with its actual preview constraints.
  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: _buildScanner);

  /// Fits the scan window and its overlay to the same preview.
  Widget _buildScanner(BuildContext context, BoxConstraints constraints) {
    final Size size = constraints.biggest;
    final Rect scanWindow = Rect.fromCenter(
      center: size.center(Offset.zero),
      width: math.min(200, size.width),
      height: math.min(200, size.height),
    );
    return Stack(
      fit: StackFit.expand,
      children: [
        Center(
          child: MobileScanner(
            placeholderBuilder: widget.placeholderBuilder,
            onDetect: _onDetect,
            onDetectError: widget.onError ?? printException,
            fit: BoxFit.contain,
            controller: controller,
            scanWindow: scanWindow,
            errorBuilder: (context, error) => ScannerErrorWidget(error: error),
          ),
        ),
        ScanWindowOverlay(
          controller: controller,
          scanWindow: scanWindow,
          borderRadius: BorderRadius.circular(12),
          borderWidth: 4,
        ),
        Positioned(
          top: kToolbarHeight,
          left: 0,
          right: 0,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ToggleFlashlightButton(controller: controller),
                SwitchCameraButton(controller: controller),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Handles one barcode at a time and resumes only while the scanner is mounted.
  Future<void> _onDetect(BarcodeCapture capture) async {
    final String? value = capture.barcodes.firstOrNull?.rawValue;
    final Future<bool> Function(String)? onScan = widget.onScan;
    if (_handlingScan || value == null || onScan == null) {
      return;
    }
    _handlingScan = true;
    try {
      await controller.stop();
      if (mounted && await onScan(value)) {
        await Future<void>.delayed(const Duration(seconds: 2));
        if (mounted) {
          await controller.start();
        }
      }
    } catch (error, stackTrace) {
      if (mounted) {
        (widget.onError ?? printException)(error, stackTrace);
      }
    } finally {
      _handlingScan = false;
    }
  }

  /// Releases the camera controller when the scanner closes.
  @override
  void dispose() {
    unawaited(controller.dispose());
    super.dispose();
  }
}
