import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/material.dart';
import 'package:open_authenticator/model/migrator/firebase_auth/firebase_auth.dart';

/// Uses FlutterFire's Firebase implementation.
class FirebaseAuthDefault extends FirebaseAuth {
  /// The current user instance.
  FirebaseAuthUser? _currentUser;

  /// The instance user stream subscription.
  StreamSubscription<FirebaseAuthUser?>? _userStreamSubscription;

  /// The user changes stream controller.
  final StreamController<FirebaseAuthUser?> _userChangesStreamController = StreamController<FirebaseAuthUser?>.broadcast();

  @override
  Future<void> initialize() async {
    await super.initialize();
    await firebase_auth.FirebaseAuth.instance.setLanguageCode(locale);
    firebase_auth.User? user = firebase_auth.FirebaseAuth.instance.currentUser;
    _currentUser = _createUserFromFirebaseUser(user);
    _userStreamSubscription = firebase_auth.FirebaseAuth.instance.userChanges().map(_createUserFromFirebaseUser).listen((user) {
      _currentUser = user;
      _userChangesStreamController.add(user);
    });
  }

  @override
  FirebaseAuthUser? get currentUser => _currentUser;

  @override
  void onLocaleChange(String newLocale) {
    super.onLocaleChange(newLocale);
    firebase_auth.FirebaseAuth.instance.setLanguageCode(newLocale);
  }

  @override
  Future<SignInResult> unlinkFrom(String providerId) async {
    if (_currentUser == null) {
      throw Exception('User must be logged in.');
    }
    firebase_auth.User user = await _currentUser!.unlinkFromProvider(providerId);
    return SignInResult(
      email: user.email,
      localId: user.uid,
    );
  }

  @override
  Future<void> signOut() => firebase_auth.FirebaseAuth.instance.signOut();

  @override
  Future<void> deleteUser() async => await _currentUser?._firebaseUser.delete();

  @override
  Stream<FirebaseAuthUser?> get userChanges => _userChangesStreamController.stream;

  @override
  void dispose() {
    super.dispose();
    _userStreamSubscription?.cancel();
    _userStreamSubscription = null;
    _userChangesStreamController.close();
  }

  /// Creates an [FirebaseAuthUser] instance from a Firebase user instance.
  FirebaseAuthUser? _createUserFromFirebaseUser(firebase_auth.User? firebaseUser) {
    if (firebaseUser == null) {
      return null;
    }
    return FirebaseAuthUser(firebaseUser);
  }
}

/// An user, linked to a [firebase_auth.User].
class FirebaseAuthUser extends User {
  /// The Firebase user instance.
  final firebase_auth.User _firebaseUser;

  /// Creates a new Firebase auth user.
  FirebaseAuthUser(firebase_auth.User firebaseUser) : _firebaseUser = firebaseUser;

  @override
  String get uid => _firebaseUser.uid;

  @override
  String? get email => _firebaseUser.email;

  @override
  List<String> get providers => [
    for (firebase_auth.UserInfo userInfo in _firebaseUser.providerData) userInfo.providerId,
  ];

  @override
  Future<String?> getIdToken({bool forceRefresh = false}) async => await _firebaseUser.getIdToken(forceRefresh);

  @override
  Future<void> reload() async => _firebaseUser.reload();

  /// Links the current user to the given [provider].
  Future<firebase_auth.UserCredential> linkWithProvider(firebase_auth.AuthProvider provider) => _firebaseUser.linkWithProvider(provider);

  /// Re-authenticates the current user using the given [provider].
  Future<firebase_auth.UserCredential> reAuthenticateWithProvider(firebase_auth.AuthProvider provider) => _firebaseUser.reauthenticateWithProvider(provider);

  /// Unlinks the current user from the given [providerId].
  Future<firebase_auth.User> unlinkFromProvider(String providerId) => _firebaseUser.unlink(providerId);
}

/// Authenticates using a [firebase_auth.AuthProvider].
mixin _ProviderAuthMethod on FirebaseAuthMethod, CanLinkTo {
  @override
  @protected
  Future<SignInResult> signIn() async {
    firebase_auth.UserCredential credential = await firebase_auth.FirebaseAuth.instance.signInWithProvider(_createAuthProvider());
    return await credentialToResult(credential);
  }

  @override
  Future<SignInResult> reAuthenticate(User user) async {
    assert(user is FirebaseAuthUser, 'You must use this class with FirebaseAuthDefault.');
    firebase_auth.UserCredential credential = await (user as FirebaseAuthUser).reAuthenticateWithProvider(_createAuthProvider());
    return await credentialToResult(credential);
  }

  @override
  @protected
  Future<SignInResult> linkTo(User user) async {
    assert(user is FirebaseAuthUser, 'You must use this class with FirebaseAuthDefault.');
    firebase_auth.UserCredential credential = await (user as FirebaseAuthUser).linkWithProvider(_createAuthProvider());
    return await credentialToResult(credential);
  }

  /// Creates a [SignInResult] from a given [credential].
  Future<SignInResult> credentialToResult(firebase_auth.UserCredential credential) async => SignInResult(
    email: credential.user?.email,
    localId: credential.user?.uid,
    providerId: credential.credential?.providerId,
    idToken: await credential.user?.getIdToken(),
    refreshToken: credential.user?.refreshToken,
  );

  /// Creates the corresponding [firebase_auth.AuthProvider].
  firebase_auth.AuthProvider _createAuthProvider();
}

