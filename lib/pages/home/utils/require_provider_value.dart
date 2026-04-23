part of '../page.dart';

/// Allows to require a crypto store, the totp list or both.
class _RequireProviderValueWidget<T, U extends AsyncNotifier<T>> extends ConsumerWidget {
  /// The child to show if the crypto store is non null.
  final Widget child;

  /// The child to show if the crypto store is null.
  final Widget childIfAbsent;

  /// Whether to display the child if the app is locked.
  final bool showChildIfLocked;

  /// The provider instance.
  final AsyncNotifierProvider<U, T> provider;

  /// Creates a new require provider widget instance.
  const _RequireProviderValueWidget({
    super.key,
    required this.child,
    this.childIfAbsent = const SizedBox.shrink(),
    this.showChildIfLocked = true,
    required this.provider,
  });

  /// Creates a new require crypto store widget instance.
  static _RequireProviderValueWidget<CryptoStore?, StoredCryptoStore> cryptoStore({
    required Widget child,
    Widget childIfAbsent = const SizedBox.shrink(),
    bool showChildIfLocked = true,
  }) => _RequireProviderValueWidget(
    provider: cryptoStoreProvider,
    childIfAbsent: childIfAbsent,
    showChildIfLocked: showChildIfLocked,
    child: child,
  );

  /// Creates a new require crypto store widget instance.
  static _RequireProviderValueWidget<CryptoStore?, StoredCryptoStore> cryptoStoreAndTotpList({
    required Widget child,
    Widget childIfAbsent = const SizedBox.shrink(),
    bool showChildIfLocked = true,
  }) => _RequireProviderValueWidget(
    provider: cryptoStoreProvider,
    childIfAbsent: childIfAbsent,
    showChildIfLocked: showChildIfLocked,
    child: _RequireProviderValueWidget(
      provider: totpRepositoryProvider,
      childIfAbsent: childIfAbsent,
      child: child,
    ),
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (showChildIfLocked) {
      bool isUnlocked = ref.watch(appLockStateProvider).value == AppLockState.unlocked;
      if (!isUnlocked) {
        return child;
      }
    }
    AsyncValue<T> value = ref.watch(provider);
    return value.value == null ? childIfAbsent : child;
  }
}
