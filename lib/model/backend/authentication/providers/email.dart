part of 'provider.dart';

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
  Future<Result<RedirectResult>> onRedirectReceived(Uri uri) async {
    if (uri.host == 'auth' && uri.path == '/provider/email/sent') {
      String? cancelCode = uri.queryParameters['cancelCode'];
      if (cancelCode == null) {
        return ResultError(
          exception: uri.queryParameters['previously']?.toLowerCase() == 'true' ? _EmailAlreadySentException() : _NoCancelCodeException(),
        );
      }
      _ref.read(emailConfirmationStateProvider.notifier)._markNeedsConfirmation(uri.queryParameters['email']!, uri.queryParameters['cancelCode']!);
      return ResultSuccess(value: ConfirmationEmailSent(providerId: id));
    }
    Result<RedirectResult> result = await super.onRedirectReceived(uri);
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
    UriBuilder uriBuilder = UriBuilder.prefix(
      prefix: backendUrl,
      path: '/auth/provider/$id/redirect',
      queryParameters: {
        'email': email,
        'locale': LocaleSettings.currentLocale.languageCode,
      },
    );
    if (link) {
      User? user = await _ref.read(userProvider.future);
      uriBuilder.appendQueryParameter('userId', user!.id);
      uriBuilder.appendQueryParameter('mode', 'link');
    } else {
      uriBuilder.appendQueryParameter('mode', 'login');
    }
    uriBuilder.appendQueryParameter('timestamp', DateTime.now().millisecondsSinceEpoch.toString());
    await launchUrl(uriBuilder.build());
    return const ResultSuccess();
  }

  /// Confirms the email.
  Future<Result<RedirectResult>> confirm(String verificationCode) async {
    try {
      EmailConfirmationData? data = await _ref.read(emailConfirmationStateProvider.future);
      if (data == null) {
        throw _NoEmailToConfirmException();
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
        if (response is ResultError<EmailConfirmResponse> && response.exception is ExpiredCodeError) {
          await _ref.read(emailConfirmationStateProvider.notifier)._cancelConfirmation();
        }
        return response.to((_) => null);
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
  User _changeId(User user, String? providerUserId) => user.updateEmail(providerUserId);
}

/// Triggered when the email has been sent.
class ConfirmationEmailSent extends RedirectResult {
  /// Creates a new confirmation email sent instance.
  const ConfirmationEmailSent({
    required super.providerId,
  });

  @override
  String get localizedMessage => translations.authentication.logIn.successNeedConfirmation;
}

/// The email confirmation state provider.
final emailConfirmationStateProvider = AsyncNotifierProvider.autoDispose<EmailConfirmationStateNotifier, EmailConfirmationData?>(EmailConfirmationStateNotifier.new);

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
    if (ref.mounted) {
      state = AsyncData(
        EmailConfirmationData(
          email: email,
          cancelCode: cancelCode,
        ),
      );
    }
  }

  /// Cancels the confirmation.
  Future<void> _cancelConfirmation() async {
    SharedPreferencesWithPrefix preferences = await ref.read(sharedPreferencesProvider.future);
    await preferences.remove(_kAuthenticationEmailKey);
    await preferences.remove(_kAuthenticationEmailCancelCodeKey);
    if (ref.mounted) {
      state = const AsyncData(null);
    }
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

/// Triggered when there is no email to confirm.
class _NoEmailToConfirmException extends LocalizableException {
  /// Creates a new no email to confirm exception instance.
  _NoEmailToConfirmException()
    : super(
        localizedErrorMessage: translations.error.backend.noEmailToConfirm,
      );
}

/// Triggered when the email has already been sent.
class _EmailAlreadySentException extends LocalizableException {
  /// Creates a new email already sent exception instance.
  _EmailAlreadySentException()
    : super(
        localizedErrorMessage: translations.error.backend.emailAlreadySent,
      );
}

/// Triggered when no cancel code has been provided by the server.
class _NoCancelCodeException extends LocalizableException {
  /// Creates a new no cancel code exception instance.
  _NoCancelCodeException()
    : super(
        localizedErrorMessage: translations.error.backend.noCancelCode,
      );
}
