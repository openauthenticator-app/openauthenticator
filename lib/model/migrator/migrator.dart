import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:open_authenticator/model/backend/authentication/providers/provider.dart';
import 'package:open_authenticator/model/backend/synchronization/queue.dart';
import 'package:open_authenticator/model/database/database.dart';
import 'package:open_authenticator/model/migrator/firebase_auth/firebase_auth.dart';
import 'package:open_authenticator/model/migrator/firebase_options.dart';
import 'package:open_authenticator/model/settings/entry.dart';
import 'package:open_authenticator/model/settings/storage_type.dart';
import 'package:open_authenticator/utils/result.dart';
import 'package:open_authenticator/utils/shared_preferences_with_prefix.dart';
import 'package:open_authenticator/utils/sqlite.dart';

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
    File oldDatabase = await SqliteUtils.getDatabaseFile('totps');
    if (oldDatabase.existsSync()) {
      return .needed;
    }
    return .notNeeded;
  }

  /// Migrates the app data to the new database and the new backend.
  Future<Result> migrate() async {
    try {
      await ref.read(appDatabaseProvider).close();
      File oldDatabase = await SqliteUtils.getDatabaseFile('totps');
      File newDatabase = await SqliteUtils.getDatabaseFile('app');
      await oldDatabase.copy(newDatabase.path);
      AppDatabase storage = AppDatabase();
      await storage.close();
      ref.invalidate(appDatabaseProvider);

      SharedPreferencesWithPrefix preferences = await ref.read(sharedPreferencesProvider.future);
      String? storageType = preferences.getString('storageType');
      StorageType newStorageType = storageType == 'online' ? StorageType.shared : StorageType.localOnly;
      if (newStorageType == .shared) {
        await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
        await FirebaseAuth.instance.initialize();
        await Future.delayed(const Duration(seconds: 1));
        User? user = FirebaseAuth.instance.currentUser;
        String? idToken = await user?.getIdToken();
        if (idToken == null) {
          throw Exception('Could not get ID token.');
        }
        http.Response response = await http.post(
          Uri.https(
            'login.openauthenticator.app',
            '/migrate',
          ),
          headers: {
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'userId': user!.uid,
            'idToken': idToken,
          }),
        );
        if (response.statusCode != 200) {
          throw Exception('Migration failed. HTTP Error ${response.statusCode} : ${response.body}.');
        }
        Map<String, dynamic> data = jsonDecode(response.body);
        AuthenticationProvider? provider = ref.read(authenticationProvider(data['providerId']));
        if (provider == null) {
          throw Exception('Could not find authentication provider ${data['providerId']}');
        }
        Result result = await provider.onRedirectReceived(Uri.parse(data['redirectUrl']));
        if (result is! ResultSuccess) {
          if (result is ResultCancelled) {
            throw Exception('Migration cancelled.');
          }
          Error.throwWithStackTrace((result as ResultError).exception, result.stackTrace);
        }
      }
      await ref.read(storageTypeSettingsEntryProvider.notifier).changeValue(newStorageType);
      ref.read(synchronizationControllerProvider.notifier).notifyLocalChange();
      await markMigrated();
      return const ResultSuccess();
    } catch (ex, stackTrace) {
      state = AsyncError(ex, stackTrace);
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
    state = const AsyncData(.done);
  }
}

/// The migration state.
enum MigrationState {
  /// The migration is not needed.
  notNeeded,

  /// The migration is needed.
  needed,

  /// The migration is done.
  done;
}
