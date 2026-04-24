import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'package:intl/intl.dart';
import 'package:open_authenticator/app.dart';
import 'package:open_authenticator/i18n/translations.g.dart';
import 'package:open_authenticator/model/backend/user.dart';
import 'package:open_authenticator/model/purchases/clients/client.dart';
import 'package:open_authenticator/model/purchases/contributor_plan.dart';
import 'package:open_authenticator/spacing.dart';
import 'package:open_authenticator/utils/result.dart';
import 'package:open_authenticator/utils/utils.dart';
import 'package:open_authenticator/widgets/button_text.dart';
import 'package:open_authenticator/widgets/centered_circular_progress_indicator.dart';
import 'package:open_authenticator/widgets/clickable.dart';
import 'package:open_authenticator/widgets/divider_text.dart';
import 'package:open_authenticator/widgets/sized_scalable_image.dart';
import 'package:open_authenticator/widgets/title_text.dart';
import 'package:open_authenticator/widgets/waiting_overlay.dart';
import 'package:purchases_flutter/purchases_flutter.dart' hide Price;
import 'package:url_launcher/url_launcher_string.dart';

/// The contributor plan fallback paywall header.
class ContributorPlanFallbackPaywallHeader extends StatelessWidget {
  /// Triggered on dismiss.
  final VoidCallback onDismiss;

  /// Creates a new contributor plan fallback paywall header instance.
  const ContributorPlanFallbackPaywallHeader({
    super.key,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) => FHeader.nested(
    prefixes: [
      ClickableHeaderAction.x(
        onPress: onDismiss,
      ),
    ],
    title: Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: FittedBox(
        fit: BoxFit.fitWidth,
        child: Text.rich(
          translations.contributorPlan.fallbackPaywall.title(
            title: (text) => WidgetSpan(
              child: TitleText(
                text: text,
                textStyle: context.theme.typography.xl3,
              ),
              alignment: PlaceholderAlignment.middle,
            ),
          ),
          style: context.theme.typography.xl3,
          textAlign: TextAlign.center,
        ),
      ),
    ),
  );
}

/// Allows to pick for a billing plan (annual / monthly).
/// Displayed only if `purchases_ui_flutter` is unavailable on the current OS.
class ContributorPlanFallbackPaywall extends ConsumerStatefulWidget {
  /// Triggered when the purchase has completed.
  final VoidCallback onPurchaseCompleted;

  /// Creates a new contributor plan fallback paywall instance.
  const ContributorPlanFallbackPaywall({
    super.key,
    required this.onPurchaseCompleted,
  });

  @override
  ConsumerState<ConsumerStatefulWidget> createState() => _ContributorPlanFallbackPaywallState();
}

class _ContributorPlanFallbackPaywallState extends ConsumerState<ContributorPlanFallbackPaywall> {
  bool hasPressedPurchaseButton = false;

  @override
  Widget build(BuildContext context) {
    RevenueCatClient? revenueCatClient = ref.watch(revenueCatClientProvider).value;
    FButtonStyleDelta bottomButtonsStyle = .delta(
      contentStyle: .delta(
        textStyle: .delta(
          [
            .all(
              .delta(
                fontSize: context.theme.typography.xs.fontSize,
              ),
            ),
          ],
        ),
      ),
    );
    return ListView(
      shrinkWrap: true,
      children: [
        Padding(
          padding: const EdgeInsets.all(kSpace),
          child: Container(
            height: 150,
            margin: const EdgeInsets.only(bottom: kBigSpace),
            child: const SizedScalableImage(
              asset: 'assets/images/logo.si',
            ),
          ),
        ),
        ClickableTile.raw(
          child: Column(
            spacing: kSpace / 2,
            children: [
              for (String feature in translations.contributorPlan.fallbackPaywall.features)
                Row(
                  mainAxisSize: .min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: kSpace / 2),
                      child: Icon(
                        FIcons.check,
                        color: context.theme.colors.primary,
                      ),
                    ),
                    Expanded(
                      child: Text(feature),
                    ),
                  ],
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: kBigSpace, bottom: kSpace),
          child: DividerText(
            text: Text(
              translations.contributorPlan.fallbackPaywall.packageType.choose,
              textAlign: .center,
              style: const TextStyle(fontWeight: .bold),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: kSpace),
          child: _ContributorPlanBillingPlanPicker(
            onContinuePress: _tryPurchase,
          ),
        ),
        Wrap(
          alignment: WrapAlignment.spaceAround,
          children: [
            ClickableButton(
              variant: .ghost,
              onPress: () async {
                if (await canLaunchUrlString(AppContributorPlan.privacyPolicyLink)) {
                  await launchUrlString(AppContributorPlan.privacyPolicyLink);
                }
              },
              mainAxisSize: .min,
              style: bottomButtonsStyle,
              child: ButtonText(translations.contributorPlan.fallbackPaywall.button.privacyPolicy),
            ),
            ClickableButton(
              variant: .ghost,
              onPress: () async {
                if (await canLaunchUrlString(AppContributorPlan.termsOfServiceLink)) {
                  await launchUrlString(AppContributorPlan.termsOfServiceLink);
                }
              },
              mainAxisSize: .min,
              style: bottomButtonsStyle,
              child: ButtonText(translations.contributorPlan.fallbackPaywall.button.termsOfService),
            ),
            ClickableButton(
              variant: hasPressedPurchaseButton ? .outline : .ghost,
              onPress: _tryRefreshUserInfo,
              mainAxisSize: .min,
              style: bottomButtonsStyle,
              child: ButtonText(translations.miscellaneous.refreshUserInfo),
            ),
            if (revenueCatClient is CanRestorePurchases)
              ClickableButton(
                variant: .ghost,
                onPress: _tryRestorePurchases,
                mainAxisSize: .min,
                style: bottomButtonsStyle,
                child: ButtonText(translations.contributorPlan.fallbackPaywall.button.restorePurchases),
              ),
          ],
        ),
      ],
    );
  }

