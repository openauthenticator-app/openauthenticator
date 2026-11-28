import 'dart:async';
import 'dart:io';

import 'package:dbus/dbus.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:open_authenticator/core/backend/request/error.dart';
import 'package:open_authenticator/utils/result/handler.dart';
import 'package:open_authenticator/utils/result/reporter.dart';
import 'package:open_authenticator/utils/result/result.dart';
import 'package:open_authenticator/utils/sentry.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

/// Checks which user-visible errors are forwarded to crash reporting.
void main() {
  test('environment failures are not reported, unlike unexpected platform errors', () {
    for (final Object ex in [
      const SocketException('Connection reset by peer'),
      const HandshakeException('CERTIFICATE_VERIFY_FAILED'),
      http.ClientException('Connection closed before full header was received'),
      TimeoutException('fixture'),
      PlatformException(code: 'Clipboard error', message: 'Unable to get clipboard data'),
      PlatformException(code: 'error', message: 'No active stream to cancel'),
      DBusAccessDeniedException(DBusMethodErrorResponse.accessDenied('An AppArmor policy prevents this sender from sending this message to this recipient; destination="org.freedesktop.NetworkManager"')),
      DBusServiceUnknownException(DBusMethodErrorResponse('org.freedesktop.DBus.Error.ServiceUnknown', [const DBusString('The name org.freedesktop.NetworkManager was not provided by any .service files')])),
    ]) {
      expect(isReportableException(ex), isFalse, reason: '$ex');
    }
    expect(isReportableException(PlatformException(code: 'write_error')), isTrue);
    expect(isReportableException(PlatformException(code: 'error', message: 'No active stream to listen')), isTrue);
    expect(isReportableException(DBusAccessDeniedException(DBusMethodErrorResponse.accessDenied('destination="org.freedesktop.secrets"'))), isTrue);
    expect(isReportableException(StateError('fixture')), isTrue);
  });

  testWidgets('an expired verification code stays out of Sentry while unexpected failures are reported', (tester) async {
    late BuildContext context;
    await tester.pumpWidget(
      Builder(
        builder: (value) {
          context = value;
          return const SizedBox();
        },
      ),
    );
    await tester.runAsync(() async {
      final seen = <Object?>[];
      final captured = Completer<void>();
      final bool previous = kSentryEnabled;
      kSentryEnabled = true;
      try {
        await Sentry.init((options) {
          options.dsn = 'https://example@example.invalid/1';
          options.beforeSend = (event, hint) {
            seen.add(event.throwable);
            if (event.throwable is StateError) {
              captured.complete();
            }
            return null;
          };
        });
        final BackendRequestError expired = BackendRequestError.fromJson(
          route: '/auth/provider/email/login',
          statusCode: 400,
          json: {
            'data': {'errorCode': 'expiredCode'},
          },
        );
        handleResult(context, ResultError(exception: expired), presentation: .none);
        final failure = StateError('fixture');
        handleResult(context, ResultError(exception: failure), presentation: .none);
        await captured.future.timeout(const Duration(seconds: 5));
        expect(seen, [failure]);
      } finally {
        kSentryEnabled = previous;
        await Sentry.close();
      }
    });
  });
}
