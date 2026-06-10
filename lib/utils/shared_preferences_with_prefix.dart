import 'package:flutter/foundation.dart';
import 'package:open_authenticator/utils/platform.dart';
import 'package:shared_preferences/shared_preferences.dart';
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_linux/shared_preferences_linux.dart';
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_windows/shared_preferences_windows.dart';

/// Allows to use [SharedPreferencesWithCache] with a prefix.
class SharedPreferencesWithPrefix {
  /// The shared preferences instance.
  final SharedPreferencesWithCache _sharedPreferences;

  /// The prefix.
  final String prefix;

  /// Creates a new shared preferences with prefix instance.
  const SharedPreferencesWithPrefix._({
    required this._sharedPreferences,
    this.prefix = '',
  });

  /// Creates a new instance with the given options and reloads the cache from the platform data.
  static Future<SharedPreferencesWithPrefix> create({
    String prefix = kDebugMode ? 'flutterDebug.' : 'flutter.',
  }) async {
    SharedPreferencesWithPrefix sharedPreferencesWithPrefix = await _createSharedPreferencesWithPrefix(prefix);
    return sharedPreferencesWithPrefix;
  }

  /// Creates a new shared preferences with prefix instance.
  static Future<SharedPreferencesWithPrefix> _createSharedPreferencesWithPrefix(
    String prefix, {
    String fileName = kDebugMode ? 'shared_preferences_debug' : 'shared_preferences',
  }) async => SharedPreferencesWithPrefix._(
    sharedPreferences: await SharedPreferencesWithCache.create(
      sharedPreferencesOptions: switch (currentPlatform) {
        Platform.windows => SharedPreferencesWindowsOptions(fileName: fileName),
        Platform.linux => SharedPreferencesLinuxOptions(fileName: fileName),
        _ => const SharedPreferencesOptions(),
      },
      cacheOptions: const SharedPreferencesWithCacheOptions(),
    ),
    prefix: prefix,
  );

  /// Returns true if cache contains the given [key].
  ///
  /// Throws an [ArgumentError] if [key] is not in this instance's filter.
  bool containsKey(String key) => _sharedPreferences.containsKey(prefix + key);

  /// Returns all keys in the cache.
  Set<String> get keys => {
    for (String key in _sharedPreferences.keys)
      if (key.startsWith(prefix)) key.substring(prefix.length),
  };

  /// Reads a value of any type from the cache.
  ///
  /// Throws an [ArgumentError] if [key] is not in this instance's filter.
  Object? get(String key) => _sharedPreferences.get(prefix + key);

  /// Reads a value from the cache, throwing a [TypeError] if the value is not a
  /// bool.
  ///
  /// Throws an [ArgumentError] if [key] is not in this instance's filter.
  bool? getBool(String key) => _sharedPreferences.getBool(prefix + key);

  /// Reads a value from the cache, throwing a [TypeError] if the value is not
  /// an int.
  ///
  /// Throws an [ArgumentError] if [key] is not in this instance's filter.
  int? getInt(String key) => _sharedPreferences.getInt(prefix + key);

  /// Reads a value from the cache, throwing a [TypeError] if the value is not a
  /// double.
  ///
  /// Throws an [ArgumentError] if [key] is not in this instance's filter.
  double? getDouble(String key) => _sharedPreferences.getDouble(prefix + key);

  /// Reads a value from the cache, throwing a [TypeError] if the value is not a
  /// String.
  ///
  /// Throws an [ArgumentError] if [key] is not in this instance's filter.
  String? getString(String key) => _sharedPreferences.getString(prefix + key);

  /// Reads a list of string values from the cache, throwing an
  /// exception if it's not a string list.
  ///
  /// Throws an [ArgumentError] if [key] is not in this instance's filter.
  List<String>? getStringList(String key) => _sharedPreferences.getStringList(prefix + key);

  /// Saves a boolean [value] to the cache and platform.
  ///
  /// Throws an [ArgumentError] if [key] is not in this instance's filter.
  Future<void> setBool(String key, bool value) async => await _sharedPreferences.setBool(prefix + key, value);

  /// Saves an integer [value] to the cache and platform.
  ///
  /// Throws an [ArgumentError] if [key] is not in this instance's filter.
  Future<void> setInt(String key, int value) async => await _sharedPreferences.setInt(prefix + key, value);

  /// Saves a double [value] to the cache and platform.
  ///
  /// On platforms that do not support storing doubles,
  /// the value will be stored as a float instead.
  ///
  /// Throws an [ArgumentError] if [key] is not in this instance's filter.
  Future<void> setDouble(String key, double value) async => await _sharedPreferences.setDouble(prefix + key, value);

  /// Saves a string [value] to the cache and platform.
  ///
  /// Note: Due to limitations on some platforms,
  /// values cannot start with the following:
  ///
  /// - 'VGhpcyBpcyB0aGUgcHJlZml4IGZvciBhIGxpc3Qu'
  ///
  /// Throws an [ArgumentError] if [key] is not in this instance's filter.
  Future<void> setString(String key, String value) async => await _sharedPreferences.setString(prefix + key, value);

  /// Saves a list of strings [value] to the cache and platform.
  ///
  /// Throws an [ArgumentError] if [key] is not in this instance's filter.
  Future<void> setStringList(String key, List<String> value) async => await _sharedPreferences.setStringList(prefix + key, value);

  /// Removes an entry from cache and platform.
  ///
  /// Throws an [ArgumentError] if [key] is not in this instance's filter.
  Future<void> remove(String key) async => await _sharedPreferences.remove(prefix + key);

  /// Clears cache and platform preferences that match filter options.
  Future<void> clear() async => Future.forEach(keys, remove);
}
