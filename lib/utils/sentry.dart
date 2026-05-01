import 'package:flutter/foundation.dart';
import 'package:open_authenticator/app.dart';

/// Whether Sentry is enabled.
bool kSentryEnabled = !kDebugMode && App.sentryDsn.isNotEmpty;
