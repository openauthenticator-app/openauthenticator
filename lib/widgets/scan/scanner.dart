import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:open_authenticator/utils/utils.dart';
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
  /// The mobile scanner controller controller.
  MobileScannerController controller = MobileScannerController(
    formats: const [
      BarcodeFormat.qrCode,
    ],
  );

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.sizeOf(context);
    Rect scanWindow = Rect.fromCenter(
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
            onDetect: (barcodes) {
              String? barcodeValue = barcodes.barcodes.firstOrNull?.rawValue;
              if (barcodeValue != null && widget.onScan != null) {
                controller.stop();
                widget.onScan!(barcodeValue).then((resume) async {
                  if (resume) {
                    await Future.delayed(const Duration(seconds: 2));
                    controller.start();
                  }
                });
              }
            },
            onDetectError: widget.onError ?? handleException,
            fit: BoxFit.contain,
            controller: controller,
            scanWindow: scanWindow,
            errorBuilder: (context, error) => ScannerErrorWidget(error: error),
          ),
        ),
        ValueListenableBuilder(
          valueListenable: controller,
          builder: (context, value, child) {
            if (!value.isInitialized || !value.isRunning || value.error != null) {
              return const SizedBox();
            }

            return CustomPaint(
              painter: ScannerOverlay(scanWindow: scanWindow),
            );
          },
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

  @override
  Future<void> dispose() async {
    controller.dispose();
    super.dispose();
  }
}

/// The scanner overlay.
class ScannerOverlay extends CustomPainter {
  /// The scan window instance.
  final Rect scanWindow;

  /// The border radius.
  final double borderRadius;

  /// Creates a new scanner overlay instance.
  const ScannerOverlay({
    required this.scanWindow,
    this.borderRadius = 12.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    Path backgroundPath = Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));

    Path cutoutPath = Path()
      ..addRRect(
        RRect.fromRectAndCorners(
          scanWindow,
          topLeft: Radius.circular(borderRadius),
          topRight: Radius.circular(borderRadius),
          bottomLeft: Radius.circular(borderRadius),
          bottomRight: Radius.circular(borderRadius),
        ),
      );

    Paint backgroundPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.5)
      ..style = PaintingStyle.fill
      ..blendMode = BlendMode.dstOver;

    Path backgroundWithCutout = Path.combine(
      PathOperation.difference,
      backgroundPath,
      cutoutPath,
    );

    Paint borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0;

    RRect borderRect = RRect.fromRectAndCorners(
      scanWindow,
      topLeft: Radius.circular(borderRadius),
      topRight: Radius.circular(borderRadius),
      bottomLeft: Radius.circular(borderRadius),
      bottomRight: Radius.circular(borderRadius),
    );

    canvas.drawPath(backgroundWithCutout, backgroundPaint);
    canvas.drawRRect(borderRect, borderPaint);
  }

  @override
  bool shouldRepaint(ScannerOverlay oldDelegate) => scanWindow != oldDelegate.scanWindow || borderRadius != oldDelegate.borderRadius;
}
