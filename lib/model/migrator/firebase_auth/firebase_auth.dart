import 'dart:async';

import 'package:flutter/material.dart';
import 'package:open_authenticator/i18n/translations.g.dart';
import 'package:open_authenticator/model/migrator/firebase_auth/default.dart';
import 'package:open_authenticator/model/migrator/firebase_auth/rest.dart';
import 'package:open_authenticator/model/migrator/firebase_auth/stub.dart';
import 'package:open_authenticator/utils/platform.dart';

/// Allows to either use FlutterFire's Firebase Auth implementation or fallback to the REST API if needed.
abstract class FirebaseAuth {
  /// The current [FirebaseAuth] instance.
  static FirebaseAuth? _instance;

  /// The current locale.
  String _currentLocale = LocaleSettings.currentLocale.languageCode;

  /// The locale change stream subscription.
  StreamSubscription<AppLocale>? _localeStreamSubscription;

  /// Returns the [FirebaseAuth] instance corresponding to the current platform.
  static FirebaseAuth get instance {
    _instance ??= switch (currentPlatform) {
      Platform.android || Platform.iOS || Platform.macOS => FirebaseAuthDefault(),
      Platform.windows => FirebaseAuthRest(),
      _ => FirebaseAuthSub(),
    };
    return _instance!;
  }

  /// Returns the current locale.
  String get locale => _currentLocale;

  /// Initializes the current instance.
  @mustCallSuper
  FutureOr<void> initialize() => _localeStreamSubscription = LocaleSettings.getLocaleStream().listen((locale) => onLocaleChange(locale.languageCode));

  /// Triggered when the locale has changed.
  @mustCallSuper
  @protected
  void onLocaleChange(String newLocale) {
    _currentLocale = newLocale;
  }

  /// Returns the user changes stream.
  Stream<User?> get userChanges;

  /// Returns the current user, if logged in.
  User? get currentUser;

  /// Returns whether the user is logged in.
  bool get isLoggedIn => currentUser != null;

  /// Sign ins the user with a given method.
  Future<SignInResult> signInWith(FirebaseAuthMethod method) => method.signIn();

  /// Unlinks the user from a given method.
  Future<SignInResult> unlinkFrom(String providerId);

  /// Sign-outs the current user.
  Future<void> signOut();

  /// Deletes the user.
  /// He may need to be recently authenticated.
  Future<void> deleteUser();

  /// Disposes this instance.
  void dispose() {
    _localeStreamSubscription?.cancel();
    _localeStreamSubscription = null;
    if (FirebaseAuth._instance == this) {
      FirebaseAuth._instance = null;
    }
  }
}

/// Holds some info about the current user.
abstract class User {
  /// The user unique id.
  String get uid;

  /// The user email.
  String? get email;

  /// The user providers list.
  List<String> get providers;

  /// Should return the user id token.
  Future<String?> getIdToken({bool forceRefresh = false});

  /// Reloads the current user.
  Future<void> reload();

  /// Re-authenticates the user with a given method.
  Future<SignInResult> reAuthenticateWith(FirebaseAuthMethod method) async => await method.reAuthenticate(this);

  /// Links the user to a given method.
  Future<SignInResult> linkTo(CanLinkTo method) async => await method.linkTo(this);
}

/// A Firebase authentication method.
mixin FirebaseAuthMethod {
  /// Sign ins using this method.
  @protected
  Future<SignInResult> signIn();

  /// Reauthenticates the current user.
  @protected
  Future<SignInResult> reAuthenticate(User user);
}

/// A [FirebaseAuthMethod] that an user can links its account to.
mixin CanLinkTo on FirebaseAuthMethod {
  /// Links the method to the current user.
  @protected
  Future<SignInResult> linkTo(User user);
}

/// Authenticates using Apple.
abstract class AppleAuthMethod with FirebaseAuthMethod, CanLinkTo {
  /// The provider id.
  static const String providerId = 'apple.com';

  /// Creates a new default Apple auth method instance.
  factory AppleAuthMethod.defaultMethod({
    List<String> scopes = const [],
    Map<String, String> customParameters = const {},
  }) => AppleAuthMethodDefault(
    scopes: scopes,
    customParameters: customParameters,
  );

  /// Creates a new REST Apple auth method instance.
  factory AppleAuthMethod.rest({
    String? idToken,
    String? nonce,
  }) => AppleAuthMethodRest(
    idToken: idToken,
    nonce: nonce,
  );

  /// Creates a new Apple auth method instance.
  const AppleAuthMethod();
}