  /// Tries to do purchase the [packageType].
  Future<void> _tryPurchase(PackageType packageType) async {
    ContributorPlan contributorPlan = ref.read(contributorPlanStateProvider.notifier);
    Result<ContributorPlanState> result = await showWaitingOverlay(
      context,
      future: contributorPlan.purchase(packageType),
    );
    _handleContributorPlanStateResult(
      result,
      successMessage: (state) => state == .active ? translations.contributorPlan.subscribeSuccess.immediate : translations.contributorPlan.subscribeSuccess.delayed,
    );
    if (result is ResultSuccess<ContributorPlanState> && result.value != .active && mounted) {
      setState(() => hasPressedPurchaseButton = true);
    }
  }

  /// Tries to refresh the user info.
  Future<void> _tryRefreshUserInfo() async {
    ContributorPlan contributorPlan = ref.read(contributorPlanStateProvider.notifier);
    Result<ContributorPlanState> result = await showWaitingOverlay(
      context,
      future: contributorPlan.refresh(),
    );
    _handleContributorPlanStateResult(result);
  }

  /// Tries to restore the purchases.
  Future<void> _tryRestorePurchases() async {
    ContributorPlan contributorPlan = ref.read(contributorPlanStateProvider.notifier);
    Result<ContributorPlanState> result = await showWaitingOverlay(
      context,
      future: contributorPlan.restore(),
    );
    _handleContributorPlanStateResult(
      result,
      successMessage: (_) => translations.contributorPlan.fallbackPaywall.restorePurchasesSuccess,
    );
  }

  /// Handles the [result] of either the [ContributorPlan.purchase] or [ContributorPlan.refresh] method.
  void _handleContributorPlanStateResult(Result<ContributorPlanState> result, {String? Function(ContributorPlanState?)? successMessage}) {
    if (!mounted) {
      return;
    }
    context.handleResult(
      result,
      successMessage: successMessage,
    );
    if (result.valueOrNull == .active) {
      widget.onPurchaseCompleted();
    }
  }
}

/// Displays the billing plan list and a "Continue" button.
class _ContributorPlanBillingPlanPicker extends ConsumerStatefulWidget {
  /// Triggered when a package type has been chosen.
  final Function(PackageType) onContinuePress;

  /// Creates a new contributor plan billing plan picker instance.
  const _ContributorPlanBillingPlanPicker({
    required this.onContinuePress,
  });

  @override
  ConsumerState<ConsumerStatefulWidget> createState() => _ContributorPlanBillingPlanPickerState();
}

/// The contributor plan billing plan picker state.
class _ContributorPlanBillingPlanPickerState extends ConsumerState<_ContributorPlanBillingPlanPicker> {
  /// The selected package type.
  PackageType? packageType;

