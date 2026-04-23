import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The AppLinks listener provider.
final appLinksListenerProvider = AsyncNotifierProvider<AppLinksListener, Uri?>(AppLinksListener.new);

/// Allows to listen to [AppLinks].
class AppLinksListener extends AsyncNotifier<Uri?> {
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
      state = AsyncData(uri);
    }
  }
}
