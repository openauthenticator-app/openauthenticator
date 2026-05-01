import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_authenticator/model/app_unlock/methods/method.dart';
import 'package:open_authenticator/model/app_unlock/reason.dart';
import 'package:open_authenticator/model/settings/app_unlock_method.dart';
import 'package:open_authenticator/utils/result/result.dart';

/// The app unlock state state provider.
final appLockStateProvider = AsyncNotifierProvider<AppLockStateNotifier, AppLockState>(AppLockStateNotifier.new);

/// Allows to get and set the app unlocked state.
class AppLockStateNotifier extends AsyncNotifier<AppLockState> {
  @override
  FutureOr<AppLockState> build() async {
    String unlockMethodId = await ref.watch(appUnlockMethodSettingsEntryProvider.future);
    AppUnlockMethod unlockMethod = ref.watch(appUnlockMethodProvider(unlockMethodId))!;
    return state.value ?? unlockMethod.defaultAppLockState;
  }

  /// Tries to unlock the app.
  Future<Result> unlock(BuildContext context) async {
    if ((await future) == .unlockChallengedStarted || !context.mounted) {
      return const ResultCancelled();
    }
    if (!ref.mounted) {
      return const ResultCancelled();
    }
    state = const AsyncData(.unlockChallengedStarted);
    Result result = await ref.read(appUnlockMethodSettingsEntryProvider.notifier).unlockWithCurrentMethod(context, UnlockReason.openApp);
    if (!ref.mounted) {
      return const ResultCancelled();
    }
    state = AsyncData(result is ResultSuccess ? .unlocked : .locked);
    return result;
  }
}
