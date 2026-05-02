import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_authenticator/flows/app_flow.dart';
import 'package:open_authenticator/pages/contributor_plan_paywall/page.dart';

/// The contributor plan flow provider.
final contributorPlanFlowProvider = Provider.autoDispose<ContributorPlanFlow>(ContributorPlanFlow.new);

/// Coordinates contributor plan user flows.
class ContributorPlanFlow extends AppFlow {
  /// Creates a new contributor plan flow instance.
  const ContributorPlanFlow(super.ref);

  /// Subscribe to the Contributor Plan.
  Future<bool> purchase(BuildContext context) => keepAliveWhile(() async {
    Object? result = await Navigator.pushNamed(context, ContributorPlanPaywallPage.name);
    return result == true;
  });
}
