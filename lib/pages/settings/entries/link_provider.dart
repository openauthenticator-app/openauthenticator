import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'package:open_authenticator/i18n/translations.g.dart';
import 'package:open_authenticator/model/backend/authentication/session.dart';
import 'package:open_authenticator/model/backend/user.dart';
import 'package:open_authenticator/pages/settings/entries/widgets.dart';
import 'package:open_authenticator/utils/account.dart';
import 'package:open_authenticator/widgets/clickable.dart';

/// Allows the user to link its account to another provider.
class AccountLinkSettingsEntryWidget extends ConsumerWidget with FTileMixin {
  /// Creates a new account link settings entry widget instance.
  const AccountLinkSettingsEntryWidget({
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    SessionRefreshState sessionRefreshState = ref.watch(sessionRefreshManagerProvider);
    if (sessionRefreshState == .invalidSession) {
      return const SizedBox.shrink();
    }
    User? user = ref.watch(userProvider).value;
    if (user == null) {
      return const SizedBox.shrink();
    }
    List<String> providers = [
      if (user.email != null) 'email',
      if (user.googleId != null) 'google.com',
      if (user.githubId != null) 'github.com',
      if (user.microsoftId != null) 'microsoft.com',
      if (user.appleId != null) 'apple.com',
    ];
    return ClickableTile(
      suffix: const RightChevronSuffix(),
      prefix: const Icon(FIcons.link),
      title: Text(translations.settings.synchronization.accountLink.title),
      subtitle: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: translations.settings.synchronization.accountLink.subtitle.text,
            ),
            if (providers.isNotEmpty)
              translations.settings.synchronization.accountLink.subtitle.linkedProviders(
                providers: TextSpan(
                  children: [
                    for (int i = 0; i < providers.length; i++)
                      TextSpan(
                        text: providers[i],
                        children: [
                          if (i < providers.length - 1)
                            const TextSpan(
                              text: ', ',
                              style: TextStyle(fontStyle: FontStyle.normal),
                            ),
                        ],
                        style: const TextStyle(fontStyle: FontStyle.italic),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
      onPress: () => AccountUtils.tryRequestToggleLink(context),
      enabled: sessionRefreshState != .inProgress,
    );
  }
}
