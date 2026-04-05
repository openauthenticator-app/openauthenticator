import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'package:open_authenticator/i18n/translations.g.dart';
import 'package:open_authenticator/model/backend/user.dart';
import 'package:open_authenticator/model/purchases/contributor_plan.dart';
import 'package:open_authenticator/model/settings/storage_type.dart';
import 'package:open_authenticator/model/totp/limit.dart';
import 'package:open_authenticator/model/totp/repository.dart';
import 'package:open_authenticator/model/totp/totp.dart';
import 'package:open_authenticator/pages/settings/entries/widgets.dart';
import 'package:open_authenticator/utils/storage_migration.dart';

/// Allows the user to choose its storage type.
class SynchronizeSettingsEntryWidget extends CheckboxSettingsEntryWidget<StorageTypeSettingsEntry, StorageType> {
  /// Creates a new synchronize settings entry widget instance.
  SynchronizeSettingsEntryWidget({
    super.key,
    super.icon = FIcons.refreshCcw,
  }) : super(
         provider: storageTypeSettingsEntryProvider,
         title: translations.settings.synchronization.synchronizeTotps.title,
         subtitle: translations.settings.synchronization.synchronizeTotps.subtitle.description,
       );

  /// Creates a new synchronize settings entry widget instance for the intro page.
  SynchronizeSettingsEntryWidget.intro({
    Key? key,
  }) : this(
         key: key,
         icon: null,
       );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    User? user = ref.watch(userProvider).value;
    if (user == null) {
      return const SizedBox.shrink();
    }
    return super.build(context, ref);
  }

  @override
  Widget createTile(BuildContext context, WidgetRef ref, {StorageType? value, bool enabled = true}) {
    if (value == null) {
      return super.createTile(
        context,
        ref,
        enabled: false,
      );
    }
    AsyncValue<ContributorPlanState> state = ref.watch(contributorPlanStateProvider);
    switch (state) {
      case AsyncData():
        switch (state.value) {
          case ContributorPlanState.inactive:
            return FutureBuilder(
              future: ref.watch(totpLimitProvider.future),
              builder: (context, snapshot) => super.createTile(
                context,
                ref,
                value: value,
                enabled: snapshot.data?.isExceeded != true,
              ),
            );
          case ContributorPlanState.active:
            return super.createTile(
              context,
              ref,
              value: value,
              enabled: enabled,
            );
          default:
            return const SizedBox.shrink();
        }
      case AsyncLoading():
      default:
        return super.createTile(
          context,
          ref,
          value: value,
          enabled: value == .shared,
        );
    }
  }

  @override
  Widget? buildSubtitle(BuildContext context, WidgetRef ref, StorageType? storageType) {
    AsyncValue<ContributorPlanState> state = ref.watch(contributorPlanStateProvider);
    if (state is! AsyncData || state.value == ContributorPlanState.active || state.value == ContributorPlanState.impossible) {
      return super.buildSubtitle(
        context,
        ref,
        storageType,
      );
    }
    User user = ref.watch(userProvider).value!;
    AsyncValue<List<Totp>> totps = ref.watch(totpRepositoryProvider);
    if (totps is! AsyncData<List<Totp>>) {
      return Text(translations.settings.synchronization.synchronizeTotps.subtitle.description);
    }
    return Text.rich(
      TextSpan(
        text: translations.settings.synchronization.synchronizeTotps.subtitle.description,
        children: [
          const TextSpan(text: '\n'),
          translations.settings.synchronization.synchronizeTotps.subtitle.totpLimit.limit(
            limit: TextSpan(
              text: user.totpsLimit.toString(),
              style: const TextStyle(fontStyle: FontStyle.italic),
            ),
            count: TextSpan(
              text: totps.value.length.toString(),
              style: const TextStyle(fontStyle: FontStyle.italic),
            ),
          ),
          if (storageType == StorageType.localOnly && totps.value.length > user.totpsLimit)
            TextSpan(
              text: '\n${translations.settings.synchronization.synchronizeTotps.subtitle.totpLimit.notEnabled}',
            ),
          if (storageType == StorageType.shared)
            TextSpan(
              text: '\n${translations.settings.synchronization.synchronizeTotps.subtitle.totpLimit.enabled}',
            ),
        ],
      ),
    );
  }

  @override
  void changeValue(BuildContext context, WidgetRef ref, bool newValue) => StorageMigrationUtils.changeStorageType(context, ref, newValue ? StorageType.shared : StorageType.localOnly);

  @override
  bool isEnabled(StorageType? storageType) => storageType == StorageType.shared;
}
