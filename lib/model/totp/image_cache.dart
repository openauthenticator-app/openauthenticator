import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/painting.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:open_authenticator/model/settings/cache_totp_pictures.dart';
import 'package:open_authenticator/model/totp/decrypted.dart';
import 'package:open_authenticator/model/totp/repository.dart';
import 'package:open_authenticator/model/totp/totp.dart';
import 'package:open_authenticator/pages/totp.dart';
import 'package:open_authenticator/utils/image_type.dart';
import 'package:open_authenticator/utils/jovial_svg.dart';
import 'package:open_authenticator/utils/json.dart';
import 'package:open_authenticator/utils/result/reporter.dart';
import 'package:open_authenticator/widgets/totp/image.dart';
import 'package:open_authenticator/widgets/totp/widget.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:riverpod/src/providers/future_provider.dart';

/// The TOTP image cache manager provider.
final totpImageCacheManagerProvider = AsyncNotifierProvider<TotpImageCacheManager, Map<String, CacheObject>>(TotpImageCacheManager.new);

/// Resolves the best image source for a TOTP.
final FutureProviderFamily<ResolvedTotpImage?, ({String? imageUrl, String uuid})> totpResolvedImageProvider = FutureProvider.family.autoDispose<ResolvedTotpImage?, ({String uuid, String? imageUrl})>((ref, args) async {
  ref.watch(totpImageCacheManagerProvider);
  return ref
      .read(totpImageCacheManagerProvider.notifier)
      .resolveImage(
        args.uuid,
        args.imageUrl,
      );
});

/// A resolved TOTP image source.
typedef ResolvedTotpImage = ({
  ImageType imageType,
  String source,
});

/// Manages the cache of TOTPs images.
class TotpImageCacheManager extends AsyncNotifier<Map<String, CacheObject>> {
  /// The maximum number of concurrent cache fills.
  static const int _kFillCacheConcurrency = 4;

  /// The maximum age of an unused cached image before it is cleaned up.
  static const Duration _kUnusedCacheTtl = Duration(days: 180);

  /// Serializes cache state mutations and index writes.
  Future<void> _cacheMutationQueue = Future.value();

  @override
  FutureOr<Map<String, CacheObject>> build() async {
    final File index = await _getIndexFile();
    Map<String, CacheObject> cached = {};
    if (await index.exists()) {
      final JsonMap json = decodeJsonMap(await index.readAsString());
      cached = {
        for (final MapEntry<String, dynamic> entry in json.entries) //
          entry.key: CacheObject.fromJson(entry.value),
      };
    }
    return await _repairCache(cached);
  }

  /// Caches the TOTP image.
  Future<void> cacheImage(Totp totp, {bool checkSettings = true}) async {
    try {
      if (!totp.isDecrypted) {
        return;
      }
      if (checkSettings) {
        final bool cacheEnabled = await ref.read(cacheTotpPicturesSettingsEntryProvider.future);
        if (!cacheEnabled) {
          return;
        }
      }
      final String? imageUrl = (totp as DecryptedTotp).imageUrl;
      if (imageUrl == null) {
        await deleteCachedImage(totp.uuid);
      } else {
        final File file = await _getTotpCachedImageFile(totp.uuid, createDirectory: true);
        final CacheObject? previousCacheObject = (_currentCachedState() ?? await future)[totp.uuid];
        if (previousCacheObject?.url == imageUrl && await file.exists()) {
          return;
        }
        final http.Response response = await http.get(Uri.parse(imageUrl));
        if (response.statusCode < 200 || response.statusCode >= 300) {
          throw HttpException(
            'Failed to cache image: HTTP ${response.statusCode}.',
            uri: Uri.parse(imageUrl),
          );
        }
        await file.writeAsBytes(response.bodyBytes);
        await _evictCachedImageFile(file);
        ImageType imageType;
        if (imageUrl.endsWith('.svg')) {
          imageType = .svg;
          if (await JovialSvgUtils.svgToSi(response.body, file)) {
            imageType = .si;
          }
        } else {
          imageType = .other;
        }

        await _enqueueCacheMutation(() async {
          final Map<String, CacheObject> cached = await _readCachedState();
          cached[totp.uuid] = CacheObject(
            url: imageUrl,
            imageType: imageType,
            lastAccessedAt: DateTime.now(),
          );
          if (ref.mounted) {
            state = AsyncData(cached);
          }
          await _saveIndex(content: cached);
        });
      }
    } catch (ex, stackTrace) {
      printException(
        ex,
        stackTrace,
        sendToSentry: ex is! HttpException,
      );
    }
  }

