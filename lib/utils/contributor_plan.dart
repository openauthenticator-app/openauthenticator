import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_authenticator/model/purchases/contributor_plan.dart';
import 'package:open_authenticator/pages/contributor_plan_paywall/page.dart';
import 'package:open_authenticator/utils/result.dart';
import 'package:open_authenticator/widgets/waiting_overlay.dart';

/// Contains some useful methods for subscribing to the Contributor Plan.
class ContributorPlanUtils {
  /// Subscribe to the Contributor Plan.
  static Future<Result> purchase(BuildContext context, WidgetRef ref) async {
    Object? result = await Navigator.pushNamed(context, ContributorPlanPaywallPage.name);
    if (result == true || result == null) {
      if (!context.mounted) {
        return const ResultCancelled();
      }
      Result<ContributorPlanState> result = await showWaitingOverlay(
        context,
        future: (() async {
          await Future.delayed(const Duration(seconds: 5));
          return await ref.read(contributorPlanStateProvider.notifier).refresh();
        })(),
      );
      return result;
    }
    return const ResultCancelled();
  }
}
