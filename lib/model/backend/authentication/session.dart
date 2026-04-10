import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_authenticator/i18n/localizable_exception.dart';
import 'package:open_authenticator/i18n/translations.g.dart';
import 'package:open_authenticator/model/backend/backend.dart';
import 'package:open_authenticator/model/backend/request/error.dart';
import 'package:open_authenticator/model/backend/request/request.dart';
import 'package:open_authenticator/model/backend/request/response.dart';
import 'package:open_authenticator/utils/result.dart';
import 'package:simple_secure_storage/simple_secure_storage.dart';

/// Represents a session.
class Session with EquatableMixin {
  /// The access token.
  final String accessToken;

  /// The refresh token.
  final String refreshToken;

  /// Creates a new session instance.
  const Session({
    required this.accessToken,
    required this.refreshToken,
  });

  /// Creates a copy of the session.
  Session copyWith({
    String? accessToken,
    String? refreshToken,
    bool? isValid,
  }) => Session(
    accessToken: accessToken ?? this.accessToken,
    refreshToken: refreshToken ?? this.refreshToken,
  );

  @override
  List<Object?> get props => [
    accessToken,
    refreshToken,
  ];
}

/// The stored session provider.
final storedSessionProvider = AsyncNotifierProvider<StoredSessionNotifier, Session?>(StoredSessionNotifier.new);

/// The stored session notifier.
class StoredSessionNotifier extends AsyncNotifier<Session?> {
  /// The preferences key where the access token is stored.
  static const String _kAccessToken = 'accessToken';

  /// The preferences key where the refresh token is stored.
  static const String _kRefreshToken = 'refreshToken';

  @override
  Future<Session?> build() async {
    String? accessToken = await SimpleSecureStorage.read(_kAccessToken);
    String? refreshToken = await SimpleSecureStorage.read(_kRefreshToken);
    return accessToken == null || refreshToken == null
        ? null
        : Session(
            accessToken: accessToken,
            refreshToken: refreshToken,
          );
  }

  /// Stores the session and uses it.
  Future<void> storeAndUse(Session session) async {
    await SimpleSecureStorage.write(_kAccessToken, session.accessToken);
    await SimpleSecureStorage.write(_kRefreshToken, session.refreshToken);
    if (ref.mounted) {
      state = AsyncData(
        Session(
          accessToken: session.accessToken,
          refreshToken: session.refreshToken,
        ),
      );
    }
  }

  /// Clears the session.
  Future<Result> clear() async {
    await SimpleSecureStorage.delete(_kAccessToken);
    await SimpleSecureStorage.delete(_kRefreshToken);
    if (!ref.mounted) {
      return const ResultCancelled();
    }
    state = const AsyncData(null);
    return const ResultSuccess();
  }
}

/// The session refresh manager provider.
final sessionRefreshManagerProvider = NotifierProvider<SessionRefreshManager, SessionRefreshState>(SessionRefreshManager.new);

/// The session refresh manager notifier.
class SessionRefreshManager extends Notifier<SessionRefreshState> {
  @override
  SessionRefreshState build() {
    ref.listen(storedSessionProvider, (_, _) {
      if (ref.mounted) {
        state = .idle;
      }
    });
    return .idle;
  }

  /// Refreshes the session.
  Future<Result> refresh({Session? session}) async {
    if (!ref.mounted || state == .inProgress || state == .invalidSession) {
      return const ResultCancelled();
    }
    state = .inProgress;
    try {
      BackendClient backend = await ref.read(backendClientProvider.notifier);
      Result<Session> result = await _sendRefreshRequest(backend, session: session);
      if (result is! ResultSuccess<Session>) {
        if (result is ResultError) {
          Error.throwWithStackTrace((result as ResultError).exception, (result as ResultError).stackTrace);
        }
        return result;
      }
      await ref.read(storedSessionProvider.notifier).storeAndUse(result.value);
      if (!ref.mounted) {
        return const ResultCancelled();
      }
      state = .success;
      return const ResultSuccess();
    } catch (ex, stackTrace) {
      List<String> invalidSessionCodes = [
        InvalidPayloadError.kErrorCode,
        InvalidTokenError.kErrorCode,
        InvalidSessionError.kErrorCode,
        ExpiredSessionError.kErrorCode,
      ];
      if (ex is BackendRequestError && invalidSessionCodes.contains(ex.code) && ref.mounted) {
        state = .invalidSession;
      }
      return ResultError(
        exception: ex,
        stackTrace: stackTrace,
      );
    }
  }

  /// Sends a refresh request.
  Future<Result<Session>> _sendRefreshRequest(BackendClient backend, {Session? session}) async {
    try {
      session ??= await ref.read(storedSessionProvider.future);
      if (session == null) {
        throw NoSessionException();
      }
      Result<RefreshSessionResponse> result = await backend.sendHttpRequest(
        RefreshSessionRequest(
          refreshToken: session.refreshToken,
        ),
        session: session,
      );
      return result.to((response) => response!.session);
    } catch (ex, stackTrace) {
      return ResultError(
        exception: ex,
        stackTrace: stackTrace,
      );
    }
  }
}

/// The no session exception.
class NoSessionException extends LocalizableException {
  /// Creates a new no session exception instance.
  NoSessionException()
    : super(
        localizedErrorMessage: translations.error.backend.noSession,
      );
}

/// The session refresh state.
enum SessionRefreshState {
  /// The session refresh state is idle.
  idle,

  /// The session refresh state is in progress.
  inProgress,

  /// The session refresh state is success.
  success,

  /// The session refresh state is invalid.
  invalidSession,
}
