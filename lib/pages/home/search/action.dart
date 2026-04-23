part of '../page.dart';

/// Displays a search button if the TOTP list is available.
class _SearchAction extends ConsumerWidget {
  /// Triggered when a TOTP has been found by the user.
  final Function(Totp totp)? onTotpFound;

  /// Creates a new search button instance.
  const _SearchAction({
    super.key,
    this.onTotpFound,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    AsyncValue<List<Totp>> totps = ref.watch(totpRepositoryProvider);
    return switch (totps) {
      AsyncData<List<Totp>>(:final value) =>
        value.isEmpty
            ? const SizedBox.shrink()
            : ClickableHeaderAction(
                onPress: () async {
                  Totp? result = await _showTotpSearch(context);
                  if (result != null) {
                    onTotpFound?.call(result);
                  }
                },
                icon: const Icon(FIcons.search),
              ),
      _ => const SizedBox.shrink(),
    };
  }
}
