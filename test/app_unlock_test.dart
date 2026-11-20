import 'dart:async';

import 'package:flutter/widgets.dart' show AppLifecycleState;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_authenticator/core/app_unlock/interaction.dart';
import 'package:open_authenticator/core/app_unlock/local_authentication/default.dart';
import 'package:open_authenticator/core/app_unlock/methods/method.dart';
import 'package:open_authenticator/core/app_unlock/reason.dart';
import 'package:open_authenticator/core/app_unlock/state.dart';
import 'package:open_authenticator/core/settings/app_unlock_method.dart';
import 'package:open_authenticator/utils/result/result.dart';

/// Keeps a simulated authentication prompt open until the test dismisses it.
class _PromptSettings extends AppUnlockMethodSettingsEntry {
  /// Signals that the first prompt has opened.
  final opened = Completer<void>();

  /// Completes when the user dismisses the prompt.
  final dismissed = Completer<void>();

  /// Counts authentication prompts shown to the user.
  int calls = 0;

  /// Selects the local authentication method.
  @override
  String build() => LocalAuthenticationAppUnlockMethod.kMethodId;

  /// Opens a simulated native prompt and waits for cancellation.
  @override
  Future<Result> unlockWithCurrentMethod(AppUnlockInteraction interaction, UnlockReason unlockReason, {bool? allowNone}) async {
    calls++;
    if (!opened.isCompleted) {
      opened.complete();
    }
    await dismissed.future;
    return const ResultCancelled();
  }
}

/// Represents an interaction with an active application window.
class _Interaction extends Fake implements AppUnlockInteraction {
  /// Allows authentication prompts to open.
  @override
  bool get canInteract => true;
}

/// Checks overlapping unlock requests against an open authentication prompt.
void main() {
  testWidgets('a background mobile app waits for foreground interaction before presenting biometrics', (tester) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    try {
      expect(await LocalAuthenticationDefault().authenticate(UnlockReason.openApp), isFalse);
    } finally {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    }
  });

  test('simultaneous unlock requests open one prompt and cancellation keeps the vault locked', () async {
    final settings = _PromptSettings();
    final container = ProviderContainer.test(overrides: [appUnlockMethodSettingsEntryProvider.overrideWith(() => settings)]);
    expect(await container.read(appLockStateProvider.future), AppLockState.locked);
    final AppLockStateNotifier lock = container.read(appLockStateProvider.notifier);
    final Future<Result> first = lock.unlock(_Interaction());
    final Future<Result> second = lock.unlock(_Interaction());
    await settings.opened.future;
    settings.dismissed.complete();
    expect(await Future.wait([first, second]), everyElement(isA<ResultCancelled>()));
    expect(settings.calls, 1);
    expect(await container.read(appLockStateProvider.future), AppLockState.locked);
  });
}
