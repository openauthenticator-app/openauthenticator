import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:open_authenticator/model/migrator/firebase_auth/firebase_auth.dart';
import 'package:open_authenticator/model/migrator/firebase_options.dart';
import 'package:simple_secure_storage/simple_secure_storage.dart';

/// The error message thrown when an invalid response is returned.
String _invalidResponseErrorMessage(http.Response response) => 'Invalid response (${response.statusCode}) : ${response.body}.';

/// Uses Firebase REST API to interact with Firebase Auth.
class FirebaseAuthRest extends FirebaseAuth {
  /// The header that allows to localize Firebase messages.
  static const String kLocaleHeader = 'X-Firebase-Locale';

  /// The user data preferences key.
  static const String _kUserData = 'firebaseUserData';

  /// The first method to call.
  static const String _kCallInstall = 'auth.install';

  /// The method to call when the user has changed.
  static const String _kCallUserChanged = 'auth.userChanged';

  /// The current user instance.
  RestUser? _currentUser;

  /// The user's stream controller.
  final StreamController<RestUser?> _controller = StreamController<RestUser?>.broadcast();

  /// The method channel.
  /// This allow us to link our auth implementation to the Firebase C++ SDK.
  final MethodChannel _methodChannel = const MethodChannel('app.openauthenticator.auth');

  @override
  Future<void> initialize() async {
    await super.initialize();
    _methodChannel.setMethodCallHandler(_handlePlatformCall);
    String? userData = await SimpleSecureStorage.read(_kUserData);
    if (userData == null) {
      _onUserChanged(methodChannelCall: _kCallInstall);
      return;
    }
    RestUser currentUser = RestUser.fromJson(jsonDecode(userData));
    _currentUser = currentUser;
    currentUser.addListener(_onUserChanged);
    _onUserChanged(methodChannelCall: _kCallInstall);
    if (!await currentUser.reload()) {
      await signOut();
    }
  }

  @override
  RestUser? get currentUser => _currentUser;

  @override
  Future<SignInResult> signInWith(FirebaseAuthMethod method) async {
    SignInResult result = await super.signInWith(method);
    if (result.localId == null || result.idToken == null || result.email == null || result.refreshToken == null || result.expiresIn == null) {
      throw Exception('Invalid sign-in result.');
    }
    _currentUser?.dispose();
    _currentUser = await RestUser._fromSignInResult(result);
    _currentUser?.addListener(_onUserChanged);
    _onUserChanged();
    return result;
  }

  @override
  Future<SignInResult> unlinkFrom(String providerId) async {
    if (!isLoggedIn) {
      throw Exception('You must be logged-in to unlink a provider.');
    }
    http.Response response = await http.post(
      Uri.https(
        'identitytoolkit.googleapis.com',
        '/v1/accounts:update',
        {
          'key': DefaultFirebaseOptions.currentPlatform.apiKey,
        },
      ),
      headers: {
        HttpHeaders.contentTypeHeader: 'application/json',
        FirebaseAuthRest.kLocaleHeader: locale,
      },
      body: jsonEncode(
        {
          'idToken': _currentUser!._idToken,
          'deleteProvider': [providerId],
        },
      ),
    );
    if (response.statusCode != 200) {
      throw Exception(_invalidResponseErrorMessage(response));
    }
    Map<String, dynamic> data = jsonDecode(response.body);
    _currentUser!._refreshFromResponse(data);
    return SignInResult(
      email: data['email'],
      localId: data['localId']!,
    );
  }

  @override
  Future<void> signOut() async {
    await SimpleSecureStorage.delete(_kUserData);
    _currentUser?.dispose();
    _currentUser = null;
    _onUserChanged();
  }

  @override
  Future<void> deleteUser() async {
    if (_currentUser != null && await _currentUser!._sendDeleteRequest()) {
      await signOut();
    }
  }

  @override
  Stream<RestUser?> get userChanges => _controller.stream;