  @override
  Widget build(BuildContext context) {
    AsyncValue<User?> user = ref.watch(userProvider);
    return Column(
      mainAxisSize: .min,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: kBigSpace),
          child: FutureBuilder(
            future: ref.read(contributorPlanStateProvider.notifier).getPrices(),
            builder: (context, snapshot) {
              if (snapshot.hasError || snapshot.data is ResultError) {
                Object? error;
                if (snapshot.hasError) {
                  error = snapshot.error!;
                } else if (snapshot.data is ResultError) {
                  error = snapshot.error;
                }
                return Text(
                  error == null ? translations.error.generic.tryAgain : translations.error.generic.withException(exception: error),
                  textAlign: TextAlign.center,
                );
              }
              if (snapshot.hasData) {
                Result<Prices> result = snapshot.requireData;
                if (result is! ResultSuccess) {
                  Object? exception = result is! ResultError ? null : (result as ResultError).exception;
                  return Text(
                    exception == null ? translations.error.generic.tryAgain : translations.error.generic.withException(exception: exception),
                    textAlign: TextAlign.center,
                  );
                }
                Prices prices = (result as ResultSuccess).value;
                if (prices.packagesPrice.isEmpty) {
                  return Text(
                    translations.contributorPlan.fallbackPaywall.packageType.empty,
                    textAlign: TextAlign.center,
                  );
                }
                return Row(
                  mainAxisAlignment: .spaceEvenly,
                  mainAxisSize: .max,
                  spacing: kBigSpace,
                  children: [
                    for (MapEntry<PackageType, Price> entry in prices.packagesPrice.entries)
                      Expanded(
                        child: _createTile(
                          context,
                          packageType: entry.key,
                          price: entry.value,
                          off: prices.promotions[entry.key],
                        ),
                      ),
                  ],
                );
              }
              return const CenteredCircularProgressIndicator();
            },
          ),
        ),
        ClickableButton(
          onPress: !user.hasValue || user.value!.contributorPlan || packageType == null ? null : (() => widget.onContinuePress(packageType!)),
          child: ButtonText(user.value?.contributorPlan == true ? translations.contributorPlan.fallbackPaywall.button.subscribed : MaterialLocalizations.of(context).continueButtonLabel),
        ),
      ],
    );
  }

  /// Creates the list tile for the given [packageType].
  Widget _createTile(
    BuildContext context, {
    required PackageType packageType,
    required Price price,
    int? off,
  }) {
    String? name = translations.contributorPlan.fallbackPaywall.packageType.name[packageType.name];
    String? interval = translations.contributorPlan.fallbackPaywall.packageType.interval[packageType.name];
    String? subtitle = translations.contributorPlan.fallbackPaywall.packageType.subtitle[packageType.name];
    return name == null || interval == null || subtitle == null
        ? const SizedBox.shrink()
        : ClickableTile(
            style: .delta(
              decoration: .delta(
                this.packageType == packageType
                    ? [
                        .base(
                          .boxDelta(color: context.theme.tileStyles.base.decoration.base.color?.highlight()),
                        ),
                      ]
                    : [],
              ),
              contentStyle: const .delta(
                unsuffixedPadding: .value(EdgeInsets.symmetric(vertical: kSpace, horizontal: kBigSpace)),
              ),
            ),
            title: Text.rich(
              TextSpan(
                children: [
                  if (off != null)
                    WidgetSpan(
                      child: Padding(
                        padding: const EdgeInsets.only(right: kSpace),
                        child: FBadge(
                          style: .delta(
                            contentStyle: .delta(
                              labelTextStyle: .delta(fontSize: context.theme.typography.xs.fontSize),
                              padding: const .value(
                                .symmetric(horizontal: kSpace / 2, vertical: kSpace / 4),
                              ),
                            ),
                          ),
                          child: Text(
                            '-${off.abs()}%',
                          ),
                        ),
                      ),
                    ),
                  TextSpan(
                    text: name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            subtitle: Text(subtitle),
            details: Text.rich(
              translations.contributorPlan.fallbackPaywall.packageType.price(
                price: TextSpan(
                  text: NumberFormat.simpleCurrency(locale: translations.$meta.locale.underscoreTag, name: price.currencyCode).format(price.amount),
                  style: const TextStyle(fontStyle: .italic),
                ),
                interval: TextSpan(
                  text: interval.toLowerCase(),
                  style: const TextStyle(fontStyle: .italic),
                ),
              ),
            ),
            prefix: Icon(this.packageType == packageType ? FIcons.circleCheckBig : FIcons.circle),
            onPress: () {
              setState(() => this.packageType = this.packageType == packageType ? null : packageType);
            },
          );
  }
}
