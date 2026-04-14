import 'dart:async';
import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:open_authenticator/i18n/localizable_exception.dart';
import 'package:open_authenticator/i18n/translations.g.dart';
import 'package:open_authenticator/model/migrator/firebase_auth/firebase_auth.dart';
import 'package:open_authenticator/model/migrator/firebase_options.dart';
import 'package:open_authenticator/model/settings/entry.dart';
import 'package:open_authenticator/model/settings/storage_type.dart';
import 'package:open_authenticator/utils/result.dart';
import 'package:open_authenticator/utils/shared_preferences_with_prefix.dart';

/// The migrator provider.
final migratorProvider = AsyncNotifierProvider<Migrator, MigrationState>(Migrator.new);

/// Allows to migrate the app data to the new database and the new backend.
class Migrator extends AsyncNotifier<MigrationState> {
  @override
  Future<MigrationState> build() async {
    SharedPreferencesWithPrefix preferences = await ref.watch(sharedPreferencesProvider.future);
    int migratorVersion = preferences.getInt('migratorVersion') ?? 1;
    if (migratorVersion >= 2) {
      return .done;
    }
    String? storageType = preferences.getString('storageType');
    if ({'local', 'online'}.contains(storageType)) {
      return .needed;
    }
    return .notNeeded;
  }

  /// Changes the migration state.
  void changeValue(MigrationState value) {
    if (ref.mounted) {
      state = AsyncData(value);
    }
  }

  /// Migrates the app data to the new database and the new backend.
  Future<Result<StorageType>> migrate() async {
    try {
      SharedPreferencesWithPrefix preferences = await ref.read(sharedPreferencesProvider.future);
      String? storageType = preferences.getString('storageType');
      StorageType newStorageType = storageType == 'online' ? .shared : .localOnly;
      if (newStorageType == .shared) {
        await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
        await FirebaseAuth.instance.initialize();
        await Future.delayed(const Duration(seconds: 1));
        User? user = FirebaseAuth.instance.currentUser;
        String? idToken = await user?.getIdToken(forceRefresh: true);
        if (idToken == null) {
          throw _IdTokenException();
        }
        http.Response response = await http.post(
          Uri.https(
            'europe-west1-open-authenticator-by-skyost.cloudfunctions.net',
            '/migrate',
          ),
          headers: {
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'userId': user!.uid,
            'idToken': idToken,
            'debug': kDebugMode,
          }),
        );
        if (response.statusCode != 200) {
          if (response.statusCode == 400 && response.body.contains('User already migrated')) {
            await markMigrated();
            return const ResultSuccess(value: .shared);
          }
          throw _HttpErrorException(response: response);
        }
      }
      await markMigrated();
      return const ResultSuccess(value: .localOnly);
    } catch (ex, stackTrace) {
      if (ref.mounted) {
        state = AsyncError(ex, stackTrace);
      }
      return ResultError(
        exception: ex,
        stackTrace: stackTrace,
      );
    }
  }

  /// Marks the migration as done.
  Future<void> markMigrated() async {
    SharedPreferencesWithPrefix preferences = await ref.read(sharedPreferencesProvider.future);
    await preferences.setInt('migratorVersion', 2);
    if (ref.mounted) {
      state = const AsyncData(.done);
    }
  }
}

/// The migration state.
enum MigrationState {
  /// The migration is not needed.
  notNeeded,

  /// The migration is needed.
  needed,

  /// The migration is done.
  done,
}

/// Thrown when the ID token could not be retrieved.
class _IdTokenException extends LocalizableException {
  /// Creates a new id token exception instance.
  _IdTokenException()
    : super(
        localizedErrorMessage: translations.error.migrator.idToken,
      );
}

/// Thrown when an HTTP error occurred.
class _HttpErrorException extends LocalizableException {
  /// Creates a new http error exception instance.
  _HttpErrorException({
    required http.Response response,
  }) : super(
         localizedErrorMessage: translations.error.migrator.httpError(
           statusCode: response.statusCode,
           body: response.body,
         ),
       );
}