  /// Triggered when the current user has changed.
  void _onUserChanged({String methodChannelCall = _kCallUserChanged}) {
    _controller.add(_currentUser);
    if (_currentUser == null) {
      SimpleSecureStorage.delete(_kUserData);
    } else {
      SimpleSecureStorage.write(_kUserData, jsonEncode(_currentUser!.toJson()));
    }
    _methodChannel.invokeMethod(
      methodChannelCall,
      {
        'appName': Firebase.app().name,
        if (_currentUser?.uid != null) 'userUid': _currentUser?.uid,
        // if (_currentUser?._idToken != null) 'idToken': _currentUser?._idToken,
      },
    );
  }

  /// Handles platform calls.
  Future _handlePlatformCall(MethodCall call) async {
    switch (call.method) {
      case 'user.getIdToken':
        Object? arguments = call.arguments;
        bool forceRefresh = arguments is Map && arguments['forceRefresh']?.toString() == 'true';
        return await _currentUser?.getIdToken(forceRefresh: forceRefresh);
      default:
        throw UnimplementedError();
    }
  }
}

/// An user, with some additional parameters.
class RestUser extends User with ChangeNotifier {
  /// The "uid" key.
  static const String _kUid = 'uid';

  /// The "email" key.
  static const String _kEmail = 'email';

  /// The "providers" key.
  static const String _kProviders = 'providers';

  /// The "idToken" key.
  static const String _kIdToken = 'idToken';

  /// The "refreshToken" key.
  static const String _kRefreshToken = 'refreshToken';

  /// The "expirationDate" key.
  static const String _kExpirationDate = 'expirationDate';

  /// The expiration threshold, just to ensure we have a fresh access token.
  static const _kTokenExpirationThreshold = Duration(seconds: 30);

  /// Matches [User.uid].
  String _uid;

  /// Matches [User.email].
  String? _email;

  /// Matches [User.providers].
  List<String> _providers;

  /// The id token.
  String _idToken;

  /// The refresh token.
  String refreshToken;

  /// The expiration date.
  DateTime expirationDate;

  /// Creates a new REST user instance.
  RestUser._({
    required String uid,
    String? email,
    required List<String> providers,
    required String idToken,
    required this.refreshToken,
    required this.expirationDate,
  }) : _uid = uid,
       _email = email,
       _providers = providers,
       _idToken = idToken;

  /// Creates a new REST user instance from a sign-in result.
  static Future<RestUser?> _fromSignInResult(SignInResult signInResult) async {
    RestUser user = RestUser._(
      uid: signInResult.localId!,
      email: signInResult.email,
      providers: [],
      idToken: signInResult.idToken!,
      refreshToken: signInResult.refreshToken!,
      expirationDate: DateTime.now().add(Duration(seconds: signInResult.expiresIn!)),
    );
    if (!await user.reload()) {
      return null;
    }
    return user;
  }

  /// Creates a new REST user instance from a JSON map.
  RestUser.fromJson(Map<String, dynamic> json)
    : this._(
        uid: json[RestUser._kUid],
        email: json[RestUser._kEmail],
        providers: (json[RestUser._kProviders] as List).cast<String>(),
        idToken: json[RestUser._kIdToken],
        refreshToken: json[RestUser._kRefreshToken],
        expirationDate: DateTime.fromMillisecondsSinceEpoch(json[RestUser._kExpirationDate]),
      );

  @override
  String get uid => _uid;

  @override
  String? get email => _email;

  @override
  List<String> get providers => _providers;

  /// Converts this user to a JSON map.
  Map<String, dynamic> toJson() => {
    _kUid: _uid,
    _kEmail: _email,
    _kProviders: _providers,
    _kIdToken: _idToken,
    _kRefreshToken: refreshToken,
    _kExpirationDate: expirationDate.millisecondsSinceEpoch,
  };

  @override
  Future<String> getIdToken({bool forceRefresh = false}) async {
    if (forceRefresh || expirationDate.subtract(_kTokenExpirationThreshold).isBefore(DateTime.now())) {
      await refreshAccessToken();
    }
    return _idToken;
  }

  /// Refreshes the access token.
  Future<bool> refreshAccessToken() async {
    http.Response response = await http.post(
      Uri.https(
        'securetoken.googleapis.com',
        '/v1/token',
        {
          'key': DefaultFirebaseOptions.currentPlatform.apiKey,
        },
      ),
      body: {
        'grant_type': 'refresh_token',
        'refresh_token': refreshToken,
      },
    );
    if (response.statusCode != 200) {
      return false;
    }
    Map<String, dynamic> data = jsonDecode(response.body);
    _idToken = data['id_token'];
    refreshToken = data['refresh_token'];
    int expirationSeconds = int.parse(data['expires_in']);
    expirationDate = DateTime.now().add(Duration(seconds: expirationSeconds));
    notifyListeners();
    return true;
  }