/// Authenticates using an email link.
abstract class EmailLinkAuthMethod with FirebaseAuthMethod {
  /// The provider id.
  static const String providerId = 'password';

  /// Creates a new default email link auth method instance.
  factory EmailLinkAuthMethod.defaultMethod({
    required String email,
    required String emailLink,
  }) => EmailLinkAuthMethodDefault(
    email: email,
    emailLink: emailLink,
  );

  /// Creates a new REST email link auth method instance.
  factory EmailLinkAuthMethod.rest({
    required String email,
    required String oobCode,
  }) => EmailLinkAuthMethodRest(
    email: email,
    oobCode: oobCode,
  );

  /// Creates a new email link auth method instance.
  const EmailLinkAuthMethod();
}

/// Authenticates using Github.
abstract class GithubAuthMethod with FirebaseAuthMethod, CanLinkTo {
  /// The provider id.
  static const String providerId = 'github.com';

  /// Creates a new default Github auth method instance.
  factory GithubAuthMethod.defaultMethod({
    List<String> scopes = const [],
    Map<String, String> customParameters = const {},
  }) => GithubAuthMethodDefault(
    scopes: scopes,
    customParameters: customParameters,
  );

  /// Creates a new REST Github auth method instance.
  factory GithubAuthMethod.rest({
    String? accessToken,
  }) => GithubAuthMethodRest(
    accessToken: accessToken,
  );

  /// Creates a new Github auth method instance.
  const GithubAuthMethod();
}

/// Authenticates using Google.
abstract class GoogleAuthMethod with FirebaseAuthMethod, CanLinkTo {
  /// The provider id.
  static const String providerId = 'google.com';

  /// Creates a new default Google auth method instance.
  factory GoogleAuthMethod.defaultMethod({
    List<String> scopes = const [],
    Map<String, String> customParameters = const {},
  }) => GoogleAuthMethodDefault(
    scopes: scopes,
    customParameters: customParameters,
  );

  /// Creates a new REST Google auth method instance.
  factory GoogleAuthMethod.rest({
    String? accessToken,
    String? idToken,
  }) => GoogleAuthMethodRest(
    accessToken: accessToken,
    idToken: idToken,
  );

  /// Creates a new Google auth method instance.
  const GoogleAuthMethod();
}

/// Authenticates using Microsoft.
abstract class MicrosoftAuthMethod with FirebaseAuthMethod, CanLinkTo {
  /// The provider id.
  static const String providerId = 'microsoft.com';

  /// Creates a new default Microsoft auth method instance.
  factory MicrosoftAuthMethod.defaultMethod({
    List<String> scopes = const [],
    Map<String, String> customParameters = const {},
  }) => MicrosoftAuthMethodDefault(
    scopes: scopes,
    customParameters: customParameters,
  );

  /// Creates a new REST Microsoft auth method instance.
  factory MicrosoftAuthMethod.rest({
    String? accessToken,
    String? idToken,
    String? nonce,
  }) => MicrosoftAuthMethodRest(
    accessToken: accessToken,
    idToken: idToken,
    nonce: nonce,
  );

  /// Creates a new Microsoft auth method instance.
  const MicrosoftAuthMethod();
}

/// Authenticates using Twitter.
abstract class TwitterAuthMethod with FirebaseAuthMethod, CanLinkTo {
  /// The provider id.
  static const String providerId = 'twitter.com';

  /// Creates a new default Twitter auth method instance.
  factory TwitterAuthMethod.defaultMethod({
    Map<String, String> customParameters = const {},
  }) => TwitterAuthMethodDefault(
    customParameters: customParameters,
  );

  /// Creates a new REST Microsoft auth method instance.
  factory TwitterAuthMethod.rest({
    String? accessToken,
  }) => TwitterAuthMethodRest(
    accessToken: accessToken,
  );

  /// Creates a new Twitter auth method instance.
  const TwitterAuthMethod();
}

/// Holds a sign-in result.
class SignInResult {
  /// The user email.
  final String? email;

  /// Whether the email is verified.
  final bool? emailVerified;

  /// The user unique id.
  final String? localId;

  /// The provider id.
  final String? providerId;

  /// The id token.
  final String? idToken;

  /// The refresh token.
  final String? refreshToken;

  /// The number of seconds in which the ID token expires.
  final int? expiresIn;

  /// Creates a new sign-in result instance.
  const SignInResult({
    this.email,
    this.emailVerified,
    this.localId,
    this.providerId,
    this.idToken,
    this.refreshToken,
    this.expiresIn,
  });
}
