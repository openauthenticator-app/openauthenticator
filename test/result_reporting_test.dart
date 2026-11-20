import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_authenticator/core/backend/request/error.dart';
import 'package:open_authenticator/utils/result/handler.dart';
import 'package:open_authenticator/utils/result/result.dart';
import 'package:open_authenticator/utils/sentry.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

/// Checks which user-visible errors are forwarded to crash reporting.
void main() {
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
