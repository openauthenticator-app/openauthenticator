import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'package:open_authenticator/i18n/translations.g.dart';
import 'package:open_authenticator/pages/totp.dart';
import 'package:open_authenticator/widgets/app_scaffold.dart';
import 'package:open_authenticator/widgets/clickable.dart';
import 'package:open_authenticator/widgets/dialog/error_dialog.dart';
import 'package:open_authenticator/widgets/scan/scanner.dart';
import 'package:open_authenticator/widgets/toast.dart';
import 'package:open_authenticator/widgets/waiting_overlay.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// Allows to scan QR codes.
class ScanPage extends ConsumerStatefulWidget {
  /// The scan page name.
  static const String name = '/scan';

  /// Creates a new scan page instance.
  const ScanPage({
    super.key,
  });

  @override
  ConsumerState<ConsumerStatefulWidget> createState() => _ScanPageState();
}

/// The scan page state.
class _ScanPageState extends ConsumerState<ScanPage> {
  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  }

  @override
  Widget build(BuildContext context) => AppScaffold(
    header: FHeader.nested(
      prefixes: [
        ClickableHeaderAction.back(
          onPress: () => Navigator.pop(context),
        ),
      ],
      title: Text(translations.home.addDialog.qrCode.title),
    ),
    children: [
      QrCodeScanner(
        onScan: (barcode) async {
          Uri? uri = Uri.tryParse(barcode);
          if (uri == null) {
            showErrorToast(context, text: translations.error.scan.noUri);
            return true;
          }
          await showWaitingOverlay(
            context,
            future: TotpPage.openFromUri(context, ref, uri),
          );
          return false;
        },
        onError: (error, listener) => ErrorDialog.openDialog(
          context,
          error: error,
        ),
      ),
    ],
  );

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations(const []);
    WakelockPlus.disable();
    super.dispose();
  }
}
