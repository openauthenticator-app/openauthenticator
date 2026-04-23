import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_authenticator/model/purchases/clients/client.dart';
import 'package:purchases_flutter/purchases_flutter.dart' hide Price;

/// Allows to communicate with RevenueCat using its SDK.
class RevenueCatMethodChannelClient extends RevenueCatClient with CanRestorePurchases {
  /// Creates a new RevenueCat method channel client instance.
  RevenueCatMethodChannelClient({
    required super.purchasesConfiguration,
    required super.backendHost,
  });

  @override
  Future<void> initialize(Ref ref) async {
    await Purchases.configure(purchasesConfiguration);
    await Purchases.setAttributes(attributes);
    if (purchasesConfiguration.email != null) {
      await Purchases.setEmail(purchasesConfiguration.email!);
    }
  }

  @override
  Future<CustomerInfo?> getCustomerInfo() => Purchases.getCustomerInfo();

  @override
  Future<Offerings?> getOfferings() => Purchases.getOfferings();

  @override
  Future<bool> purchasePackage(Package package) async {
    await Purchases.purchase(
      PurchaseParams.package(
        package,
        customerEmail: purchasesConfiguration.email,
      ),
    );
    return true;
  }

  @override
  Future<void> restorePurchases() async => await Purchases.restorePurchases();
}
