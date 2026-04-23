import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_authenticator/model/settings/entry.dart';
import 'package:open_authenticator/model/totp/image_cache.dart';

/// The cache TOTP pictures settings entry provider.
final cacheTotpPicturesSettingsEntryProvider = AsyncNotifierProvider.autoDispose<CacheTotpPicturesSettingsEntry, bool>(CacheTotpPicturesSettingsEntry.new);

/// A settings entry that allows to control whether we have to cache TOTP pictures.
class CacheTotpPicturesSettingsEntry extends SettingsEntry<bool> {
  /// Creates a new cache TOTP pictures settings entry instance.
  CacheTotpPicturesSettingsEntry()
    : super(
        key: 'cacheTotpPictures',
        defaultValue: true,
      );

  @override
  Future<void> changeValue(bool value) async {
    if (value != state.value && ref.mounted) {
      state = const AsyncLoading();
      TotpImageCacheManager totpImageCacheManager = ref.read(totpImageCacheManagerProvider.notifier);
      if (value) {
        await totpImageCacheManager.fillCache(checkSettings: false);
      } else {
        await totpImageCacheManager.clearCache();
      }
    }
    await super.changeValue(value);
  }
}
