part of 'method.dart';

/// Local authentication.
class LocalAuthenticationAppUnlockMethod extends AppUnlockMethod {
  /// The local authentication app unlock method id.
  static const String kMethodId = 'localAuthentication';

  /// Creates a new local authentication app unlock method instance.
  const LocalAuthenticationAppUnlockMethod._({
    required super.ref,
  }) : super(
         id: kMethodId,
       );

  @override
  Future<Result> _tryUnlock(AppUnlockInteraction interaction, UnlockReason reason) async {
    bool result = await LocalAuthentication.instance.authenticate(reason);
    return result ? const ResultSuccess() : const ResultCancelled();
  }

  @override
  Future<CannotUnlockException?> canUnlock(UnlockReason reason) async {
    if (!(await LocalAuthentication.instance.isSupported())) {
      return LocalAuthenticationDeviceNotSupported();
    }
    return null;
  }
}

/// Indicates that local authentication is not supported by the device.
class LocalAuthenticationDeviceNotSupported extends CannotUnlockException {
  /// Creates a new local authentication device not supported exception instance.
  LocalAuthenticationDeviceNotSupported()
    : super(
        localizedErrorMessage: translations.error.appUnlock.localAuthenticationDeviceNotSupported,
      );
}
