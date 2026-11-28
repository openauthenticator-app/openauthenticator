import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:open_authenticator/core/release_update.dart';

/// The direct-download asset expected by the test installation.
const String _assetName = 'openauthenticator-linux-x64.zip';

/// The GitHub repository serving releases.
final Uri _repository = Uri.parse('https://github.com/openauthenticator-app/openauthenticator');

/// Tests the GitHub release lookup used by the startup notice.
void main() {
  test('finds a newer stable version and links to its exact release', () async {
    final MockClient client = MockClient((request) async {
      expect(request.url, Uri.parse('https://api.github.com/repos/openauthenticator-app/openauthenticator/releases/latest'));
      return _release('v2.10.0');
    });
    addTearDown(client.close);

    final ReleaseUpdate? update = await _check(client);

    expect(update?.version, '2.10.0');
    expect(update?.downloadsPage, _repository.replace(path: '${_repository.path}/releases/tag/v2.10.0'));
  });

  test('ignores the same version with different build metadata and older versions', () async {
    for (final String tag in ['2.9.0+31', '2.8.9']) {
      final MockClient client = MockClient((_) async => _release(tag));
      addTearDown(client.close);
      expect(await _check(client), isNull, reason: tag);
    }
  });

  test('waits for the matching platform asset to be uploaded', () async {
    for (final http.Response response in [
      _release('2.10.0', assetName: 'openauthenticator-android.apk'),
      _release('2.10.0', assetState: 'starter'),
    ]) {
      final MockClient client = MockClient((_) async => response);
      addTearDown(client.close);
      expect(await _check(client), isNull);
    }
  });

  test('ignores prereleases and invalid responses', () async {
    for (final http.Response response in [
      _release('2.10.0', prerelease: true),
      _release('2.10.0-beta.1'),
      _release('wrong tag'),
      http.Response('{', 200),
      http.Response('', 404),
      http.Response('', 429),
    ]) {
      final MockClient client = MockClient((_) async => response);
      addTearDown(client.close);
      expect(await _check(client), isNull);
    }
  });

  test('keeps startup quiet when offline', () async {
    final MockClient client = MockClient((_) async => throw http.ClientException('Offline'));
    addTearDown(client.close);

    expect(await _check(client), isNull);
  });
}

/// Checks for an update to the test installation of the Linux ZIP.
Future<ReleaseUpdate?> _check(http.Client client) => findReleaseUpdate(
  client: client,
  repository: _repository,
  installedVersion: '2.9.0+30',
  assetName: _assetName,
);

/// Creates the response for a published release with one asset.
http.Response _release(String tag, {String assetName = _assetName, String assetState = 'uploaded', bool prerelease = false}) => http.Response(
  jsonEncode({
    'tag_name': tag,
    'draft': false,
    'prerelease': prerelease,
    'assets': [
      {'name': assetName, 'state': assetState},
    ],
  }),
  200,
);
