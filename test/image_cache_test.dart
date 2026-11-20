import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_authenticator/core/crypto/salt.dart';
import 'package:open_authenticator/core/crypto/store.dart';
import 'package:open_authenticator/core/totp/decrypted.dart';
import 'package:open_authenticator/core/totp/image_cache.dart';
import 'package:open_authenticator/core/totp/repository.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

/// Supplies a temporary application cache directory.
class _CacheDirectory extends PathProviderPlatform {
  /// The temporary directory used by the image cache.
  final Directory root;

  /// Creates a path provider rooted in [root].
  _CacheDirectory(this.root);

  /// Returns the test cache directory.
  @override
  Future<String> getApplicationCachePath() async => root.path;
}

/// Checks cache repair and concurrent cache clearing.
void main() {
  test('repairs a truncated index and keeps an in-flight image from undoing a cache clear', () async {
    final Directory root = await Directory.systemTemp.createTemp('totp-image-cache-');
    addTearDown(() => root.delete(recursive: true));
    final PathProviderPlatform previous = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _CacheDirectory(root);
    addTearDown(() => PathProviderPlatform.instance = previous);
    final Directory directory = await Directory('${root.path}/totps_images').create();
    final File index = await File('${directory.path}/index.json').writeAsString('{');
    final File orphan = await File('${directory.path}/unused').writeAsString('old');
    final HttpServer server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    final container = ProviderContainer.test(overrides: [totpRepositoryProvider.overrideWithBuild((ref, notifier) => [])]);
    final TotpImageCacheManager cache = container.read(totpImageCacheManagerProvider.notifier);
    expect(await container.read(totpImageCacheManagerProvider.future), isEmpty);
    expect(await index.readAsString(), '{}');
    expect(await orphan.exists(), isFalse);

    final CryptoStore key = await CryptoStore.fromPasswordInIsolate('fixture', Salt.generate());
    final DecryptedTotp item = DecryptedTotp.create(cryptoStore: key, secret: 'JBSWY3DPEHPK3PXP', label: 'fixture', imageUrl: 'http://127.0.0.1:${server.port}/logo.png')!;
    final Future<HttpRequest> arriving = server.first;
    final Future<void> pending = cache.cacheImage(item, checkSettings: false);
    final HttpRequest request = await arriving;
    await cache.clearCache();
    request.response.add([1, 2]);
    await request.response.close();
    await pending;
    expect(await directory.exists(), isFalse);
    expect(await container.read(totpImageCacheManagerProvider.future), isEmpty);
  });

  test('clearing the cache does not fail when some files cannot be deleted', () async {
    final Directory root = await Directory.systemTemp.createTemp('totp-image-cache-locked-');
    final Directory directory = await Directory('${root.path}/totps_images').create();
    addTearDown(() async {
      await Process.run('chmod', ['-R', 'u+rwx', root.path]);
      await root.delete(recursive: true);
    });
    final PathProviderPlatform previous = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _CacheDirectory(root);
    addTearDown(() => PathProviderPlatform.instance = previous);
    final container = ProviderContainer.test(overrides: [totpRepositoryProvider.overrideWithBuild((ref, notifier) => [])]);
    final TotpImageCacheManager cache = container.read(totpImageCacheManagerProvider.notifier);
    expect(await container.read(totpImageCacheManagerProvider.future), isEmpty);

    // Simulates files that cannot be deleted (eg. locked by Windows) with a read-only directory.
    final File locked = await File('${directory.path}/locked').writeAsString('image');
    await Process.run('chmod', ['a-w', directory.path]);
    await cache.clearCache();
    expect(await locked.exists(), isTrue);
    expect(await container.read(totpImageCacheManagerProvider.future), isEmpty);
  }, skip: !Platform.isLinux);
}
