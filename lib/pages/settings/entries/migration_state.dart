import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'package:open_authenticator/model/migrator/migrator.dart';

/// Allows to change the migration state for debugging purposes.
class MigrationStateSettingsEntryWidget extends ConsumerWidget with FTileMixin {
  /// Creates a new migration state settings entry widget instance.
  const MigrationStateSettingsEntryWidget({
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    MigrationState? migrationState = ref.watch(migratorProvider).value;
    return migrationState == null ? const SizedBox.shrink() : FSelectMenuTile<MigrationState>.fromMap(
      {
        'Not needed': .notNeeded,
        'Needed': .needed,
        'Done': .done,
      },
      selectControl: FMultiValueControl.managedRadio(
        initial: migrationState,
        onChange: (choices) => ref.read(migratorProvider.notifier).changeValue(choices.first),
      ),
      prefix: const Icon(FIcons.send),
      title: const Text('Migration state'),
      detailsBuilder: (_, values, _) => Text(values.first.name),
    );
  }
}
