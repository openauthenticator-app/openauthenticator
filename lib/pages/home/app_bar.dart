part of 'page.dart';

/// The app bar for the home page.
class _HomePageHeader extends ConsumerWidget {
  /// Whether to show the add button.
  final bool showAddButton;

  /// Triggered when the add button is pressed.
  final VoidCallback? onAddButtonPress;

  /// Triggered when a TOTP is selected following a search.
  final Function(int index)? onTotpSelectedFollowingSearch;

  /// Whether to show the search box.
  final bool showSearchBox;

  /// Creates a new app bar instance.
  const _HomePageHeader({
    super.key,
    this.showAddButton = false,
    this.onAddButtonPress,
    this.onTotpSelectedFollowingSearch,
    this.showSearchBox = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Widget header = FHeader.nested(
      title: const _AppBarTitle(),
      prefixes: [
        _RequireProviderValueWidget.cryptoStoreAndTotpList(
          child: ClickableHeaderAction(
            onPress: () => Navigator.pushNamed(context, SettingsPage.name),
            icon: const Icon(FIcons.settings),
          ),
        ),
      ],
      suffixes: [
        if (ref.watch(displaySearchButtonSettingsEntryProvider).value ?? true)
          _RequireProviderValueWidget.cryptoStoreAndTotpList(
            child: Builder(
              builder: (context) => _SearchAction(
                onTotpFound: (totp) => onTotpFound(ref, totp),
              ),
            ),
          ),
        if (showAddButton)
          _RequireProviderValueWidget.cryptoStoreAndTotpList(
            child: ClickableHeaderAction(
              onPress: onAddButtonPress,
              icon: const Icon(FIcons.plus),
            ),
          ),
        _RequireProviderValueWidget.cryptoStoreAndTotpList(
          child: _SyncHeaderAction(),
        ),
      ],
    );
    return showSearchBox ? _SearchBox(header: header) : header;
  }

  /// Triggered when a TOTP is selected following a search.
  Future<void> onTotpFound(WidgetRef ref, Totp totp) async {
    List<Totp> totps = await ref.read(totpRepositoryProvider.future);
    int index = totps.indexOf(totp);
    if (index >= 0) {
      onTotpSelectedFollowingSearch?.call(index);
    }
  }
}

/// The app bar title.
class _AppBarTitle extends StatelessWidget {
  /// The text max width.
  /// Above this value, nothing will be displayed.
  final double? textMaxWidth;

  /// Creates a new app bar title instance.
  const _AppBarTitle({
    this.textMaxWidth = 210,
  });

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      if (textMaxWidth != null && constraints.maxWidth <= textMaxWidth!) {
        return const SizedBox.shrink();
      }
      Widget title = const TitleText();
      if (currentPlatform.isDesktop) {
        title = GestureDetector(
          onTap: () => AboutAppDialog.showForApp(context),
          child: title,
        ).clickable();
      }
      return title;
    },
  );
}

/// The sync header action.
class _SyncHeaderAction extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    StorageType? storageType = ref.watch(storageTypeSettingsEntryProvider).value;
    if (storageType != StorageType.shared) {
      return const SizedBox.shrink();
    }
    SynchronizationPhase phase = ref.watch(synchronizationControllerProvider.select((status) => status.phase));
    switch (phase) {
      case SynchronizationPhaseOffline():
        return ClickableHeaderAction(
          onPress: null,
          icon: Icon(
            FIcons.refreshCcwDot,
            color: context.theme.colors.muted,
          ),
        );
      case SynchronizationPhaseSyncing():
        return const ClickableHeaderAction(
          onPress: null,
          icon: RotationAnimation(
            child: Icon(FIcons.refreshCcw),
          ),
        );
      case SynchronizationPhaseError(:final exception, :final stackTrace):
        return ClickableHeaderAction(
          onPress: () async {
            if (exception is InvalidSessionException || exception is NoSessionException) {
              InvalidSessionDialog.openDialog(context, ref, handleResult: true);
            } else {
              ErrorDialogResult? result = await ErrorDialog.openDialog(
                context,
                error: exception,
                stackTrace: stackTrace,
                allowRetry: true,
              );
              if (result == ErrorDialogResult.retry) {
                ref.read(synchronizationControllerProvider.notifier).forceSync();
              }
            }
          },
          icon: Icon(
            FIcons.refreshCcw,
            color: context.theme.colors.destructive,
          ),
        );
      default:
        AsyncValue<List<PushOperationResult>> errors = ref.watch(pushOperationsErrorsProvider);
        if (errors.hasValue && errors.value!.isNotEmpty) {
          return ClickableHeaderAction(
            onPress: () => Navigator.pushNamed(context, SyncIssuesPage.name),
            icon: Icon(
              FIcons.refreshCcwDot,
              color: context.theme.colors.destructive,
            ),
          );
        }
        if (currentPlatform.isDesktop) {
          return ClickableHeaderAction(
            onPress: () => ref.read(synchronizationControllerProvider.notifier).forceSync(),
            icon: const Icon(FIcons.refreshCcw),
          );
        }
        return const SizedBox.shrink();
    }
  }
}
