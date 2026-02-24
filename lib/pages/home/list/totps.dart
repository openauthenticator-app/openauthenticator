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
    bool isUnlocked = ref.watch(appLockStateProvider.select((state) => state.value == AppLockState.unlocked));
    bool displayCopyButton = ref.watch(displayCopyButtonSettingsEntryProvider).value ?? true;
    return totps.isEmpty
        ? Center(
            child: SingleChildScrollView(
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
                Totp totp = totps[position];
                Widget totpWidget = TotpTile.adaptive(
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
    CryptoStore? currentCryptoStore = await ref.read(cryptoStoreProvider.future);
    if (currentCryptoStore == null) {
      if (context.mounted) {
        ErrorDialog.openDialog(context);
      }
      return;
    }
    if (!(await totp.encryptedData.canDecryptData(currentCryptoStore))) {
      if (context.mounted) {
        bool shouldContinue = await ConfirmationDialog.ask(
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
    bool confirmation = await ConfirmationDialog.ask(
      context,
      title: translations.totp.actions.deleteConfirmationDialog.title,
      message: translations.totp.actions.deleteConfirmationDialog.message,
    );
    if (!confirmation || !context.mounted) {
      return;
    }
    Result result = await showWaitingOverlay(
      context,
      future: ref.read(totpRepositoryProvider.notifier).deleteTotp(totp.uuid),
    );
    if (result is ResultError && context.mounted) {
      ErrorDialog.openDialog(context, error: result.exception, stackTrace: result.stackTrace);
    }
  }

  /// Allows to copy the code to the clipboard.
  static Future<void> copyCode(BuildContext context, DecryptedTotp totp) async {
    await Clipboard.setData(ClipboardData(text: totp.generateCode()));
    if (context.mounted) {
      showSuccessToast(context, text: translations.totp.actions.copyConfirmation);
    }
  }

  /// Tries to decrypt the current TOTP.
  Future<void> tryDecryptTotp(BuildContext context, WidgetRef ref, Totp totp) async {
    String? password = await TextInputDialog.prompt(
      context,
      title: translations.totp.decryptDialog.title,
      message: translations.totp.decryptDialog.message,
      password: true,
    );
    if (password == null || !context.mounted) {
      return;
    }

    TotpRepository repository = ref.read(totpRepositoryProvider.notifier);
    (CryptoStore, List<DecryptedTotp>) decryptedTotps = await showWaitingOverlay(
      context,
      future: () async {
        CryptoStore previousCryptoStore = await CryptoStore.fromPassword(password, totp.encryptedData.encryptionSalt);
        Totp targetTotp = await totp.decrypt(previousCryptoStore);
        if (!targetTotp.isDecrypted) {
          return (previousCryptoStore, <DecryptedTotp>[]);
        }
        Set<DecryptedTotp> decryptedTotps = await repository.tryDecryptAll(previousCryptoStore);
        return (
          previousCryptoStore,
          [
            targetTotp as DecryptedTotp,
            for (DecryptedTotp decryptedTotp in decryptedTotps)
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
        message: translations.error.totpDecrypt,
      );
      return;
    }

    TotpDecryptDialogResult? choice = await _TotpDecryptDialog.show(
      context,
      decryptedTotps: decryptedTotps.$2,
    );

    if (!context.mounted) {
      return;
    }

    Future<Result> changeTotpsKey(CryptoStore oldCryptoStore, List<DecryptedTotp> totps) async {
      try {
        CryptoStore? currentCryptoStore = await ref.read(cryptoStoreProvider.future);
        if (currentCryptoStore == null) {
          throw Exception('Unable to get current crypto store.');
        }
        List<DecryptedTotp> toUpdate = [];
        for (DecryptedTotp totp in totps) {
          DecryptedTotp? decryptedTotpWithNewKey = await totp.changeEncryptionKey(oldCryptoStore, currentCryptoStore);
          if (decryptedTotpWithNewKey == null || !decryptedTotpWithNewKey.isDecrypted) {
            throw Exception('Failed to encrypt TOTP with current crypto store.');
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
      case TotpDecryptDialogResult.changeTotpKey:
        Result result = await showWaitingOverlay(
          context,
          future: changeTotpsKey(decryptedTotps.$1, [decryptedTotps.$2.first]),
        );
        if (context.mounted) {
          context.handleResult(result);
        }
        break;
      case TotpDecryptDialogResult.changeAllTotpsKey:
        Result result = await showWaitingOverlay(
          context,
          future: changeTotpsKey(decryptedTotps.$1, decryptedTotps.$2),
        );
        if (context.mounted) {
          context.handleResult(result);
        }
        break;
      case TotpDecryptDialogResult.changeMasterPassword:
        await MasterPasswordUtils.changeMasterPassword(context, ref, password: password);
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
