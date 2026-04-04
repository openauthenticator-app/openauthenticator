import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'package:open_authenticator/model/purchases/contributor_plan.dart';

/// Allows to change the Contributor Plan state for debugging purposes.
class ContributorPlanStateSettingsEntryWidget extends ConsumerWidget with FTileMixin {
  /// Creates a new Contributor Plan state entry widget instance.
  const ContributorPlanStateSettingsEntryWidget({
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    AsyncValue<ContributorPlanState> state = ref.watch(contributorPlanStateProvider);
    return FSelectMenuTile<ContributorPlanState>.fromMap(
      {
        for (ContributorPlanState state in ContributorPlanState.values) state.name: state,
      },
      selectControl: FMultiValueControl.managedRadio(
        initial: state.value ?? ContributorPlanState.impossible,
        onChange: (choices) => ref.read(contributorPlanStateProvider.notifier).debugChangeState(choices.first),
      ),
      enabled: state.hasValue,
      prefix: const Icon(FIcons.bug),
      title: const Text('Contributor Plan state'),
      detailsBuilder: (_, values, _) => Text(values.first.name),
    );
  }
}
