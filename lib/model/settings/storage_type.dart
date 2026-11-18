import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_authenticator/model/settings/entry.dart';

/// The storage type settings entry provider.
final AsyncNotifierProvider<StorageTypeSettingsEntry, StorageType> storageTypeSettingsEntryProvider = AsyncNotifierProvider.autoDispose<StorageTypeSettingsEntry, StorageType>(
  StorageTypeSettingsEntry.new,
);

/// A settings entry that allows to get and set the storage type.
/// Changing the storage type of an existing installation should go through the [StorageMigrator].
class StorageTypeSettingsEntry extends EnumSettingsEntry<StorageType> {
  /// Creates a new storage type settings entry instance.
  StorageTypeSettingsEntry()
    : super(
        key: 'storageType',
        defaultValue: StorageType.localOnly,
      );

  @override
  @protected
  List<StorageType> get values => StorageType.values;
}

/// Contains all storage types.
enum StorageType {
  /// Local storage, using Drift.
  localOnly,

  /// Local storage and online storage.
  shared,
}
