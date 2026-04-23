import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:open_authenticator/i18n/translations.g.dart';
import 'package:open_authenticator/spacing.dart';

/// The scanner error widget.
class ScannerErrorWidget extends StatelessWidget {
  /// The error.
  final MobileScannerException error;

  /// Creates a new scanner error widget instance.
  const ScannerErrorWidget({
    super.key,
    required this.error,
  });

  @override
  Widget build(BuildContext context) => Center(
    child: ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.all(kBigSpace),
      children: [
        const Padding(
          padding: .only(bottom: kBigSpace),
          child: Icon(FIcons.circleAlert),
        ),
        Text(
          switch (error.errorCode) {
            .controllerUninitialized => translations.error.scan.controllerUninitialized(exception: error.errorDetails?.details ?? error.errorCode),
            .permissionDenied => translations.error.scan.accessDenied(exception: error.errorDetails?.details ?? error.errorCode),
            .unsupported => translations.error.scan.unsupported(exception: error.errorDetails?.details ?? error.errorCode),
            _ => translations.error.generic.withException(exception: error.errorDetails?.details ?? error.errorCode),
          },
        ),
      ],
    ),
  );
}
