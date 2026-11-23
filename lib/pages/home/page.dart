import 'package:custom_refresh_indicator/custom_refresh_indicator.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:open_authenticator/core/app_unlock/methods/method.dart';
import 'package:open_authenticator/core/app_unlock/state.dart';
import 'package:open_authenticator/core/backend/authentication/session.dart';
import 'package:open_authenticator/core/backend/backend.dart';
import 'package:open_authenticator/core/backend/synchronization/push/result.dart';
import 'package:open_authenticator/core/backend/synchronization/queue.dart';
import 'package:open_authenticator/core/backend/synchronization/status.dart';
import 'package:open_authenticator/core/crypto/store.dart';
import 'package:open_authenticator/core/settings/display_copy_button.dart';
import 'package:open_authenticator/core/settings/display_search_button.dart';
import 'package:open_authenticator/core/settings/storage_type.dart';
import 'package:open_authenticator/core/totp/decrypted.dart';
import 'package:open_authenticator/core/totp/repository.dart';
import 'package:open_authenticator/core/totp/totp.dart';
import 'package:open_authenticator/flows/master_password.dart';
import 'package:open_authenticator/i18n/localizable_exception.dart';
import 'package:open_authenticator/i18n/translations.g.dart';
import 'package:open_authenticator/main.dart';
import 'package:open_authenticator/pages/scan.dart';
import 'package:open_authenticator/pages/settings/page.dart';
import 'package:open_authenticator/pages/sync_issues.dart';
import 'package:open_authenticator/pages/totp.dart';
import 'package:open_authenticator/spacing.dart';
import 'package:open_authenticator/utils/clipboard.dart';
import 'package:open_authenticator/utils/color.dart';
import 'package:open_authenticator/utils/platform.dart';
import 'package:open_authenticator/utils/result/handler.dart';
import 'package:open_authenticator/utils/result/result.dart';
import 'package:open_authenticator/widgets/app_scaffold.dart';
import 'package:open_authenticator/widgets/button_text.dart';
import 'package:open_authenticator/widgets/clickable.dart';
import 'package:open_authenticator/widgets/dialog/about_dialog.dart';
import 'package:open_authenticator/widgets/dialog/app_dialog.dart';
import 'package:open_authenticator/widgets/dialog/confirmation_dialog.dart';
import 'package:open_authenticator/widgets/dialog/error_dialog.dart';
import 'package:open_authenticator/widgets/dialog/invalid_session_dialog.dart';
import 'package:open_authenticator/widgets/dialog/text_input_dialog.dart';
import 'package:open_authenticator/widgets/image_text_actions.dart';
import 'package:open_authenticator/widgets/rotation_animation.dart';
import 'package:open_authenticator/widgets/smooth_scale.dart';
import 'package:open_authenticator/widgets/title_text.dart';
import 'package:open_authenticator/widgets/totp/widget.dart';
import 'package:open_authenticator/widgets/waiting_overlay.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

part 'app_bar.dart';
part 'dialogs/add_totp.dart';
part 'dialogs/totp_decrypt.dart';
part 'list/refresh_indicator.dart';
part 'list/totps.dart';
part 'scroll/fab.dart';
part 'scroll/search_box.dart';
part 'search/action.dart';
part 'search/box.dart';
part 'search/extension.dart';
part 'search/route.dart';
part 'utils/require_provider_value.dart';

/// The home page.
class HomePage extends ConsumerStatefulWidget {
  /// The home page name.
  static const String name = Navigator.defaultRouteName;

  /// Overrides the platform default placement of the add button.
  final bool? useFloatingAddButton;

  /// Creates a new home page instance.
  const HomePage({
    super.key,
    this.useFloatingAddButton,
  });

  @override
  ConsumerState<ConsumerStatefulWidget> createState() => _HomePageState();
}

/// The home page state.
class _HomePageState extends ConsumerState<HomePage> {
  /// Allows to scroll through the list of items.
  late final ItemScrollController itemScrollController = ItemScrollController();

  /// Whether to display the floating action button.
  bool showFloatingActionButton = true;

  bool get useFloatingAddButton => widget.useFloatingAddButton ?? (currentPlatform == Platform.android || kDebugMode);

  /// Whether to display the search box.
  bool showSearchBox = false;

  /// The TOTP to emphasis, if any.
  int? emphasisIndex;

