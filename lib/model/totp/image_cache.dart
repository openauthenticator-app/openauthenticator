import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:open_authenticator/model/settings/cache_totp_pictures.dart';
import 'package:open_authenticator/model/totp/decrypted.dart';
import 'package:open_authenticator/model/totp/repository.dart';
import 'package:open_authenticator/model/totp/totp.dart';
import 'package:open_authenticator/utils/image_type.dart';
import 'package:open_authenticator/utils/jovial_svg.dart';
import 'package:open_authenticator/utils/utils.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

/// The TOTP image cache manager provider.
final totpImageCacheManagerProvider = AsyncNotifierProvider.autoDispose<TotpImageCacheManager, Map<String, CacheObject>>(TotpImageCacheManager.new);

/// Manages the cache of TOTPs images.
class TotpImageCacheManager extends AsyncNotifier<Map<String, CacheObject>> {
  @override
  FutureOr<Map<String, CacheObject>> build() async {
    File index = await _getIndexFile();
    if (!index.existsSync()) {
      return {};
    }
    Map<String, dynamic> json = jsonDecode(index.readAsStringSync());
    return {
      for (MapEntry<String, dynamic> entry in json.entries) //
        entry.key: CacheObject.fromJson(entry.value),
    };
  }

  /// Caches the TOTP image.
  Future<void> cacheImage(Totp totp, {bool checkSettings = true}) async {
    try {
      if (!totp.isDecrypted) {
        return;
      }
      if (checkSettings) {
        bool cacheEnabled = await ref.read(cacheTotpPicturesSettingsEntryProvider.future);
        if (!cacheEnabled) {
          return;
        }
      }
      String? imageUrl = (totp as DecryptedTotp).imageUrl;
      if (imageUrl == null) {
        await deleteCachedImage(totp.uuid);
      } else {
        Map<String, CacheObject> cached = Map.from(await future);
        CacheObject? previousCacheObject = cached[totp.uuid];
        File file = await _getTotpCachedImageFile(totp.uuid, createDirectory: true);
        if (previousCacheObject?.url == imageUrl && file.existsSync()) {
          return;
        }
        http.Response response = await http.get(Uri.parse(imageUrl));
        await file.writeAsBytes(response.bodyBytes);
        ImageType imageType;
        if (imageUrl.endsWith('.svg')) {
          imageType = ImageType.svg;
          if (await JovialSvgUtils.svgToSi(response.body, file)) {
            imageType = ImageType.si;
          }
        } else {
          imageType = ImageType.other;
        }

        cached[totp.uuid] = CacheObject(
          url: imageUrl,
          imageType: imageType,
        );
        if (ref.mounted) {
          state = AsyncData(cached);
        }
        imageCache.clear();
        _saveIndex(content: cached);
      }
    } catch (ex, stackTrace) {
      handleException(ex, stackTrace);
    }
  }

  /// Deletes the cached images, if possible.
  Future<void> deleteCachedImages(Iterable<String> uuids) async {
    Map<String, CacheObject> cached = Map.from(await future);
    for (String uuid in uuids) {
      File file = await _getTotpCachedImageFile(uuid);
      file.deleteIfExists();
      cached.remove(uuid);
    }
    if (ref.mounted) {
      state = AsyncData(cached);
    }
    _saveIndex(content: cached);
  }

  /// Deletes the cached image, if possible.
  Future<void> deleteCachedImage(String uuid) => deleteCachedImages([uuid]);

  /// Fills the cache with all TOTPs that can be read from the TOTP repository.
  Future<void> fillCache({Iterable<Totp>? totps, bool checkSettings = true}) async {
    if (checkSettings) {
      bool cacheEnabled = await ref.read(cacheTotpPicturesSettingsEntryProvider.future);
      if (!cacheEnabled) {
        return;
      }
    }
    totps ??= await ref.read(totpRepositoryProvider.future);
    for (Totp totp in totps!) {
      await cacheImage(
        totp,
        checkSettings: false,
      );
    }
  }

  /// Clears the cache.
  Future<void> clearCache() async {
    Directory directory = await _getTotpImagesDirectory();
    if (directory.existsSync()) {
      directory.deleteSync(recursive: true);
    }
    if (ref.mounted) {
      state = const AsyncData({});
    }
  }

  /// Returns the cache index.
  Future<File> _getIndexFile() async => File(join((await _getTotpImagesDirectory()).path, 'index.json'));

  /// Saves the content to the index.
  Future<void> _saveIndex({Map<String, CacheObject>? content}) async {
    content ??= await future;
    File index = await _getIndexFile();
    index.createSync(recursive: true);
    index.writeAsStringSync(
      jsonEncode({
        for (MapEntry<String, CacheObject> entry in content.entries) //
          entry.key: entry.value.toJson(),
      }),
    );
  }

  /// Returns the TOTP cached image file.
  static Future<File> _getTotpCachedImageFile(String uuid, {bool createDirectory = false}) async => File(join((await _getTotpImagesDirectory(create: createDirectory)).path, uuid));

  /// Returns the totp images directory, creating it if doesn't exist yet.
  static Future<Directory> _getTotpImagesDirectory({bool create = false}) async {
    Directory directory = Directory(join((await getApplicationCacheDirectory()).path, 'totps_images'));
    if (create && !directory.existsSync()) {
      directory.createSync(recursive: true);
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

  /// Creates a new cache object file.
  const CacheObject({
    required this.url,
    required this.imageType,
    this.legacy = false,
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
    String url = json['url'];
    return CacheObject(
      url: url,
      imageType: ImageType.values.firstWhere(
        (type) => type.name == json['imageType'],
        orElse: () => ImageType.inferFromSource(url),
      ),
    );
  }

  /// Converts this object to a JSON map.
  Map<String, String> toJson() => {
    'url': url,
    'imageType': imageType.name,
  };

  /// Creates a new cache object instance with the given parameters change.
  CacheObject copyWith({
    String? url,
    ImageType? imageType,
    bool? legacy,
  }) => CacheObject(
    url: url ?? this.url,
    imageType: imageType ?? this.imageType,
    legacy: legacy ?? this.legacy,
  );
}

/// An extension that allows to obtain the cached image associated with a TOTP.
extension GetCachedImage on Map<String, CacheObject> {
  /// Returns the cached image that corresponds to the TOTP UUID and current image URL.
  Future<(File, ImageType)?> getCachedImage(String uuid, String? imageUrl) async {
    if (!containsKey(uuid) || this[uuid]?.url != imageUrl) {
      return null;
    }
    return (await TotpImageCacheManager._getTotpCachedImageFile(uuid), this[uuid]!.imageType);
  }
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
