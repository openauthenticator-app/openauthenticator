import 'dart:async';

import 'package:open_authenticator/model/purchases/clients/client.dart';
import 'package:open_authenticator/utils/result.dart';
import 'package:purchases_dart/purchases_dart.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

/// Allows to communicate with RevenueCat thanks to its REST api.
class RevenueCatDartClient extends RevenueCatClient {
  /// Creates a new RevenueCat REST client instance.
  RevenueCatDartClient({
    required super.purchasesConfiguration,
  });

  @override
  Future<void> initialize() async {
    await _PurchasesDartConfigurator.configure(
      PurchasesDartConfiguration(
        webBillingApiKey: purchasesConfiguration.apiKey,
        appUserId: purchasesConfiguration.appUserID,
      ),
    );
  }

  @override
  Future<CustomerInfo?> getCustomerInfo() => PurchasesDart.getCustomerInfo();

  @override
  Future<Offerings?> getOfferings() => PurchasesDart.getOfferings();

  @override
  Future<void> purchasePackage(Package package) async {
    Uri? webCheckoutUrl = await PurchasesDart.getWebCheckoutUrl(
      package,
      email: purchasesConfiguration.email,
    );
    if (webCheckoutUrl != null && (await canLaunchUrl(webCheckoutUrl))) {
      await launchUrl(webCheckoutUrl);
    }
  }

  @override
  Future<Result> restorePurchases() async {
    await PurchasesDart.updateAppUserId(purchasesConfiguration.appUserID!);
    return const ResultCancelled();
  }
}

/// The PurchasesDart configurator.
class _PurchasesDartConfigurator {
  /// Whether the PurchasesDart has been configured.
  static bool isConfigured = false;

  /// Sets up Purchases with your API key and an app user id.
  static Future<void> configure(PurchasesDartConfiguration configuration) async {
    if (!isConfigured) {
      await PurchasesDart.configure(configuration);
      isConfigured = true;
    }
  }
}
