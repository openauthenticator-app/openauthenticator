import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'package:open_authenticator/i18n/localizable_exception.dart';
import 'package:open_authenticator/i18n/translations.g.dart';
import 'package:open_authenticator/model/migrator/migrator.dart';
import 'package:open_authenticator/model/settings/storage_type.dart';
import 'package:open_authenticator/pages/settings/page.dart';
import 'package:open_authenticator/spacing.dart';
import 'package:open_authenticator/utils/account.dart';
import 'package:open_authenticator/utils/result/handler.dart';
import 'package:open_authenticator/utils/result/result.dart';
import 'package:open_authenticator/widgets/app_scaffold.dart';
import 'package:open_authenticator/widgets/blur.dart';
import 'package:open_authenticator/widgets/button_text.dart';
import 'package:open_authenticator/widgets/clickable.dart';
import 'package:open_authenticator/widgets/dialog/error_dialog.dart';
import 'package:open_authenticator/widgets/waiting_overlay.dart';

/// The widget that asks the user to migrate its data.
class Migrator extends ConsumerWidget {
  /// The child.
  final Widget child;

  /// Creates a new migrator widget instance.
  const Migrator({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    AsyncValue<MigrationState> migrationState = ref.watch(migratorProvider);
    return switch (migrationState) {
      AsyncData(:final value) => switch (value) {
        .needed => AppScaffold(
          center: true,
          padding: .zero,
          children: [
            Blur(
              above: Padding(
                padding: context.theme.style.pagePadding,
                child: Center(
                  child: ListView(
                    shrinkWrap: true,
                    padding: context.theme.style.pagePadding,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: kBigSpace),
                        child: Text(
                          translations.migrator.title,
                          textAlign: TextAlign.center,
                          style: context.theme.typography.xl2,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(bottom: kBigSpace),
                        child: Text(
                          translations.migrator.message,
                          textAlign: TextAlign.center,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(bottom: kSpace),
                        child: SizedBox(
                          width: math.min(MediaQuery.sizeOf(context).width - kBigSpace, 300),
                          child: ClickableButton(
                            onPress: () => _migrate(context, ref),
                            prefix: const Icon(FIcons.cloudSync),
                            child: ButtonText(translations.migrator.button.migrate),
                          ),
                        ),
                      ),
                      SizedBox(
                        width: math.min(MediaQuery.sizeOf(context).width - kBigSpace, 300),
                        child: ClickableButton(
                          variant: .destructive,
                          onPress: () async {
                            await showWaitingOverlay(
                              context,
                              future: ref.read(migratorProvider.notifier).markMigrated(),
                            );
                          },
                          prefix: const Icon(FIcons.cloudAlert),
                          child: ButtonText(translations.migrator.button.dontMigrate),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              below: child,
            ),
          ],
        ),
        .notNeeded || .done => child,
      },
      _ => child,
    };
  }

  /// Migrates the data.
  Future<void> _migrate(BuildContext context, WidgetRef ref) async {
    Result<StorageType> result = await showWaitingOverlay(
      context,
      future: ref.read(migratorProvider.notifier).migrate(),
    );
    if (!context.mounted) {
      return;
    }
    switch (result) {
      case ResultSuccess(:final valueOrNull):
        handleResult(context, result);
        if (valueOrNull == .shared) {
          Navigator.pushNamed(context, SettingsPage.name);
          await AccountUtils.tryRequestSignIn(context);
        }
        break;
      case ResultError(:final exception, :final stackTrace):
        ErrorDialogResult? errorResult = await ErrorDialog.openDialog(
          context,
          message: exception is LocalizableException ? exception.localizedErrorMessage : translations.error.migrator.message,
          error: exception,
          stackTrace: stackTrace,
        );
        if (errorResult == .retry && context.mounted) {
          await _migrate(context, ref);
        }
        break;
      default:
        break;
    }
  }
}
