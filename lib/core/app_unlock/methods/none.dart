part of 'method.dart';

/// No unlock.
class NoneAppUnlockMethod extends AppUnlockMethod {
  /// The none app unlock method id.
  static const String kMethodId = 'none';

  /// Creates a new none app unlock method instance.
  const NoneAppUnlockMethod._({
    required super.ref,
  }) : super(
         id: kMethodId,
       );

  @override
  Future<Result> _tryUnlock(AppUnlockInteraction interaction, UnlockReason reason) => Future.value(const ResultSuccess());

  @override
  AppLockState get defaultAppLockState => AppLockState.unlocked;
}