  @override
  Future<bool> reload() async {
    String idToken = await getIdToken();
    http.Response response = await http.post(
      Uri.https(
        'identitytoolkit.googleapis.com',
        '/v1/accounts:lookup',
        {
          'key': DefaultFirebaseOptions.currentPlatform.apiKey,
        },
      ),
      headers: {
        HttpHeaders.contentTypeHeader: 'application/json',
      },
      body: jsonEncode({
        'idToken': idToken,
      }),
    );
    if (response.statusCode != 200) {
      return false;
    }
    Map<String, dynamic> data = jsonDecode(response.body);
    List? users = data['users'];
    if (users != null && users.isNotEmpty) {
      _refreshFromResponse(users.first);
    }
    return true;
  }

  /// Sends a delete request for the user.
  Future<bool> _sendDeleteRequest() async {
    String idToken = await getIdToken();
    http.Response response = await http.post(
      Uri.https(
        'identitytoolkit.googleapis.com',
        '/v1/accounts:delete',
        {
          'key': DefaultFirebaseOptions.currentPlatform.apiKey,
        },
      ),
      headers: {
        HttpHeaders.contentTypeHeader: 'application/json',
      },
      body: jsonEncode({
        'idToken': idToken,
      }),
    );
    return response.statusCode == 200;
  }

  @override
  Future<SignInResult> reAuthenticateWith(FirebaseAuthMethod method) async {
    SignInResult signInResult = await super.reAuthenticateWith(method);
    if (_uid != signInResult.localId) {
      return signInResult;
    }
    if (signInResult.idToken != null && signInResult.refreshToken != null) {
      _idToken = signInResult.idToken!;
      refreshToken = signInResult.refreshToken!;
    }
    return signInResult;
  }

  @override
  Future<SignInResult> linkTo(CanLinkTo method) async {
    SignInResult signInResult = await super.linkTo(method);
    await reload();
    return signInResult;
  }

  /// Refreshes the user data from the [data].
  void _refreshFromResponse(Map<String, dynamic> data) {
    _email = data['email'];
    List providerUserInfo = data['providerUserInfo'];
    if (providerUserInfo.isNotEmpty) {
      List<String> providers = [];
      for (Map<String, dynamic> provider in providerUserInfo) {
        providers.add(provider['providerId']);
      }
      _providers = providers;
    }
    notifyListeners();
  }
}

/// Authenticates using a [firebase_auth.AuthProvider].
mixin _RestIdpAuthMethod on FirebaseAuthMethod, CanLinkTo {
  @override
  Future<SignInResult> signIn() => _doAction();

  @override
  Future<SignInResult> reAuthenticate(User user) async => await signIn();

  @override
  Future<SignInResult> linkTo(User user) async {
    String? idToken = await user.getIdToken();
    if (idToken == null) {
      throw Exception('Failed to get current user id token.');
    }
    return await _doAction(
      additionalParameters: {
        'idToken': idToken,
      },
    );
  }

  /// Sign-in with the specified [additionalParameters].
  Future<SignInResult> _doAction({Map<String, String> additionalParameters = const {}}) async {
    http.Response response = await http.post(
      Uri.https(
        'identitytoolkit.googleapis.com',
        '/v1/accounts:signInWithIdp',
        {
          'key': DefaultFirebaseOptions.currentPlatform.apiKey,
        },
      ),
      headers: {
        HttpHeaders.contentTypeHeader: 'application/json',
      },
      body: jsonEncode({
        ...additionalParameters,
        'postBody': _postBody,
        'requestUri': 'http://localhost',
        'returnSecureToken': true,
        'returnIdpCredential': true,
      }),
    );
    if (response.statusCode != 200) {
      throw Exception(_invalidResponseErrorMessage(response));
    }
    Map<String, dynamic> data = jsonDecode(response.body);
    return SignInResult(
      email: data['email'],
      localId: data['localId'],
      providerId: data['providerId'],
      idToken: data['idToken'],
      refreshToken: data['refreshToken'],
      expiresIn: int.tryParse(data['expiresIn'] ?? ''),
    );
  }

  /// The id token, if any.
  String? get idToken => null;

  /// The access token, if any.
  String? get accessToken => null;

  /// The auth nonce parameter.
  String? get nonce => null;

  /// The provider id.
  String? get providerId;

  /// Returns the "postBody" parameter.
  String get _postBody {
    String postBody = 'providerId=$providerId';
    if (idToken != null) {
      postBody += '&id_token=$idToken';
    }
    if (accessToken != null) {
      postBody += '&access_token=$accessToken';
    }
    if (nonce != null) {
      postBody += '&nonce=$nonce';
    }
    return postBody;
  }
}

