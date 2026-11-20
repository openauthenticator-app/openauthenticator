part of '../page.dart';

/// Allows to display the TOTPs list.
class _TotpsListWidget extends ConsumerWidget {
  /// The TOTPs list.
  final List<Totp> totps;

  /// The item scroll controller.
  final ItemScrollController? itemScrollController;

  /// The TOTP to emphasis, if any.
  final int? emphasisIndex;

  /// Triggered when the highlight has been finished.
  /// Should clear the [emphasis].
  final VoidCallback? onHighlightFinished;

  /// Creates a new TOTPs list widget instance.
  const _TotpsListWidget({
    super.key,
    required this.totps,
    this.itemScrollController,
    this.emphasisIndex,
    this.onHighlightFinished,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool isUnlocked = ref.watch(appLockStateProvider.select((state) => state.value == AppLockState.unlocked));
    final bool displayCopyButton = ref.watch(displayCopyButtonSettingsEntryProvider).value ?? true;
    return totps.isEmpty
        ? Center(
            child: SingleChildScrollView(
              padding: context.theme.scaffoldStyle.childPadding,
              physics: const AlwaysScrollableScrollPhysics(),
              child: ImageTextActions.asset(
                asset: 'assets/images/home.si',
                text: translations.home.empty,
              ),
            ),
          )
        : ScrollConfiguration(
            behavior: _ScrollBehavior(),
            child: ScrollablePositionedList.separated(
              padding: context.theme.style.pagePadding,
              itemScrollController: itemScrollController,
              itemCount: totps.length,
              physics: const AlwaysScrollableScrollPhysics(),
              itemBuilder: (context, position) {
                final Totp totp = totps[position];
                final Widget totpWidget = TotpTile.adaptive(
                  key: ValueKey(totp.uuid),
                  totp: totp,
                  displayCode: isUnlocked,
                  onDecryptPress: () => tryDecryptTotp(context, ref, totp),
                  onEditPress: () => editTotp(context, ref, totp),
                  onDeletePress: () => deleteTotp(context, ref, totp),
                  onTap: (!displayCopyButton || currentPlatform.isDesktop) && totp.isDecrypted ? ((_) => copyCode(context, totp as DecryptedTotp)) : null,
                  onCopyPress: (displayCopyButton && !currentPlatform.isDesktop) && totp.isDecrypted ? (() => copyCode(context, totp as DecryptedTotp)) : null,
                );
                return position == emphasisIndex
                    ? SmoothScale(
                        useInitialScale: true,
                        onAnimationFinished: onHighlightFinished,
                        child: totpWidget,
                      )
                    : totpWidget;
              },
              separatorBuilder: (context, position) => const SizedBox(height: kBigSpace),
            ),
          );
  }

  /// Allows to edit the TOTP.
  Future<void> editTotp(BuildContext context, WidgetRef ref, Totp totp) async {
    final CryptoStore? currentCryptoStore = await ref.read(cryptoStoreProvider.future);
    if (currentCryptoStore == null) {
      if (context.mounted) {
        ErrorDialog.openDialog(context);
      }
      return;
    }
    if (!(totp.encryptedData.canDecryptData(currentCryptoStore))) {
      if (context.mounted) {
        final bool shouldContinue = await ConfirmationDialog.ask(
          context,
          title: translations.totp.actions.editConfirmationDialog.title,
          message: translations.totp.actions.editConfirmationDialog.message,
        );
        if (!shouldContinue) {
          return;
        }
      }
    }
    if (context.mounted) {
      await Navigator.pushNamed(
        context,
        TotpPage.name,
        arguments: {
          OpenAuthenticatorApp.kRouteParameterTotp: totp,
        },
      );
    }
  }

  /// Allows to delete the TOTP.
  Future<void> deleteTotp(BuildContext context, WidgetRef ref, Totp totp) async {
    final bool confirmation = await ConfirmationDialog.ask(
      context,
      title: translations.totp.actions.deleteConfirmationDialog.title,
      message: translations.totp.actions.deleteConfirmationDialog.message,
      okButtonVariant: .destructive,
    );
    if (!confirmation || !context.mounted) {
      return;
    }
    final Result result = await showWaitingOverlay(
      context,
      future: ref.read(totpRepositoryProvider.notifier).deleteTotp(totp.uuid),
    );
    if (result is ResultError && context.mounted) {
      ErrorDialog.openDialog(context, error: result.exception, stackTrace: result.stackTrace);
    }
  }

  /// Allows to copy the code to the clipboard.
  static Future<void> copyCode(BuildContext context, DecryptedTotp totp) async {
    HapticFeedback.mediumImpact();
    await copyText(context, totp.generateCode(), confirmation: translations.totp.actions.copyConfirmation);
  }

  /// Tries to decrypt the current TOTP.
  Future<void> tryDecryptTotp(BuildContext context, WidgetRef ref, Totp totp) async {
    final String? password = await TextInputDialog.prompt(
      context,
      title: translations.totp.decryptDialog.title,
      message: translations.totp.decryptDialog.message,
      password: true,
    );
    if (password == null || !context.mounted) {
      return;
    }

    final TotpRepository repository = ref.read(totpRepositoryProvider.notifier);
    final (CryptoStore, List<DecryptedTotp>) decryptedTotps = await showWaitingOverlay(
      context,
      future: () async {
        final CryptoStore previousCryptoStore = await CryptoStore.fromPasswordInIsolate(password, totp.encryptedData.encryptionSalt);
        final Totp targetTotp = totp.decrypt(previousCryptoStore);
        if (!targetTotp.isDecrypted) {
          return (previousCryptoStore, <DecryptedTotp>[]);
        }
        final Set<DecryptedTotp> decryptedTotps = await repository.tryDecryptAll(previousCryptoStore);
        return (
          previousCryptoStore,
          [
            targetTotp as DecryptedTotp,
            for (final DecryptedTotp decryptedTotp in decryptedTotps)
              if (targetTotp.uuid != decryptedTotp.uuid) decryptedTotp,
          ],
        );
      }(),
    );
    if (!context.mounted) {
      return;
    }
    if (decryptedTotps.$2.isEmpty) {
      ErrorDialog.openDialog(
        context,
        message: translations.error.totp.decrypt,
      );
      return;
    }

    final TotpDecryptDialogResult? choice = await _TotpDecryptDialog.show(
      context,
      decryptedTotps: decryptedTotps.$2,
    );

    if (!context.mounted) {
      return;
    }

    Future<Result> changeTotpsKey(CryptoStore oldCryptoStore, List<DecryptedTotp> totps) async {
      try {
        final CryptoStore? currentCryptoStore = await ref.read(cryptoStoreProvider.future);
        if (currentCryptoStore == null) {
          throw _NoCryptoStoreException();
        }
        final List<DecryptedTotp> toUpdate = [];
        for (final DecryptedTotp totp in totps) {
          final DecryptedTotp? decryptedTotpWithNewKey = totp.changeEncryptionKey(oldCryptoStore, currentCryptoStore);
          if (decryptedTotpWithNewKey == null || !decryptedTotpWithNewKey.isDecrypted) {
            throw _CryptoStoreChangeException();
          }
          toUpdate.add(decryptedTotpWithNewKey);
        }
        return await repository.updateTotps(toUpdate);
      } catch (ex, stackTrace) {
        return ResultError(
          exception: ex,
          stackTrace: stackTrace,
        );
      }
    }

    switch (choice) {
      case .changeTotpKey:
        final Result result = await showWaitingOverlay(
          context,
          future: changeTotpsKey(decryptedTotps.$1, [decryptedTotps.$2.first]),
        );
        if (context.mounted) {
          handleResult(context, result);
        }
        break;
      case .changeAllTotpsKey:
        final Result result = await showWaitingOverlay(
          context,
          future: changeTotpsKey(decryptedTotps.$1, decryptedTotps.$2),
        );
        if (context.mounted) {
          handleResult(context, result);
        }
        break;
      case .changeMasterPassword:
        await ref.read(masterPasswordFlowProvider).changeMasterPassword(context, password: password);
        break;
      default:
        break;
    }
  }
}

/// Allows to display a refresh indicator on desktop platforms as well.
class _ScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => kDebugMode
      ? {
          PointerDeviceKind.touch,
          PointerDeviceKind.mouse,
        }
      : super.dragDevices;
}

/// Thrown when we cannot get the current crypto store.
class _NoCryptoStoreException extends LocalizableException {
  /// Creates a new no crypto store exception instance.
  _NoCryptoStoreException()
    : super(
        localizedErrorMessage: translations.error.totp.changeCryptoStore.noCryptoStore,
      );
}

/// Thrown when we cannot change a TOTP's encryption key.
class _CryptoStoreChangeException extends LocalizableException {
  /// Creates a new crypto store change exception instance.
  _CryptoStoreChangeException()
    : super(
        localizedErrorMessage: translations.error.totp.changeCryptoStore.generic,
      );
}
