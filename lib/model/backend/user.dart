import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_authenticator/model/backend/authentication/providers/provider.dart';
import 'package:open_authenticator/model/backend/authentication/session.dart';
import 'package:open_authenticator/model/backend/backend.dart';
import 'package:open_authenticator/model/backend/request/request.dart';
import 'package:open_authenticator/model/backend/request/response.dart';
import 'package:open_authenticator/utils/result/result.dart';
import 'package:open_authenticator/utils/sentry.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

/// Represents a user, got from the backend.
class User with EquatableMixin {
  /// The user ID.
  final String id;

  /// Whether the user has an active Contributor Plan.
  final bool contributorPlan;

  /// The TOTPs limit.
  final int totpsLimit;

  /// The user email.
  final String? email;

  /// The user Google ID.
  final String? googleId;

  /// The user GitHub ID.
  final String? githubId;

  /// The user Microsoft ID.
  final String? microsoftId;

  /// The user Apple ID.
  final String? appleId;

  /// Creates a new user instance.
  const User._({
    required this.id,
    required this.contributorPlan,
    required this.totpsLimit,
    this.email,
    this.googleId,
    this.githubId,
    this.microsoftId,
    this.appleId,
  });

  /// Creates a new user instance from a JSON map.
  User.fromJson(Map<String, dynamic> json)
    : this._(
        id: json['id'],
        contributorPlan: json['contributorPlan'] == true,
        totpsLimit: json['totpsLimit'],
        email: json['providers']?['email'],
        googleId: json['providers']?['googleId'],
        githubId: json['providers']?['githubId'],
        microsoftId: json['providers']?['microsoftId'],
        appleId: json['providers']?['appleId'],
      );

  /// Whether the user has an authentication provider.
  bool hasAuthenticationProvider(String providerId) => switch (providerId) {
    EmailAuthenticationProvider.kProviderId => email != null,
    GoogleAuthenticationProvider.kProviderId => googleId != null,
    GithubAuthenticationProvider.kProviderId => githubId != null,
    MicrosoftAuthenticationProvider.kProviderId => microsoftId != null,
    AppleAuthenticationProvider.kProviderId => appleId != null,
    _ => false,
  };

  /// Gets the user authentication provider ID.
  static Future<File> _getFile({
    bool create = false,
    bool addDebugModeSuffix = true,
  }) async {
    Directory directory = await getApplicationSupportDirectory();
    File file = File('${directory.path}/user${addDebugModeSuffix && kDebugMode ? '_debug' : ''}.json');
    if (create && !file.existsSync()) {
      file.createSync();
    }
    return file;
  }

  /// Reads the user from the cache.
  static Future<User?> _readFromCache() async {
    File file = await _getFile();
    if (!file.existsSync()) {
      return null;
    }
    String content = await file.readAsString();
    Map<String, dynamic> json = jsonDecode(content);
    return json['id'] == null ? null : User.fromJson(json);
  }

  /// Saves the user to the cache.
  Future<void> _saveToCache() async {
    File file = await _getFile(create: true);
    await file.writeAsString(jsonEncode(toJson()));
  }

  /// Clears the user cache.
  static Future<void> _clearCache() async {
    File file = await _getFile();
    if (file.existsSync()) {
      await file.delete();
    }
  }

  /// Updates the user email.
  User updateEmail(String? email) => User._(
    id: id,
    contributorPlan: contributorPlan,
    totpsLimit: totpsLimit,
    email: email,
    googleId: googleId,
    githubId: githubId,
    microsoftId: microsoftId,
    appleId: appleId,
  );

  /// Updates the user Google ID.
  User updateGoogleId(String? googleId) => User._(
    id: id,
    contributorPlan: contributorPlan,
    totpsLimit: totpsLimit,
    email: email,
    googleId: googleId,
    githubId: githubId,
    microsoftId: microsoftId,
    appleId: appleId,
  );

