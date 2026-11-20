import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:open_authenticator/core/app_unlock/interaction.dart';
import 'package:open_authenticator/core/app_unlock/methods/method.dart';
import 'package:open_authenticator/core/app_unlock/state.dart';
import 'package:open_authenticator/themes.dart';
import 'package:open_authenticator/utils/platform.dart';
import 'package:open_authenticator/utils/result/result.dart';
import 'package:open_authenticator/widgets/unlock_challenge.dart';

/// Keeps the app locked and counts unlock attempts.
class _LockedApp extends AppLockStateNotifier {
  /// Called during each unlock attempt, while the prompt would be displayed.
  final void Function(int attempt) onAttempt;

  /// The number of unlock attempts.
  int attempts = 0;

  /// Creates a new locked app instance.
  _LockedApp({
    required this.onAttempt,
  });

  /// Starts locked.
  @override
  AppLockState build() => AppLockState.locked;

  /// Counts the attempt, as if the prompt had been cancelled.
  @override
  Future<Result> unlock(AppUnlockInteraction interaction) async {
    attempts++;
    onAttempt(attempts);
    return const ResultCancelled();
  }
}

/// Lets the asynchronous unlock attempts run.
Future<void> _settle(WidgetTester tester) async {
  for (int i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// Checks when the unlock challenge automatically asks for an unlock.
void main() {
  testWidgets('the automatic unlock is retried once when the app went to the background meanwhile', (tester) async {
    final Platform previousPlatform = currentPlatform;
    currentPlatform = Platform.android;
    addTearDown(() => currentPlatform = previousPlatform);
    addTearDown(() => tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed));

    // The user leaves the app while the first prompt is being opened.
    final lockedApp = _LockedApp(
      onAttempt: (attempt) {
        if (attempt == 1) {
          tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
          tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
          tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        }
      },
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appLockStateProvider.overrideWith(() => lockedApp)],
        child: MaterialApp(
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          builder: (context, child) => FTheme(
            data: greenTheme.light.touch,
            child: FToaster(child: child!),
          ),
          home: const UnlockChallenge(child: SizedBox()),
        ),
      ),
    );
    await _settle(tester);
    expect(lockedApp.attempts, 1);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await _settle(tester);
    expect(lockedApp.attempts, 2);

    // A later resume (eg. after the prompt has been cancelled) must not reopen the prompt.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await _settle(tester);
    expect(lockedApp.attempts, 2);
  });
}
