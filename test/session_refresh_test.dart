import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_authenticator/model/backend/authentication/session.dart';
import 'package:open_authenticator/model/backend/backend.dart';
import 'package:open_authenticator/model/backend/request/request.dart';
import 'package:open_authenticator/model/backend/request/response.dart';
import 'package:open_authenticator/utils/result/result.dart';

const _original = Session(accessToken: 'access', refreshToken: 'refresh');
const _renewed = Session(accessToken: 'new-access', refreshToken: 'new-refresh');

class _StoredSession extends StoredSessionNotifier {
  @override
  Future<Session?> build() async => _original;
  @override
  Future<void> storeAndUse(Session session) async => state = AsyncData(session);
}

class _Client extends BackendClient {
  final firstResponse = Completer<void>();
  int requests = 0;

  @override
  Map<String, String> build() => {};

  @override
  Future<Result<T>> sendHttpRequest<T extends BackendResponse>(
    BackendRequest<T> request, {
    String? backendUrl,
    Session? session,
    bool autoRefreshAccessToken = true,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    expect(autoRefreshAccessToken, isFalse);
    if (++requests == 1) {
      await firstResponse.future;
      return ResultError(exception: TimeoutException('first refresh'));
    }
    return ResultSuccess(value: const RefreshSessionResponse(session: _renewed) as T);
  }
}

void main() {
  test('a transient refresh failure releases all waiters and allows the next refresh', () async {
    final client = _Client();
    final container = ProviderContainer.test(
      overrides: [
        backendClientProvider.overrideWith(() => client),
        storedSessionProvider.overrideWith(_StoredSession.new),
      ],
    );
    await container.read(storedSessionProvider.future);
    final SessionRefreshManager manager = container.read(sessionRefreshManagerProvider.notifier);
    final Future<Result<Session>> first = manager.refresh();
    final Future<Result<Session>> concurrent = manager.refresh();
    client.firstResponse.complete();
    expect(await first, isA<ResultError<Session>>());
    expect(await concurrent, same(await first));
    expect(container.read(sessionRefreshManagerProvider), isA<SessionRefreshStateIdle>());
    expect((await manager.refresh() as ResultSuccess<Session>).value, _renewed);
    expect(await container.read(storedSessionProvider.future), _renewed);
    expect(client.requests, 2);
  });
}
