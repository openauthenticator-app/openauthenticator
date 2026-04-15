import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'package:open_authenticator/app.dart';
import 'package:open_authenticator/i18n/translations.g.dart';
import 'package:open_authenticator/model/app_unlock/methods/method.dart';
import 'package:open_authenticator/model/app_unlock/state.dart';
import 'package:open_authenticator/model/password_verification/methods/method.dart';
import 'package:open_authenticator/model/password_verification/password_verification.dart';
import 'package:open_authenticator/model/settings/app_unlock_method.dart';
import 'package:open_authenticator/spacing.dart';
import 'package:open_authenticator/utils/master_password.dart';
import 'package:open_authenticator/utils/result.dart';
import 'package:open_authenticator/widgets/app_scaffold.dart';
import 'package:open_authenticator/widgets/blur.dart';
import 'package:open_authenticator/widgets/button_text.dart';
import 'package:open_authenticator/widgets/clickable.dart';
import 'package:open_authenticator/widgets/dialog/text_input_dialog.dart';
import 'package:open_authenticator/widgets/title_text.dart';

/// The unlock challenge widget.
class UnlockChallenge extends ConsumerStatefulWidget {
  /// The child widget.
  final Widget child;

  /// Creates a new unlock challenge widget instance.
  const UnlockChallenge({
    super.key,
    required this.child,
  });

  @override
  ConsumerState<ConsumerStatefulWidget> createState() => _UnlockChallengeState();
}

/// The master password unlock route widget state.
class _UnlockChallengeState extends ConsumerState<UnlockChallenge> {
  /// Will be non-null if the app cannot be unlocked for a specific reason.
  CannotUnlockException? cannotUnlockException;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      tryUnlockIfNeeded();
    });
  }

  @override
  Widget build(BuildContext context) {
    AsyncValue<AppLockState> appLockState = ref.watch(appLockStateProvider);
    return switch (appLockState) {
      AsyncData<AppLockState>(:final value) =>
        value == .unlocked
            ? widget.child
            : AppScaffold(
                padding: .zero,
                children: [
                  Blur(
                    above: switch (cannotUnlockException) {
                      LocalAuthenticationDeviceNotSupported(:final localizedErrorMessage) => _UnlockChallengeContent(
                        text: localizedErrorMessage,
                        buttonIcon: FIcons.x,
                        buttonLabel: translations.appUnlock.button.disable,
                        onButtonPress: () async {
                          List<PasswordVerificationMethod> passwordVerificationMethod = await ref.read(passwordVerificationProvider.future);
                          if (passwordVerificationMethod.isNotEmpty) {
                            String? password = context.mounted ? (await MasterPasswordInputDialog.prompt(context)) : null;
                            if (password == null) {
                              return;
                            }
                          }
                          await ref.read(appUnlockMethodSettingsEntryProvider.notifier).changeValue(NoneAppUnlockMethod.kMethodId);
                          await tryUnlockIfNeeded();
                        },
                      ),
                      MasterPasswordNoPasswordVerificationMethodAvailable(:final localizedErrorMessage) || MasterPasswordNoSalt(:final localizedErrorMessage) => _UnlockChallengeContent(
                        text: localizedErrorMessage,
                        buttonIcon: FIcons.keyRound,
                        buttonLabel: translations.appUnlock.button.changeMasterPassword,
                        onButtonPress: () async {
                          Result<String> changeResult = await MasterPasswordUtils.changeMasterPassword(context, ref, askForUnlock: false);
                          if (changeResult is ResultSuccess<String>) {
                            await ref.read(appUnlockMethodSettingsEntryProvider.notifier).changeValue(NoneAppUnlockMethod.kMethodId, disableResult: changeResult);
                            await tryUnlockIfNeeded();
                          }
                        },
                      ),
                      _ => _UnlockChallengeContent(
                        text: translations.appUnlock.widget(app: App.appName),
                        buttonIcon: FIcons.keyRound,
                        buttonLabel: translations.appUnlock.button.unlock,
                        onButtonPress: value == AppLockState.unlockChallengedStarted ? null : tryUnlockIfNeeded,
                      ),
                    },
                    below: widget.child,
                  ),
                ],
              ),
      _ => widget.child,
    };
  }

  /// Tries to unlock the app.
  Future<void> tryUnlockIfNeeded() async {
    AppLockState lockState = await ref.read(appLockStateProvider.future);
    if (!mounted || lockState != AppLockState.locked) {
      return;
    }
    Result result = await ref.read(appLockStateProvider.notifier).unlock(context);
    if (!mounted || result is! ResultError) {
      return;
    }
    if (result.exception is CannotUnlockException) {
      setState(() => cannotUnlockException = result.exception as CannotUnlockException);
    } else {
      context.handleResult(result, showDialogIfError: (_) => false);
    }
  }
}

/// The content of [UnlockChallenge].
class _UnlockChallengeContent extends StatelessWidget {
  /// The text to display.
  final String text;

  /// The action button label.
  final String buttonLabel;

  /// The action button icon.
  final IconData? buttonIcon;

  /// Triggered when the action button has been pressed.
  final VoidCallback? onButtonPress;

  /// Creates a new unlock challenge widget content instance.
  const _UnlockChallengeContent({
    required this.text,
    required this.buttonLabel,
    this.buttonIcon,
    this.onButtonPress,
  });

  @override
  Widget build(BuildContext context) => Center(
    child: ListView(
      padding: context.theme.style.pagePadding,
      shrinkWrap: true,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: kBigSpace),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: TitleText(
              textAlign: TextAlign.center,
              textStyle: context.theme.typography.xl2,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: kBigSpace),
          child: Text(
            text,
            textAlign: TextAlign.center,
          ),
        ),
        SizedBox(
          width: math.min(MediaQuery.sizeOf(context).width - kBigSpace, 300),
          child: ClickableButton(
            onPress: onButtonPress,
            prefix: buttonIcon == null ? null : Icon(buttonIcon),
            child: ButtonText(buttonLabel),
          ),
        ),
      ],
    ),
  );
}
