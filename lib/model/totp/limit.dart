import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_authenticator/model/backend/user.dart';
import 'package:open_authenticator/model/settings/storage_type.dart';
import 'package:open_authenticator/model/totp/repository.dart';
import 'package:open_authenticator/model/totp/totp.dart';

/// The TOTP limit provider.
final totpLimitProvider = FutureProvider<TotpLimit>((ref) async {
  User? user = await ref.watch(userProvider.future);
  StorageType storageType = await ref.watch(storageTypeSettingsEntryProvider.future);
  List<Totp> totps = await ref.watch(totpRepositoryProvider.future);
  return TotpLimit._(
    userTotpsLimit: user?.totpsLimit,
    storageType: storageType,
    currentTotpCount: totps.length,
  );
});

/// The class that allows to check whether TOTP limit has been reached.
class TotpLimit {
  /// The user TOTPs limit.
  final int? userTotpsLimit;

  /// The storage type.
  final StorageType storageType;

  /// The current TOTP count.
  final int currentTotpCount;

  /// Creates a new TOTP limit instance.
  const TotpLimit._({
    this.userTotpsLimit,
    required this.storageType,
    required this.currentTotpCount,
  });

  /// Returns whether the limit will be exceeded if one more TOTP is added.
  bool _willExceedIfAddMore({
    int count = 1,
    StorageType? storageType,
  }) => (storageType ?? this.storageType) == StorageType.shared && userTotpsLimit != null && currentTotpCount + count > userTotpsLimit!;

  /// Returns whether the limit will be exceeded if one more TOTP is added.
  bool willExceedIfAddMore({int count = 1}) => _willExceedIfAddMore(
    count: count,
  );

  /// Returns whether the user should be able to change the current storage type.
  bool canChangeStorageType(StorageType? currentStorageType) {
    currentStorageType ??= storageType == StorageType.shared ? StorageType.localOnly : StorageType.shared;
    if (currentStorageType == StorageType.shared) {
      return true;
    }
    return !_willExceedIfAddMore(
      count: 0,
      storageType: currentStorageType == StorageType.shared ? StorageType.localOnly : StorageType.shared,
    );
  }

  /// Returns whether the TOTP limit is exceeded.
  bool get isExceeded => willExceedIfAddMore(count: 0);
}
