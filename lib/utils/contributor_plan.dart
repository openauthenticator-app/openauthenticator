import 'package:flutter/material.dart';
import 'package:open_authenticator/pages/contributor_plan_paywall/page.dart';
import 'package:open_authenticator/utils/result.dart';

/// Contains some useful methods for subscribing to the Contributor Plan.
class ContributorPlanUtils {
  /// Subscribe to the Contributor Plan.
  static Future<Result> purchase(BuildContext context) async {
    Object? result = await Navigator.pushNamed(context, ContributorPlanPaywallPage.name);
    return result == true ? const ResultSuccess() : const ResultCancelled();
  }
}
