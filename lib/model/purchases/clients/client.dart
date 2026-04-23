import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_authenticator/app.dart';
import 'package:open_authenticator/model/backend/user.dart';
import 'package:open_authenticator/model/purchases/clients/dart.dart';
import 'package:open_authenticator/model/purchases/clients/method_channel.dart';
import 'package:open_authenticator/model/settings/backend_url.dart';
import 'package:open_authenticator/utils/platform.dart';
import 'package:purchases_flutter/models/purchases_configuration.dart' as rc_purchases_configuration;
import 'package:purchases_flutter/purchases_flutter.dart';

/// The RevenueCat client provider.
final revenueCatClientProvider = FutureProvider((ref) async {
  String? backendHost = Uri.tryParse(await ref.watch(backendUrlSettingsEntryProvider.future))?.host;
  if (backendHost == null) {
    return null;
  }
  User? user = await ref.watch(userProvider.future);
  if (user == null) {
    return null;
  }
  String? apiKey = switch (currentPlatform) {
    Platform.android => AppCredentials.revenueCatPublicKeyAndroid,
    Platform.iOS || Platform.macOS => AppCredentials.revenueCatPublicKeyDarwin,
    Platform.windows => AppCredentials.revenueCatPublicKeyWindows,
    Platform.linux => AppCredentials.revenueCatPublicKeyLinux,
    _ => null,
  };
  if (apiKey == null || apiKey.isEmpty) {
    return null;
  }
  return RevenueCatClient.fromPlatform(
    purchasesConfiguration: PurchasesConfiguration(
      apiKey: apiKey,
      user: user,
    ),
    backendHost: backendHost,
  );
});

/// A RevenueCat client.
abstract class RevenueCatClient {
  /// The RevenueCat's purchases configuration.
  final PurchasesConfiguration purchasesConfiguration;

  /// The purchase timeout.
  final Duration? purchaseTimeout;

  /// The backend host.
  final String backendHost;

  /// Creates a new RevenueCat client instance.
  RevenueCatClient({
    required this.purchasesConfiguration,
    this.purchaseTimeout = Duration.zero,
    required this.backendHost,
  }) : assert(purchasesConfiguration.appUserID != null);

  /// Creates a new RevenueCat client instance that corresponds to the given [platform].
  factory RevenueCatClient.fromPlatform({
    required PurchasesConfiguration purchasesConfiguration,
    Platform? platform,
    required String backendHost,
  }) {
    platform ??= currentPlatform;
    return (switch (platform) {
      Platform.android || Platform.iOS || Platform.macOS => RevenueCatMethodChannelClient.new,
      _ => RevenueCatDartClient.new,
    })(
      purchasesConfiguration: purchasesConfiguration,
      backendHost: backendHost,
    );
  }

  /// Returns the user's attributes.
  @protected
  Map<String, String> get attributes => {
    'backend': backendHost,
  };

  /// Initializes this client instance.
  Future<void> initialize(Ref ref) async {}

  /// Returns the customer info.
  Future<CustomerInfo?> getCustomerInfo();

  /// Returns the offerings.
  Future<Offerings?> getOfferings();

  /// Returns the available package types.
  /// Note that only RevenueCat default identifiers are supported.
  Future<List<PackageType>> getAvailablePackageTypes(String offeringId) async {
    Offerings? offerings = await getOfferings();
    Offering? offering = offerings?.getOffering(offeringId);
    return offering?.availablePackages.map((package) => package.packageType).toList() ?? [];
  }

  /// Purchases the given [purchasable].
  /// Returns whether the user info should be refreshed.
  Future<bool> purchase(Purchasable purchasable, PackageType packageType) async {
    Offerings? offerings = await getOfferings();
    Offering? offering = offerings?.getOffering(purchasable.offeringId);
    if (offering == null) {
      return false;
    }

    Package? package = offering.availablePackages.firstWhereOrNull((package) => package.packageType == packageType);
    if (package != null) {
      return await purchasePackage(package);
    }
    return false;
  }

  /// Purchases the given [package].
  /// Returns whether the user info should be refreshed.
  Future<bool> purchasePackage(Package package);

  /// Returns the prices of the [purchasable].
  Future<Map<PackageType, Price>> getPrices(Purchasable purchasable) async {
    Offerings? offerings = await getOfferings();
    Offering? offering = offerings?.getOffering(purchasable.offeringId);
    if (offering == null) {
      return {};
    }
    Map<PackageType, Price> result = {};
    for (Package package in offering.availablePackages) {
      result[package.packageType] = Price(
        amount: package.storeProduct.price / 100,
        currencyCode: package.storeProduct.currencyCode,
      );
    }
    return result;
  }

  /// Returns the user management URL.
  Future<String?> getManagementUrl() async {
    CustomerInfo? customerInfo = await getCustomerInfo();
    return customerInfo?.managementURL;
  }
}

/// Allows to restore the user purchases.
mixin CanRestorePurchases on RevenueCatClient {
  /// Restores the user purchases, if possible.
  Future<void> restorePurchases();
}

/// Represents a price.
class Price with EquatableMixin {
  /// The raw amount.
  final double amount;

  /// The currency code.
  final String currencyCode;

  /// Creates a new price instance.
  const Price({
    required this.amount,
    required this.currencyCode,
  });

  @override
  List<Object?> get props => [amount, currencyCode];
}

/// Represents a purchasable item.
enum Purchasable {
  /// Allows to subscribe to the Contributor Plan.
  contributorPlan(
    offeringId: AppContributorPlan.offeringId,
  )
  ;

  /// The offering ID.
  final String offeringId;

  /// Creates a new purchasable instance.
  const Purchasable({
    required this.offeringId,
  });
}

/// The purchases configuration object.
class PurchasesConfiguration extends rc_purchases_configuration.PurchasesConfiguration {
  /// The user email.
  String? email;

  /// Creates a new purchases configuration instance.
  PurchasesConfiguration({
    required String apiKey,
    required User user,
  }) : email = user.email,
       super(apiKey) {
    appUserID = user.id;
  }
}
