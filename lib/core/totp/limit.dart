import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_authenticator/core/backend/user.dart';
import 'package:open_authenticator/core/settings/storage_type.dart';
import 'package:open_authenticator/core/totp/repository.dart';
import 'package:open_authenticator/core/totp/totp.dart';

/// The TOTP limit provider.
final totpLimitProvider = FutureProvider<TotpLimit>((ref) async {
  final User? user = await ref.watch(userProvider.future);
  final StorageType storageType = await ref.watch(storageTypeSettingsEntryProvider.future);
  final List<Totp> totps = await ref.watch(totpRepositoryProvider.future);
  return TotpLimit._(
    userTotpsLimit: user?.totpsLimit,
    storageType: storageType,
    currentTotpCount: totps.length,
  );
});

/// The class that allows to check whether TOTP limit has been reached.
class TotpLimit with Equatable {
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

  bool _exceedsLimit(int count) => userTotpsLimit != null && count > userTotpsLimit!;

  /// Returns whether adding the entries would exceed the synchronized vault quota.
  bool willExceedIfAddMore({int count = 1}) => storageType == StorageType.shared && _exceedsLimit(currentTotpCount + count);

  /// Whether the existing local vault fits in the account's synchronized vault.
  bool get canEnableSynchronization => !_exceedsLimit(currentTotpCount);

  /// Returns whether the TOTP limit is exceeded.
  bool get isExceeded => willExceedIfAddMore(count: 0);

  @override
  List<Object?> get props => [
    userTotpsLimit,
    storageType,
    currentTotpCount,
  ];
}