  /// Deletes the cached images, if possible.
  Future<void> deleteCachedImages(Iterable<String> uuids) async {
    await _enqueueCacheMutation(() async {
      final Map<String, CacheObject> cached = await _readCachedState();
      for (final String uuid in uuids) {
        final File file = await _getTotpCachedImageFile(uuid);
        await _evictCachedImageFile(file);
        await file.deleteIfExists();
        cached.remove(uuid);
      }
      if (ref.mounted) {
        state = AsyncData(cached);
      }
      await _saveIndex(content: cached);
    });
  }

  /// Deletes the cached image, if possible.
  Future<void> deleteCachedImage(String uuid) => deleteCachedImages([uuid]);

  /// Resolves the best image source for a TOTP and updates the access timestamp.
  Future<ResolvedTotpImage?> resolveImage(String uuid, String? imageUrl) async {
    if (imageUrl == null) {
      return null;
    }

    final Map<String, CacheObject> cached = await future;
    final CacheObject? cacheObject = cached[uuid];
    if (cacheObject?.url != imageUrl) {
      return null;
    }

    final File file = await _getTotpCachedImageFile(uuid);
    final String source = await file.exists() ? file.path : imageUrl;

    final DateTime now = DateTime.now();
    if (cacheObject!.lastAccessedAt == null || now.difference(cacheObject.lastAccessedAt!).inMinutes >= 1) {
      await _enqueueCacheMutation(() async {
        final Map<String, CacheObject> updated = await _readCachedState();
        final CacheObject? current = updated[uuid];
        if (current?.url != imageUrl) {
          return;
        }
        updated[uuid] = current!.copyWith(
          lastAccessedAt: now,
        );
        if (ref.mounted) {
          state = AsyncData(updated);
        }
        await _saveIndex(content: updated);
      });
    }

    return (
      imageType: cacheObject.imageType,
      source: source,
    );
  }

  /// Fills the cache with all TOTPs that can be read from the TOTP repository.
  Future<void> fillCache({
    Iterable<Totp>? totps,
    bool checkSettings = true,
  }) async {
    if (checkSettings) {
      final bool cacheEnabled = await ref.read(cacheTotpPicturesSettingsEntryProvider.future);
      if (!cacheEnabled) {
        return;
      }
    }
    final List<Totp> cacheableTotps = List.of(totps ?? await ref.read(totpRepositoryProvider.future));
    for (int i = 0; i < cacheableTotps.length; i += _kFillCacheConcurrency) {
      final int end = (i + _kFillCacheConcurrency).clamp(0, cacheableTotps.length);
      await Future.wait([
        for (final Totp totp in cacheableTotps.sublist(i, end))
          cacheImage(
            totp,
            checkSettings: false,
          ),
      ]);
    }
  }

  /// Clears the cache.
  Future<void> clearCache() async {
    await _enqueueCacheMutation(() async {
      final Directory directory = await _getTotpImagesDirectory();
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
      if (ref.mounted) {
        state = const AsyncData({});
      }
    });
  }

  /// Returns the cache index.
  Future<File> _getIndexFile() async => File(join((await _getTotpImagesDirectory()).path, 'index.json'));

  /// Saves the content to the index.
  Future<void> _saveIndex({Map<String, CacheObject>? content}) async {
    content ??= await _readCachedState();
    final File index = await _getIndexFile();
    await index.create(recursive: true);
    await index.writeAsString(
      jsonEncode({
        for (final MapEntry<String, CacheObject> entry in content.entries) //
          entry.key: entry.value.toJson(),
      }),
    );
  }

  /// Queues a cache mutation to keep the state and index consistent.
  Future<void> _enqueueCacheMutation(Future<void> Function() mutation) {
    final Future<void> next = _cacheMutationQueue.catchError((Object error, StackTrace stackTrace) {}).then((_) => mutation());
    _cacheMutationQueue = next;
    return next;
  }

  /// Reads the current cached state as a mutable copy.
  Future<Map<String, CacheObject>> _readCachedState() async => Map<String, CacheObject>.from(_currentCachedState() ?? await future);