/// Authenticates using Apple with an HTTP client.
class AppleAuthMethodRest extends AppleAuthMethod with _RestIdpAuthMethod {
  @override
  final String? idToken;

  @override
  final String? nonce;

  @override
  String? get providerId => AppleAuthMethod.providerId;

  /// Creates a new Apple auth method REST instance.
  const AppleAuthMethodRest({
    this.idToken,
    this.nonce,
  });
}

/// Authenticates using an email link with an HTTP client.
class EmailLinkAuthMethodRest extends EmailLinkAuthMethod {
  /// The email that has requested the authentication.
  final String email;

  /// The OOB code to validate.
  final String oobCode;

  /// Creates a new email link auth method instance.
  const EmailLinkAuthMethodRest({
    required this.email,
    required this.oobCode,
  });

  @override
  Future<SignInResult> signIn() async {
    http.Response response = await http.post(
      Uri.https(
        'identitytoolkit.googleapis.com',
        '/v1/accounts:signInWithEmailLink',
        {
          'key': DefaultFirebaseOptions.currentPlatform.apiKey,
        },
      ),
      headers: {
        HttpHeaders.contentTypeHeader: 'application/json',
      },
      body: jsonEncode({
        'oobCode': oobCode,
        'email': email,
      }),
    );
    if (response.statusCode != 200) {
      throw Exception(_invalidResponseErrorMessage(response));
    }
    Map<String, dynamic> data = jsonDecode(response.body);
    return SignInResult(
      email: data['email'],
      localId: data['localId'],
      idToken: data['idToken'],
      refreshToken: data['refreshToken'],
      expiresIn: int.tryParse(data['expiresIn'] ?? ''),
    );
  }

  @override
  Future<SignInResult> reAuthenticate(User user) async => await signIn();
}

/// Authenticates using Github with an HTTP client.
class GithubAuthMethodRest extends GithubAuthMethod with _RestIdpAuthMethod {
  @override
  final String? accessToken;

  /// Creates a new Github auth method REST instance.
  const GithubAuthMethodRest({
    this.accessToken,
  });

  @override
  String? get providerId => GithubAuthMethod.providerId;
}

/// Authenticates using Google with an HTTP client.
class GoogleAuthMethodRest extends GoogleAuthMethod with _RestIdpAuthMethod {
  @override
  final String? accessToken;

  @override
  final String? idToken;

  @override
  String? get providerId => GoogleAuthMethod.providerId;

  /// Creates a new Google auth method REST instance.
  const GoogleAuthMethodRest({
    this.accessToken,
    this.idToken,
  });
}

/// Authenticates using Microsoft with an HTTP client.
class MicrosoftAuthMethodRest extends MicrosoftAuthMethod with _RestIdpAuthMethod {
  @override
  final String? accessToken;

  @override
  final String? idToken;

  @override
  final String? nonce;

  /// Creates a new Microsoft auth method REST instance.
  const MicrosoftAuthMethodRest({
    this.accessToken,
    this.idToken,
    this.nonce,
  });

  @override
  String? get providerId => MicrosoftAuthMethod.providerId;
}

/// Authenticates using Twitter with an HTTP client.
class TwitterAuthMethodRest extends TwitterAuthMethod with _RestIdpAuthMethod {
  @override
  final String? accessToken;

  /// Creates a new Microsoft auth method REST instance.
  const TwitterAuthMethodRest({
    this.accessToken,
  });

  @override
  String? get providerId => TwitterAuthMethod.providerId;
}
