import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_authenticator/core/app_unlock/interaction.dart';
import 'package:open_authenticator/core/app_unlock/methods/method.dart';
import 'package:open_authenticator/core/settings/app_unlock_method.dart';
import 'package:open_authenticator/utils/result/result.dart';

/// The app unlock state state provider.
final appLockStateProvider = AsyncNotifierProvider<AppLockStateNotifier, AppLockState>(AppLockStateNotifier.new);

/// Allows to get and set the app unlocked state.
class AppLockStateNotifier extends AsyncNotifier<AppLockState> {
  @override
  FutureOr<AppLockState> build() async {
    final String unlockMethodId = await ref.watch(appUnlockMethodSettingsEntryProvider.future);
    final AppUnlockMethod unlockMethod = ref.watch(appUnlockMethodProvider(unlockMethodId))!;
    return state.value ?? unlockMethod.defaultAppLockState;
  }

  /// Tries to unlock the app.
  Future<Result> unlock(AppUnlockInteraction interaction) async {
    await future;
    if (!ref.mounted || state.value == .unlockChallengedStarted || !interaction.canInteract) {
      return const ResultCancelled();
    }
    state = const AsyncData(.unlockChallengedStarted);
    final Result result = await ref.read(appUnlockMethodSettingsEntryProvider.notifier).unlockWithCurrentMethod(interaction, .openApp);
    if (!ref.mounted) {
      return const ResultCancelled();
    }
    state = AsyncData(result is ResultSuccess ? .unlocked : .locked);
    return result;
  }
}