  @override
  void initState() {
    super.initState();
    ref.listenManual(displaySearchButtonSettingsEntryProvider, (previous, next) {
      if (next.value == true && showSearchBox && mounted) {
        setState(() => showSearchBox = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<Totp>> totps = ref.watch(totpRepositoryProvider);
    final StorageType? storageType = ref.watch(storageTypeSettingsEntryProvider).value;
    final bool displaySearchButton = ref.read(displaySearchButtonSettingsEntryProvider).value ?? true;
    return AppScaffold.asyncValue(
      asyncValue: totps,
      scrollable: !totps.hasValue,
      paddingBuilder: (_) => EdgeInsets.zero,
      header: _HomePageHeader(
        showAddButton: !useFloatingAddButton,
        onAddButtonPress: () => onAddButtonPress(context),
        onTotpSelectedFollowingSearch: (index) async {
          itemScrollController.jumpTo(index: index);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() {
                showSearchBox = false;
                emphasisIndex = index;
              });
            }
          });
          if (!(await ref.read(displayCopyButtonSettingsEntryProvider.future))) {
            final Totp? totp = totps.value?[index];
            if (context.mounted && totp?.isDecrypted == true) {
              _TotpsListWidget.copyCode(context, totp as DecryptedTotp);
            }
          }
        },
        showSearchBox: showSearchBox,
      ),
      builder: (value) {
        final Widget body = _RequireProviderValueWidget.cryptoStore(
          childIfAbsent: Center(
            child: SingleChildScrollView(
              padding: context.theme.scaffoldStyle.childPadding,
              child: ImageTextActions.icon(
                icon: FLucideIcons.lock,
                text: translations.home.noCryptoStore.message,
                actions: [
                  ClickableButton(
                    onPress: () => ref.read(masterPasswordFlowProvider).changeMasterPassword(context, askForUnlock: false),
                    prefix: const Icon(FLucideIcons.rectangleEllipsis),
                    child: ButtonText(translations.home.noCryptoStore.resetButton),
                  ),
                ],
              ),
            ),
          ),
          child: _RevealFloatingActionButtonWidget(
            enabled: useFloatingAddButton,
            onHideFloatingActionButton: () {
              if (showFloatingActionButton) {
                setState(() => showFloatingActionButton = false);
              }
            },
            onShowFloatingActionButton: () {
              if (!showFloatingActionButton) {
                setState(() => showFloatingActionButton = true);
              }
            },
            child: _RevealSearchBoxWidget(
              onHideSearchBox: () {
                if (showSearchBox) {
                  setState(() => showSearchBox = false);
                }
              },
              onShowSearchBox: () {
                if (!showSearchBox) {
                  setState(() => showSearchBox = true);
                }
              },
              child: (displaySearchButton || (!displaySearchButton && showSearchBox)) && (currentPlatform.isMobile || kDebugMode) && storageType == StorageType.shared
                  ? _TotpsRefreshIndicatorWidget(
                      onRefresh: () => ref.read(synchronizationControllerProvider.notifier).forceSync(),
                      child: buildTotpsListWidget(value),
                    )
                  : buildTotpsListWidget(value),
            ),
          ),
        );
        return [
          if (useFloatingAddButton)
            Stack(
              alignment: Alignment.bottomRight,
              children: [
                body,
                _RequireProviderValueWidget.cryptoStoreAndTotpList(
                  child: _FloatingAddButton(
                    showFloatingActionButton: showFloatingActionButton,
                    onAddButtonPress: onAddButtonPress,
                  ),
                ),
              ],
            )
          else
            body,
        ];
      },
      onRetryPressed: () {
        ref.invalidate(totpRepositoryProvider);
        ref.read(synchronizationControllerProvider.notifier).forceSync();
      },
    );
  }

  /// Triggered when the "Add" button is pressed.
  Future<void> onAddButtonPress(BuildContext context) async {
    if (!kDebugMode && !_AddTotpDialog.isSupported) {
      Navigator.pushNamed(context, TotpPage.name);
      return;
    }
    final AddTotpDialogResult? choice = await _AddTotpDialog.show(context);
    if (choice == null || !context.mounted) {
      return;
    }
    Navigator.pushNamed(context, choice == AddTotpDialogResult.qrCode ? ScanPage.name : TotpPage.name);
  }

  /// Builds the TOTPs list widget.
  Widget buildTotpsListWidget(List<Totp> value) => _TotpsListWidget(
    totps: value,
    itemScrollController: itemScrollController,
    emphasisIndex: emphasisIndex,
    onHighlightFinished: () {
      if (mounted && emphasisIndex != null) {
        setState(() => emphasisIndex = null);
      }
    },
  );
}