  /// Repairs the cache index and cached files so they match the current TOTP list.
  Future<Map<String, CacheObject>> _repairCache(Map<String, CacheObject> cached) async {
    final DateTime now = DateTime.now();
    final List<Totp> totps = await ref.read(totpRepositoryProvider.future);
    final Map<String, String> currentImageUrls = {
      for (final Totp totp in totps)
        if (totp.isDecrypted && (totp as DecryptedTotp).imageUrl != null) totp.uuid: totp.imageUrl!,
    };
    final Directory directory = await _getTotpImagesDirectory();
    final Set<String> fileNames = await directory.exists() ? (await directory.list().toList()).whereType<File>().map((file) => basename(file.path)).where((name) => name != 'index.json').toSet() : {};

    bool changed = false;
    final Map<String, CacheObject> repaired = {};

    for (final MapEntry<String, CacheObject> entry in cached.entries) {
      final String? currentImageUrl = currentImageUrls[entry.key];
      final bool isUnusedForTooLong = entry.value.lastAccessedAt != null && now.difference(entry.value.lastAccessedAt!) >= _kUnusedCacheTtl;
      final bool keep = currentImageUrl != null && currentImageUrl == entry.value.url && fileNames.contains(entry.key) && !isUnusedForTooLong;
      if (keep) {
        repaired[entry.key] = entry.value;
      } else {
        changed = true;
        await (await _getTotpCachedImageFile(entry.key)).deleteIfExists();
      }
    }

    for (final String fileName in fileNames.difference(repaired.keys.toSet())) {
      changed = true;
      await (await _getTotpCachedImageFile(fileName)).deleteIfExists();
    }

    if (changed) {
      await _saveIndex(content: repaired);
    }
    return repaired;
  }

  /// Returns the current cached state if it is already loaded.
  Map<String, CacheObject>? _currentCachedState() => switch (state) {
    AsyncData(:final Map<String, CacheObject> value) => value,
    _ => null,
  };

  /// Returns the TOTP cached image file.
  static Future<File> _getTotpCachedImageFile(String uuid, {bool createDirectory = false}) async => File(join((await _getTotpImagesDirectory(create: createDirectory)).path, uuid));

  /// Evicts every image provider variant used by TOTP images.
  static Future<void> _evictCachedImageFile(File file) async {
    final FileImage fileImage = FileImage(file);
    await fileImage.evict();
    await Future.wait([
      for (final double size in [
        TotpTile.kDefaultImageSize,
        TotpImage.kDefaultSize,
        TotpPage.kDefaultTotpImageSize,
      ])
        ResizeImage.resizeIfNeeded(size.toInt(), size.toInt(), fileImage).evict(),
    ]);
  }

  /// Returns the totp images directory, creating it if doesn't exist yet.
  static Future<Directory> _getTotpImagesDirectory({bool create = false}) async {
    final Directory directory = Directory(join((await getApplicationCacheDirectory()).path, 'totps_images'));
    if (create && !await directory.exists()) {
      await directory.create(recursive: true);
    }
    return directory;
  }
}

/// A cache object, holding a TOTP image URL with its type.
class CacheObject {
  /// The TOTP image url.
  final String url;

  /// The image type.
  final ImageType imageType;

  /// Whether this cache object has been created by a previous version of the app,
  /// that was not supporting `jovial_svg` yet.
  final bool legacy;

  /// The last access date.
  final DateTime? lastAccessedAt;

  /// Creates a new cache object file.
  const CacheObject({
    required this.url,
    required this.imageType,
    this.legacy = false,
    this.lastAccessedAt,
  });

  /// Creates a cache object thanks to the given JSON map.
  factory CacheObject.fromJson(dynamic json) {
    if (json is String) {
      return CacheObject(
        url: json,
        imageType: ImageType.inferFromSource(json),
        legacy: true,
      );
    }
    final String url = json['url'];
    return CacheObject(
      url: url,
      imageType: ImageType.values.firstWhere(
        (type) => type.name == json['imageType'],
        orElse: () => ImageType.inferFromSource(url),
      ),
      lastAccessedAt: json['lastAccessedAt'] == null ? null : DateTime.tryParse(json['lastAccessedAt']),
    );
  }

  /// Converts this object to a JSON map.
  Map<String, String> toJson() => {
    'url': url,
    'imageType': imageType.name,
    if (lastAccessedAt != null) 'lastAccessedAt': lastAccessedAt!.toIso8601String(),
  };

  /// Creates a new cache object instance with the given parameters change.
  CacheObject copyWith({
    String? url,
    ImageType? imageType,
    bool? legacy,
    DateTime? lastAccessedAt,
  }) => CacheObject(
    url: url ?? this.url,
    imageType: imageType ?? this.imageType,
    legacy: legacy ?? this.legacy,
    lastAccessedAt: lastAccessedAt ?? this.lastAccessedAt,
  );
}

/// Allows to easily delete a file without checking if it exists.
extension _DeleteIfExists on File {
  /// Deletes the current file if it exists.
  Future<void> deleteIfExists() async {
    if (await exists()) {
      await delete();
    }
  }
}
