part of 'provider.dart';

/// The email authentication provider.
final emailAuthenticationProvider = Provider<EmailAuthenticationProvider>(
  (ref) => EmailAuthenticationProvider._(
    ref: ref,
  ),
);

/// The email authentication provider.
class EmailAuthenticationProvider extends AuthenticationProvider {
  /// The email authentication provider id.
  static const String kProviderId = 'email';

  /// Creates a new email authentication provider instance.
  const EmailAuthenticationProvider._({
    required super.ref,
  }) : super(
         id: kProviderId,
       );

  @override
  Future<Result> onRedirectReceived(Uri uri) async {
    if (uri.host == 'auth' && uri.path == '/provider/email/sent') {
      String? cancelCode = uri.queryParameters['cancelCode'];
      if (cancelCode == null) {
        return ResultError(exception: uri.queryParameters['previously']?.toLowerCase() == 'true' ? const _EmailAlreadySentException() : const _NoCancelCodeException());
      }
      _ref.read(emailConfirmationStateProvider.notifier)._markNeedsConfirmation(uri.queryParameters['email']!, uri.queryParameters['cancelCode']!);
      return const ResultSuccess();
    }
    Result result = await super.onRedirectReceived(uri);
    if (result is ResultSuccess) {
      await _ref.read(emailConfirmationStateProvider.notifier)._cancelConfirmation();
    }
    return result;
  }

  /// Requests to sign in.
  Future<Result> requestSignIn(String email) => _requestLogin(email, link: false);

  /// Requests to link.
  Future<Result> requestLinking(String email) => _requestLogin(email, link: true);

  /// Requests a login for either signing in or linking.
  Future<Result> _requestLogin(String email, {bool link = false}) async {
    String backendUrl = await _ref.read(backendUrlSettingsEntryProvider.future);
    String uriPrefix = '$backendUrl/auth/provider/$id/redirect?email=$email';
    Uri uri;
    if (link) {
      User? user = await _ref.read(userProvider.future);
      uri = Uri.parse('$uriPrefix&mode=link&userId=${user!.id}');
    } else {
      uri = Uri.parse('$uriPrefix&mode=login');
    }
    await launchUrl(uri);
    return const ResultSuccess();
  }

  /// Confirms the email.
  Future<Result> confirm(String verificationCode) async {
    try {
      EmailConfirmationData? data = await _ref.read(emailConfirmationStateProvider.future);
      if (data == null) {
        throw Exception('No email to confirm.');
      }
      Result<EmailConfirmResponse> response = await _ref
          .read(backendClientProvider.notifier)
          .sendHttpRequest(
            EmailConfirmRequest(
              email: data.email,
              verificationCode: verificationCode,
            ),
          );
      if (response is! ResultSuccess<EmailConfirmResponse>) {
        return response;
      }
      Uri uri = response.value.url;
      return await onRedirectReceived(uri);
    } catch (ex, stackTrace) {
      return ResultError(
        exception: ex,
        stackTrace: stackTrace,
      );
    }
  }

  /// Cancels the confirmation.
  Future<Result> cancelConfirmation() async {
    try {
      EmailConfirmationData? data = await _ref.read(emailConfirmationStateProvider.future);
      if (data == null) {
        return const ResultSuccess();
      }
      Result<EmailConfirmationCancelResponse> response = await _ref
          .read(backendClientProvider.notifier)
          .sendHttpRequest(
            EmailConfirmationCancelRequest(
              email: data.email,
              cancelCode: data.cancelCode,
            ),
          );
      if (response is! ResultSuccess<EmailConfirmationCancelResponse>) {
        return response;
      }
      await _ref.read(emailConfirmationStateProvider.notifier)._cancelConfirmation();
      return const ResultSuccess();
    } catch (ex, stackTrace) {
      return ResultError(
        exception: ex,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  User _changeId(User user, String providerUserId) => user.copyWith(email: providerUserId);
}

/// The email confirmation state provider.
final emailConfirmationStateProvider = AsyncNotifierProvider<EmailConfirmationStateNotifier, EmailConfirmationData?>(EmailConfirmationStateNotifier.new);

/// The email confirmation state notifier.
class EmailConfirmationStateNotifier extends AsyncNotifier<EmailConfirmationData?> {
  /// The preferences key where the email is temporally stored.
  static const String _kAuthenticationEmailKey = 'authenticationEmail';

  /// The preferences key where the cancel code is temporally stored.
  static const String _kAuthenticationEmailCancelCodeKey = 'authenticationEmailCancelCode';

  @override
  FutureOr<EmailConfirmationData?> build() async {
    SharedPreferencesWithPrefix preferences = await ref.read(sharedPreferencesProvider.future);
    String? email = preferences.getString(_kAuthenticationEmailKey);
    String? cancelCode = preferences.getString(_kAuthenticationEmailCancelCodeKey);
    return email == null || cancelCode == null
        ? null
        : EmailConfirmationData(
            email: email,
            cancelCode: cancelCode,
          );
  }

  /// Marks the [email] for confirmation with the given cancel code.
  Future<void> _markNeedsConfirmation(String email, String cancelCode) async {
    if ((await future) != null) {
      return;
    }
    SharedPreferencesWithPrefix preferences = await ref.read(sharedPreferencesProvider.future);
    await preferences.setString(_kAuthenticationEmailKey, email);
    await preferences.setString(_kAuthenticationEmailCancelCodeKey, cancelCode);
    state = AsyncData(
      EmailConfirmationData(
        email: email,
        cancelCode: cancelCode,
      ),
    );
  }

  /// Cancels the confirmation.
  Future<void> _cancelConfirmation() async {
    SharedPreferencesWithPrefix preferences = await ref.read(sharedPreferencesProvider.future);
    await preferences.remove(_kAuthenticationEmailKey);
    await preferences.remove(_kAuthenticationEmailCancelCodeKey);
    state = const AsyncData(null);
  }
}

/// The email confirmation data.
class EmailConfirmationData with EquatableMixin {
  /// The email.
  final String email;

  /// The cancel code.
  final String cancelCode;

  /// Creates a new email confirmation data instance.
  const EmailConfirmationData({
    required this.email,
    required this.cancelCode,
  });

  @override
  List<Object?> get props => [
    email,
    cancelCode,
  ];
}

/// Triggered when the email has already been sent.
class _NoCancelCodeException implements Exception {
  /// Creates a new no cancel code exception instance.
  const _NoCancelCodeException();

  @override
  String toString() => 'No cancel code.';
}

/// Triggered when the email has already been sent.
class _EmailAlreadySentException implements Exception {
  /// Creates a new email already sent exception instance.
  const _EmailAlreadySentException();

  @override
  String toString() => 'Email already sent.';
}
