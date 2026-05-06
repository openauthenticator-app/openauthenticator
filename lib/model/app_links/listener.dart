import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_authenticator/model/app_links/openauthenticator.dart';
import 'package:open_authenticator/model/app_links/otpauth_totp.dart';

/// The AppLinks listener provider.
final appLinksListenerProvider = AsyncNotifierProvider<AppLinksListener, Uri?>(AppLinksListener.new);

/// Allows to listen to [AppLinks].
class AppLinksListener extends AsyncNotifier<Uri?> {
  /// The consumed links.
  final Set<String> _consumedLinks = {};

  @override
  Future<Uri?> build() {
    AppLinks appLinks = AppLinks();
    StreamSubscription subscription = appLinks.uriLinkStream.listen(provideLink);
    ref.onDispose(subscription.cancel);
    return appLinks.getInitialLink();
  }

  /// Manually provides the [uri].
  void provideLink(Uri uri) {
    if (ref.mounted) {
      if ((uri as OtpAuthTotpLink).isValid) {
        uri = OtpAuthTotpLink(uri);
      } else if ((uri as OpenAuthenticatorAppLink).isValid) {
        uri = OpenAuthenticatorAppLink(uri);
      }
      state = AsyncData(uri);
    }
  }

  /// Consumes the [uri], returning whether it had not been consumed before.
  bool consumeLink(Uri uri) => _consumedLinks.add(uri.toString());
}
