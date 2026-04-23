import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'package:open_authenticator/i18n/translations.g.dart';
import 'package:open_authenticator/model/backend/authentication/providers/provider.dart';
import 'package:open_authenticator/model/backend/user.dart';
import 'package:open_authenticator/utils/account.dart';
import 'package:open_authenticator/utils/storage_migration.dart';
import 'package:open_authenticator/widgets/clickable.dart';

/// Allows the user to login or logout from the app.
class AccountLogInSettingsEntryWidget extends ConsumerWidget with FTileMixin {
  /// Creates a new account login settings entry widget instance.
  const AccountLogInSettingsEntryWidget({
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    User? user = ref.watch(userProvider).value;
    return user == null ? const _LogInTile() : _LogOutTile(user: user.email ?? user.id);
  }
}

/// The login list tile.
class _LogInTile extends ConsumerWidget {
  /// Creates a new log in list tile instance.
  const _LogInTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    EmailConfirmationData? confirmationData = ref.watch(emailConfirmationStateProvider).value;
    return confirmationData == null
        ? ClickableTile(
            prefix: const Icon(FIcons.logIn),
            title: Text(translations.settings.synchronization.accountLogin.logIn.title),
            subtitle: Text(translations.settings.synchronization.accountLogin.logIn.subtitle),
            onPress: () => AccountUtils.tryRequestSignIn(context),
          )
        : const SizedBox.shrink();
  }
}

/// The logout list tile.
class _LogOutTile extends ConsumerWidget {
  /// The user.
  final String? user;

  /// Creates a new logout list tile instance.
  const _LogOutTile({
    required this.user,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) => ClickableTile(
    prefix: const Icon(FIcons.logOut),
    title: Text(translations.settings.synchronization.accountLogin.logOut.title),
    subtitle: Text.rich(
      translations.settings.synchronization.accountLogin.logOut.subtitle(
        user: TextSpan(
          text: user,
          style: const TextStyle(fontStyle: .italic),
        ),
      ),
    ),
    onPress: () => StorageMigrationUtils.changeStorageType(context, ref, .localOnly, logout: true),
  );
}
