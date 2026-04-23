import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_authenticator/model/app_unlock/methods/method.dart';
import 'package:open_authenticator/model/app_unlock/reason.dart';
import 'package:open_authenticator/model/settings/entry.dart';
import 'package:open_authenticator/utils/result.dart';
import 'package:open_authenticator/utils/shared_preferences_with_prefix.dart';
import 'package:simple_secure_storage/simple_secure_storage.dart';

/// The app unlock method settings entry provider.
final appUnlockMethodSettingsEntryProvider = AsyncNotifierProvider.autoDispose<AppUnlockMethodSettingsEntry, String>(AppUnlockMethodSettingsEntry.new);

/// A settings entry that allows to get and set the app unlock method.
class AppUnlockMethodSettingsEntry extends SettingsEntry<String> {
  /// Creates a new app unlock settings entry instance.
  AppUnlockMethodSettingsEntry()
    : super(
        key: 'appUnlockMethod',
        defaultValue: NoneAppUnlockMethod.kMethodId,
      );

  @override
  Future<String> loadFromPreferences(SharedPreferencesWithPrefix preferences) async {
    if (!preferences.containsKey(key)) {
      return defaultValue;
    }
    String value = await super.loadFromPreferences(preferences);
    if (value != NoneAppUnlockMethod.kMethodId) {
      return value;
    }
    String? secureValue = await SimpleSecureStorage.read(key);
    if (secureValue == null) {
      return value;
    }
    if (secureValue != NoneAppUnlockMethod.kMethodId) {
      saveToPreferences(preferences, secureValue);
      return secureValue;
    }
    return value;
  }

  /// Tries to unlock the app with the current method, handling errors.
  /// Errors may contain a [CannotUnlockException] if unlock has failed for a specific reason.
  Future<Result> unlockWithCurrentMethod(BuildContext context, UnlockReason unlockReason, {bool? allowNone}) async {
    try {
      return _tryUnlockWithCurrentMethod(context, unlockReason, allowNone: allowNone);
    } catch (ex, stackTrace) {
      return ResultError(
        exception: ex,
        stackTrace: stackTrace,
      );
    }
  }

  /// Tries to unlock the app with the current method.
  Future<Result> _tryUnlockWithCurrentMethod(BuildContext context, UnlockReason unlockReason, {bool? allowNone}) async {
    allowNone ??= unlockReason != UnlockReason.sensibleAction;
    String unlockMethodId = await future;
    if (!allowNone && unlockMethodId == NoneAppUnlockMethod.kMethodId) {
      unlockMethodId = MasterPasswordAppUnlockMethod.kMethodId;
    }
    if (!context.mounted) {
      return const ResultCancelled();
    }
    AppUnlockMethod? unlockMethod = ref.read(appUnlockMethodProvider(unlockMethodId));
    if (unlockMethod == null) {
      return const ResultCancelled();
    }
    Result result = await unlockMethod.unlock(context, unlockReason);
    return result;
  }

  /// Changes the entry value but check for unlock success before.
  Future<Result> changeValueIfUnlockSucceed(String newMethodId, BuildContext context) async {
    String currentMethodId = await future;
    if (!context.mounted) {
      return const ResultCancelled();
    }
    AppUnlockMethod? currentMethod = ref.read(appUnlockMethodProvider(currentMethodId));
    if (currentMethod == null) {
      return const ResultCancelled();
    }
    Result disableResult = await currentMethod.unlock(context, UnlockReason.disable);
    if (disableResult is! ResultSuccess) {
      return disableResult;
    }
    if (!context.mounted) {
      return const ResultCancelled();
    }
    AppUnlockMethod? newMethod = ref.read(appUnlockMethodProvider(newMethodId));
    if (newMethod == null) {
      return const ResultCancelled();
    }
    Result enableResult = await newMethod.unlock(context, UnlockReason.enable);
    if (enableResult is! ResultSuccess) {
      return enableResult;
    }
    await changeValue(newMethodId, enableResult: enableResult, disableResult: disableResult);
    return const ResultSuccess();
  }

  @override
  Future<void> changeValue(String value, {ResultSuccess? enableResult, ResultSuccess? disableResult}) async {
    switch (value) {
      case NoneAppUnlockMethod.kMethodId:
        await SimpleSecureStorage.delete(key);
        break;
      case LocalAuthenticationAppUnlockMethod.kMethodId:
      case MasterPasswordAppUnlockMethod.kMethodId:
        await SimpleSecureStorage.write(key, value);
        break;
      default:
        return;
    }
    AppUnlockMethod? currentMethod = ref.read(appUnlockMethodProvider(await future));
    AppUnlockMethod newMethod = ref.read(appUnlockMethodProvider(value))!;
    await newMethod.onMethodChosen(enableResult: enableResult);
    await currentMethod?.onMethodChanged(disableResult: disableResult);
    await super.changeValue(value);
  }
}