  /// Updates the user GitHub ID.
  User updateGithubId(String? githubId) => User._(
    id: id,
    contributorPlan: contributorPlan,
    totpsLimit: totpsLimit,
    email: email,
    googleId: googleId,
    githubId: githubId,
    microsoftId: microsoftId,
    appleId: appleId,
  );

  /// Updates the user Microsoft ID.
  User updateMicrosoftId(String? microsoftId) => User._(
    id: id,
    contributorPlan: contributorPlan,
    totpsLimit: totpsLimit,
    email: email,
    googleId: googleId,
    githubId: githubId,
    microsoftId: microsoftId,
    appleId: appleId,
  );

  /// Updates the user Apple ID.
  User updateAppleId(String? appleId) => User._(
    id: id,
    contributorPlan: contributorPlan,
    totpsLimit: totpsLimit,
    email: email,
    googleId: googleId,
    githubId: githubId,
    microsoftId: microsoftId,
    appleId: appleId,
  );

  @override
  List<Object?> get props => [
    id,
    contributorPlan,
    totpsLimit,
    email,
    googleId,
    githubId,
    microsoftId,
    appleId,
  ];

  /// Converts the user to a JSON map.
  Map<String, dynamic> toJson() => {
    'id': id,
    'contributorPlan': contributorPlan,
    'totpsLimit': totpsLimit,
    'providers': {
      'email': ?email,
      'googleId': ?googleId,
      'githubId': ?githubId,
      'microsoftId': ?microsoftId,
      'appleId': ?appleId,
    },
  };
}

/// The user provider.
final userProvider = AsyncNotifierProvider<UserNotifier, User?>(UserNotifier.new);

/// The user notifier.
class UserNotifier extends AsyncNotifier<User?> {
  @override
  Future<User?> build() async {
    Session? session = await ref.watch(storedSessionProvider.future);
    if (session == null) {
      return null;
    }
    User? user = await User._readFromCache();
    refreshUserInfo();
    return user;
  }

  /// Refreshes the user info.
  Future<Result<User>> refreshUserInfo() async {
    Result<GetUserInfoResponse> result = await ref
        .read(backendClientProvider.notifier)
        .sendHttpRequest(
          const GetUserInfoRequest(),
        );
    if (result is! ResultSuccess<GetUserInfoResponse>) {
      return result.to((_) => null);
    }
    if (kSentryEnabled) {
      Sentry.configureScope(
        (scope) => scope.setUser(
          SentryUser(
            id: result.value.user.id,
          ),
        ),
      );
    }
    await changeUser(result.value.user);
    return ResultSuccess(value: result.value.user);
  }

  /// Changes the user.
  Future<void> changeUser(User user) async {
    await user._saveToCache();
    if (ref.mounted) {
      state = AsyncData(user);
    }
  }

  /// Logs out the user.
  Future<Result> logoutUser() async {
    try {
      Session? session = await ref.read(storedSessionProvider.future);
      if (session == null) {
        return const ResultSuccess();
      }
      Result<UserLogoutResponse> result = await ref
          .read(backendClientProvider.notifier)
          .sendHttpRequest(
            UserLogoutRequest(
              refreshToken: session.refreshToken,
            ),
          );
      return result;
    } catch (ex, stackTrace) {
      return ResultError(
        exception: ex,
        stackTrace: stackTrace,
      );
    } finally {
      await _clearUser();
    }
  }

  /// Deletes the user.
  Future<Result> deleteUser() async {
    try {
      Result<DeleteUserResponse> result = await ref
          .read(backendClientProvider.notifier)
          .sendHttpRequest(
            const DeleteUserRequest(),
          );
      await _clearUser();
      return result;
    } catch (ex, stackTrace) {
      return ResultError<DeleteUserResponse>(
        exception: ex,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> _clearUser() async {
    if (kSentryEnabled) {
      Sentry.configureScope((scope) => scope.setUser(null));
    }
    await User._clearCache();
    await ref.read(storedSessionProvider.notifier).clear();
    // if (ref.mounted) {
    //   state = const AsyncData(null);
    // }
  }
}
