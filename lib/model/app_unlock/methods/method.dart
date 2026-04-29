import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart' hide LocalAuthentication;
import 'package:open_authenticator/i18n/localizable_exception.dart';
import 'package:open_authenticator/i18n/translations.g.dart';
import 'package:open_authenticator/model/app_unlock/reason.dart';
import 'package:open_authenticator/model/crypto/salt.dart';
import 'package:open_authenticator/model/crypto/store.dart';
import 'package:open_authenticator/model/password_verification/methods/method.dart';
import 'package:open_authenticator/model/password_verification/methods/password_signature.dart';
import 'package:open_authenticator/model/password_verification/password_verification.dart';
import 'package:open_authenticator/model/totp/repository.dart';
import 'package:open_authenticator/model/totp/totp.dart';
import 'package:open_authenticator/utils/local_authentication/local_authentication.dart';
import 'package:open_authenticator/utils/result.dart';
import 'package:open_authenticator/widgets/dialog/text_input_dialog.dart';

part 'local_auth.dart';
part 'master_password.dart';
part 'none.dart';

/// The app unlock method provider.
final appUnlockMethodProvider = Provider.family<AppUnlockMethod?, String>(
  (ref, id) => switch (id) {
    LocalAuthenticationAppUnlockMethod.kMethodId => LocalAuthenticationAppUnlockMethod._(ref: ref),
    MasterPasswordAppUnlockMethod.kMethodId => MasterPasswordAppUnlockMethod._(ref: ref),
    NoneAppUnlockMethod.kMethodId => NoneAppUnlockMethod._(ref: ref),
    _ => null,
  },
);

/// Allows to unlock the app.
sealed class AppUnlockMethod<T> {
  /// The app unlock method id.
  final String id;

  /// The Riverpod ref instance.
  final Ref _ref;

  /// Creates a new app unlock method instance.
  const AppUnlockMethod({
    required this.id,
    required Ref ref,
  }) : _ref = ref;

  /// Unlock the app, handling errors.
  /// [context] is required so that we can interact with the user.
  Future<Result<T>> unlock(BuildContext context, UnlockReason reason) async {
    try {
      CannotUnlockException? cannotUnlockException = await canUnlock(reason);
      if (cannotUnlockException != null) {
        throw cannotUnlockException;
      }
      if (!context.mounted) {
        return const ResultCancelled();
      }
      return await _tryUnlock(context, reason);
    } catch (ex, stackTrace) {
      if (ex is LocalAuthException) {
        if (ex.code == LocalAuthExceptionCode.userCanceled || ex.code == LocalAuthExceptionCode.systemCanceled) {
          return const ResultCancelled();
        }
      }
      return ResultError(
        exception: ex,
        stackTrace: stackTrace,
      );
    }
  }

  /// Tries to unlock the app.
  /// [context] is required so that we can interact with the user.
  Future<Result<T>> _tryUnlock(BuildContext context, UnlockReason reason);

  /// The default app lock state.
  AppLockState get defaultAppLockState => AppLockState.locked;

  /// Returns whether the app can be unlocked using this method.
  Future<CannotUnlockException?> canUnlock(UnlockReason reason) => Future.value(null);

  /// Triggered when this method has been chosen has the app unlock method.
  /// [unlockResult] is the result of the [tryUnlock] call.
  Future<void> onMethodChosen({ResultSuccess<T>? enableResult}) => Future.value();

  /// Triggered when a new method will be used for app unlocking.
  Future<void> onMethodChanged({ResultSuccess<T>? disableResult}) => Future.value();
}

/// Represents an app state.
enum AppLockState {
  /// If the app is locked, waiting for unlock.
  locked,

  /// If the app has been unlocked.
  unlocked,

  /// If an unlock challenge has started.
  unlockChallengedStarted,
}

/// Will be used if the app cannot be unlocked.
sealed class CannotUnlockException extends LocalizableException {
  /// Creates a new cannot unlock exception instance.
  CannotUnlockException({
    String? localizedErrorMessage,
  }) : super(
         localizedErrorMessage: localizedErrorMessage ?? translations.error.appUnlock.generic,
       );
}
