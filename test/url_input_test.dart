import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:open_authenticator/core/settings/backend_url.dart';
import 'package:open_authenticator/widgets/dialog/logo_search/sources.dart';

/// Checks backend addresses and free-text logo searches.
void main() {
  test('only complete HTTP backend addresses can be probed and saved', () {
    expect(BackendUrl.tryParse(' http://localhost:3000/ '), 'http://localhost:3000');
    expect(BackendUrl.tryParse('https://example.org/api/'), 'https://example.org/api');
    for (final input in [
      '',
      '/ping',
      'example.org',
      'https://',
      'ftp://example.org',
      'https://a b',
      'https://example.org:65536',
      'https://example.org:-2',
      'https://example.org:${'9' * 45}',
      'https://example.org:abc',
    ]) {
      expect(BackendUrl.tryParse(input), isNull, reason: input);
    }
  });

  test('free-text logo searches skip invalid host names and preserve working lookups', () async {
    final requests = <Uri>[];
    final client = MockClient((request) async {
      requests.add(request.url);
      return http.Response('<link rel="icon" href="/logo.png">', 200);
    });
    for (final input in ['a:bad port', 'site.test]', 'A [Brand]', 'https://']) {
      expect(await const DirectSource().search(client, input), isEmpty);
    }
    expect(requests, isEmpty);
    for (final input in ['Demo Brand', 'demobrand.com', 'https://demobrand.com/page']) {
      expect(await const DirectSource().search(client, input), [Uri.https('demobrand.com', '/logo.png')]);
    }
  });
}
