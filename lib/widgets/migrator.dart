import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'package:open_authenticator/i18n/translations.g.dart';
import 'package:open_authenticator/model/migrator/migrator.dart';
import 'package:open_authenticator/spacing.dart';
import 'package:open_authenticator/utils/account.dart';
import 'package:open_authenticator/utils/result.dart';
import 'package:open_authenticator/widgets/app_scaffold.dart';
import 'package:open_authenticator/widgets/blur.dart';
import 'package:open_authenticator/widgets/button_text.dart';
import 'package:open_authenticator/widgets/clickable.dart';
import 'package:open_authenticator/widgets/dialog/error_dialog.dart';
import 'package:open_authenticator/widgets/waiting_overlay.dart';

class Migrator extends ConsumerWidget {
  final Widget child;

  const Migrator({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    AsyncValue<MigrationState> migrationState = ref.watch(migratorProvider);
    return switch (migrationState) {
      AsyncData(:final value) => switch (value) {
        MigrationState.needed => AppScaffold(
          center: true,
          children: [
            Blur(
              above: Center(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: kBigSpace),
                      child: Text(
                        translations.migrator.title,
                        textAlign: TextAlign.center,
                        style: context.theme.typography.lg,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: kBigSpace),
                      child: Text(
                        translations.migrator.message,
                        textAlign: TextAlign.center,
                      ),
                    ),
                    SizedBox(
                      width: math.min(MediaQuery.sizeOf(context).width - kBigSpace, 300),
                      child: ClickableButton(
                        onPress: () async {
                          Result result = await showWaitingOverlay(
                            context,
                            future: ref.read(migratorProvider.notifier).migrate(),
                          );
                          if (!context.mounted) {
                            return;
                          }
                          switch (result) {
                            case ResultSuccess():
                              context.handleResult(result);
                              await AccountUtils.trySignIn(context);
                              break;
                            case ResultError():
                              await ErrorDialog.openDialog(
                                context,
                                message: translations.migrator.error,
                                error: result.exception,
                                stackTrace: result.stackTrace,
                              );
                              break;
                            default:
                              break;
                          }
                        },
                        prefix: const Icon(FIcons.cloudSync),
                        child: ButtonText(translations.migrator.button.migrate),
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
              below: child,
            ),
          ],
        ),
        MigrationState.notNeeded || MigrationState.done => child,
      },
      _ => child,
    };
  }
}
