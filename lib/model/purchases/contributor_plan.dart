import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_authenticator/app.dart';
import 'package:open_authenticator/i18n/localizable_exception.dart';
import 'package:open_authenticator/i18n/translations.g.dart';
import 'package:open_authenticator/model/backend/user.dart';
import 'package:open_authenticator/model/purchases/clients/client.dart';
import 'package:open_authenticator/model/settings/backend_url.dart';
import 'package:open_authenticator/utils/result/result.dart';
import 'package:purchases_flutter/purchases_flutter.dart' hide Price;

/// The Contributor Plan provider.
final contributorPlanStateProvider = AsyncNotifierProvider<ContributorPlan, ContributorPlanState>(ContributorPlan.new);

/// Allows to read and change the Contributor Plan state.
class ContributorPlan extends AsyncNotifier<ContributorPlanState> {
  @override
  FutureOr<ContributorPlanState> build() async {
    if (AppContributorPlan.offeringId.isEmpty) {
      return .impossible;
    }
    bool hasBackendUrlChanged = ref.watch(backendUrlSettingsEntryProvider).value?.hasBackendUrlChanged ?? false;
    if (hasBackendUrlChanged && !kDebugMode) {
      return .impossible;
    }
    RevenueCatClient? client = await ref.watch(revenueCatClientProvider.future);
    if (client == null) {
      return .impossible;
    }
    await client.initialize(ref);
    User? user = await ref.watch(userProvider.future);
    return user?.contributorPlan == true ? .active : .inactive;
  }

  /// Changes the state to [newState].
  void debugChangeState(ContributorPlanState newState) {
    if (kDebugMode && ref.mounted) {
      state = AsyncData(newState);
    }
  }

  /// Returns the prices of the contributor plan.
  Future<Result<Prices>> getPrices() async {
    try {
      RevenueCatClient? revenueCatClient = await ref.read(revenueCatClientProvider.future);
      if (revenueCatClient == null) {
        throw _NoRevenueCatClientException();
      }
      Map<PackageType, Price> packagesPrice = await revenueCatClient.getPrices(Purchasable.contributorPlan);
      List<PackageType> packages = List.of(packagesPrice.keys);
      packages.sort((a, b) => b.index.compareTo(a.index));
      PackageType? reference = packages.firstOrNull;
      Map<PackageType, int> promotions = {};
      if (reference != null && reference.inAYear != null) {
        double referencePricePerYear = packagesPrice[reference]!.amount * reference.inAYear!;
        for (MapEntry<PackageType, Price> entry in packagesPrice.entries) {
          if (entry.key.inAYear == null) {
            continue;
          }
          double pricePerYear = entry.value.amount * entry.key.inAYear!;
          if (pricePerYear < referencePricePerYear) {
            promotions[entry.key] = (((pricePerYear / referencePricePerYear) - 1) * 100).round();
          }
        }
      }
      return ResultSuccess(
        value: Prices._(
          packagesPrice: packagesPrice,
          promotions: promotions,
        ),
      );
    } catch (ex, stackTrace) {
      return ResultError(
        exception: ex,
        stackTrace: stackTrace,
      );
    }
  }

  /// Tries to restore the subscription.
  Future<Result<ContributorPlanState>> restore() async {
    try {
      RevenueCatClient? revenueCatClient = await ref.read(revenueCatClientProvider.future);
      if (revenueCatClient == null) {
        throw _NoRevenueCatClientException();
      }
      if (revenueCatClient is! CanRestorePurchases) {
        throw _RevenueCatClientCannotRestorePurchasesException();
      }
      await revenueCatClient.restorePurchases();
      if (!ref.mounted) {
        return const ResultCancelled();
      }
      await Future.delayed(const Duration(seconds: 5));
      if (!ref.mounted) {
        return const ResultCancelled();
      }
      Result<User> result = await ref.read(userProvider.notifier).refreshUserInfo();
      return result.to((user) => user?.contributorPlan == true ? .active : .inactive);
    } catch (ex, stackTrace) {
      return ResultError(
        exception: ex,
        stackTrace: stackTrace,
      );
    }
  }

  /// Tries to refresh the subscription state.
  Future<Result<ContributorPlanState>> refresh() async {
    try {
      RevenueCatClient? revenueCatClient = await ref.read(revenueCatClientProvider.future);
      if (revenueCatClient == null) {
        throw _NoRevenueCatClientException();
      }
      Result<User> result = await ref.read(userProvider.notifier).refreshUserInfo();
      if (!ref.mounted) {
        return const ResultCancelled();
      }
      return result.to((user) => user?.contributorPlan == true ? .active : .inactive);
    } catch (ex, stackTrace) {
      return ResultError(
        exception: ex,
        stackTrace: stackTrace,
      );
    }
  }

  /// Purchases the given item.
  Future<Result<ContributorPlanState>> purchase(PackageType packageType) async {
    try {
      RevenueCatClient? revenueCatClient = await ref.read(revenueCatClientProvider.future);
      if (revenueCatClient == null) {
        throw _NoRevenueCatClientException();
      }
      bool shouldRefreshUser = await revenueCatClient.purchase(Purchasable.contributorPlan, packageType);
      if (shouldRefreshUser) {
        await Future.delayed(const Duration(seconds: 5));
        if (!ref.mounted) {
          return const ResultCancelled();
        }
        Result<User> result = await ref.read(userProvider.notifier).refreshUserInfo();
        return result.to((user) => user?.contributorPlan == true ? .active : .inactive);
      }
      return const ResultSuccess(value: .inactive);
    } catch (ex, stackTrace) {
      return ResultError(
        exception: ex,
        stackTrace: stackTrace,
      );
    }
  }
}

/// Allows to get the duration of a given package type.
extension PackageTypeDuration on PackageType {
  /// Returns the duration of the package.
  int? get inAYear => switch (this) {
    PackageType.weekly => 52,
    PackageType.monthly => 12,
    PackageType.twoMonth => 6,
    PackageType.threeMonth => 4,
    PackageType.sixMonth => 2,
    PackageType.annual => 1,
    _ => null,
  };
}

/// The Contributor Plan prices.
class Prices {
  /// The price map.
  final Map<PackageType, Price> packagesPrice;

  /// The promotions map.
  final Map<PackageType, int> promotions;

  /// Creates a new prices instance.
  const Prices._({
    this.packagesPrice = const {},
    this.promotions = const {},
  });
}

/// The Contributor Plan state.
enum ContributorPlanState {
  /// Whether there is no Contributor Plan available.
  impossible,

  /// Whether the user has not subscribed to the Contributor Plan yet.
  inactive,

  /// Whether the user has subscribed to the Contributor Plan.
  active,
}

/// Thrown when no RevenueCat client is available.
class _NoRevenueCatClientException extends LocalizableException {
  /// Creates a new no RevenueCat client exception instance.
  _NoRevenueCatClientException()
    : super(
        localizedErrorMessage: translations.error.revenueCat.noClient,
      );
}

/// Thrown when the RevenueCat client cannot restore purchases.
class _RevenueCatClientCannotRestorePurchasesException extends LocalizableException {
  /// Creates a new RevenueCat cannot restore purchases exception instance.
  _RevenueCatClientCannotRestorePurchasesException()
    : super(
        localizedErrorMessage: translations.error.revenueCat.cannotRestorePurchases,
      );
}