/// Authenticates using Apple with a Firebase provider.
class AppleAuthMethodDefault extends AppleAuthMethod with _ProviderAuthMethod {
  /// The OAuth scopes.
  final List<String> scopes;

  /// The custom parameters to pass to the provider.
  final Map<String, String> customParameters;

  /// Creates a new Apple auth method instance.
  const AppleAuthMethodDefault({
    this.scopes = const [],
    this.customParameters = const {},
  });

  @override
  firebase_auth.AppleAuthProvider _createAuthProvider() {
    firebase_auth.AppleAuthProvider appleProvider = firebase_auth.AppleAuthProvider();
    scopes.forEach(appleProvider.addScope);
    appleProvider.addScope('email');
    appleProvider.setCustomParameters(customParameters);
    return appleProvider;
  }
}

/// Authenticates using an email link.
class EmailLinkAuthMethodDefault extends EmailLinkAuthMethod {
  /// The email that has requested the authentication.
  final String email;

  /// The email link to use.
  final String emailLink;

  /// Creates a new email link auth method instance.
  const EmailLinkAuthMethodDefault({
    required this.email,
    required this.emailLink,
  });

  @override
  Future<SignInResult> signIn() async {
    firebase_auth.UserCredential credential = await firebase_auth.FirebaseAuth.instance.signInWithEmailLink(
      email: email,
      emailLink: emailLink,
    );
    return SignInResult(
      email: credential.user?.email ?? email,
      localId: credential.user?.uid,
      providerId: credential.credential?.providerId,
      idToken: await credential.user?.getIdToken(),
      refreshToken: credential.user?.refreshToken,
    );
  }

  @override
  Future<SignInResult> reAuthenticate(User user) async => await signIn();

  /// Sends a sign-in link to the email.
  static Future<void> sendSignInLink(String email, ActionCodeSettings settings) => firebase_auth.FirebaseAuth.instance.sendSignInLinkToEmail(
    email: email,
    actionCodeSettings: settings,
  );
}

/// Authenticates using Github with a Firebase provider.
class GithubAuthMethodDefault extends GithubAuthMethod with _ProviderAuthMethod {
  /// The OAuth scopes.
  final List<String> scopes;

  /// The custom parameters to pass to the provider.
  final Map<String, String> customParameters;

  /// Creates a new Github auth method instance.
  const GithubAuthMethodDefault({
    this.scopes = const [],
    this.customParameters = const {},
  });

  @override
  firebase_auth.GithubAuthProvider _createAuthProvider() {
    firebase_auth.GithubAuthProvider githubAuthProvider = firebase_auth.GithubAuthProvider();
    scopes.forEach(githubAuthProvider.addScope);
    githubAuthProvider.setCustomParameters(customParameters);
    return githubAuthProvider;
  }
}

/// Authenticates using Google with a Firebase provider.
class GoogleAuthMethodDefault extends GoogleAuthMethod with _ProviderAuthMethod {
  /// The OAuth scopes.
  final List<String> scopes;

  /// The custom parameters to pass to the provider.
  final Map<String, String> customParameters;

  /// Creates a new Google auth method instance.
  const GoogleAuthMethodDefault({
    this.scopes = const [],
    this.customParameters = const {},
  });

  @override
  firebase_auth.GoogleAuthProvider _createAuthProvider() {
    firebase_auth.GoogleAuthProvider googleAuthProvider = firebase_auth.GoogleAuthProvider();
    scopes.forEach(googleAuthProvider.addScope);
    googleAuthProvider.setCustomParameters(customParameters);
    return googleAuthProvider;
  }
}

/// Authenticates using Microsoft with a Firebase provider.
class MicrosoftAuthMethodDefault extends MicrosoftAuthMethod with _ProviderAuthMethod {
  /// The OAuth scopes.
  final List<String> scopes;

  /// The custom parameters to pass to the provider.
  final Map<String, String> customParameters;

  /// Creates a new Microsoft auth method instance.
  const MicrosoftAuthMethodDefault({
    this.scopes = const [],
    this.customParameters = const {},
  });

  @override
  firebase_auth.MicrosoftAuthProvider _createAuthProvider() {
    firebase_auth.MicrosoftAuthProvider microsoftAuthProvider = firebase_auth.MicrosoftAuthProvider();
    scopes.forEach(microsoftAuthProvider.addScope);
    microsoftAuthProvider.setCustomParameters(customParameters);
    return microsoftAuthProvider;
  }
}

/// Authenticates using Twitter with a Firebase provider.
class TwitterAuthMethodDefault extends TwitterAuthMethod with _ProviderAuthMethod {
  /// The custom parameters to pass to the provider.
  final Map<String, String> customParameters;

  /// Creates a new Twitter auth method instance.
  const TwitterAuthMethodDefault({
    this.customParameters = const {},
  });

  @override
  firebase_auth.TwitterAuthProvider _createAuthProvider() {
    firebase_auth.TwitterAuthProvider twitterAuthProvider = firebase_auth.TwitterAuthProvider();
    twitterAuthProvider.setCustomParameters(customParameters);
    return twitterAuthProvider;
  }
}

/// Matches [firebase_auth.ActionCodeSettings].
class ActionCodeSettings extends firebase_auth.ActionCodeSettings {
  /// Creates a new action code settings instance.
  ActionCodeSettings({
    super.androidPackageName,
    super.androidMinimumVersion,
    super.androidInstallApp = false,
    super.linkDomain,
    super.handleCodeInApp = false,
    super.iOSBundleId,
    required super.url,
  });
}
