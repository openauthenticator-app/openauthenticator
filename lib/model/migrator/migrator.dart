import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
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
import 'package:open_authenticator/model/totp/json.dart';
import 'package:open_authenticator/model/totp/repository.dart';
import 'package:open_authenticator/model/totp/totp.dart';
import 'package:open_authenticator/utils/result/result.dart';
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
        await Future.delayed(const Duration(seconds: 2));
        Result totpsMigrationResult = await _migrateFirebaseTotps();
        Result userMigrationResult = await _migrateFirebaseUser();
        if (totpsMigrationResult is! ResultSuccess || userMigrationResult is! ResultSuccess) {
          if (totpsMigrationResult is ResultError) {
            Error.throwWithStackTrace(totpsMigrationResult.exception, totpsMigrationResult.stackTrace);
          }
          if (userMigrationResult is ResultError) {
            Error.throwWithStackTrace(userMigrationResult.exception, userMigrationResult.stackTrace);
          }
          return (totpsMigrationResult is! ResultSuccess ? userMigrationResult : totpsMigrationResult).to((_) => null);
        }
      }
      await markMigrated();
      return ResultSuccess(value: newStorageType);
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

  /// Migrates the Firestore stored TOTPs to the new database.
  Future<Result> _migrateFirebaseTotps({
    String userDataDocumentName = 'userData',
    String totpsCollectionName = 'totps',
    String updatedAtFieldName = 'updated',
  }) async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw _NoFirebaseUserException();
      }
      DocumentReference<Map<String, dynamic>> userDataDocument = FirebaseFirestore.instance.collection(user.uid).doc(userDataDocumentName);
      CollectionReference totpsCollection = userDataDocument.collection(totpsCollectionName);
      QuerySnapshot result = await totpsCollection.orderBy(Totp.kIssuerKey).get();
      List<QueryDocumentSnapshot> docs = result.docs;
      List<Totp> totps = [];
      int now = DateTime.now().millisecondsSinceEpoch;
      for (QueryDocumentSnapshot doc in docs) {
        dynamic data = doc.data();
        if (data is! Map<String, Object?>) {
          continue;
        }
        int updatedAt = data[updatedAtFieldName] is Timestamp ? (data[updatedAtFieldName] as Timestamp).toDate().millisecondsSinceEpoch : now;
        Totp? totp = JsonTotp.tryFromJson({
          ...data,
          Totp.kUpdatedAtKey: updatedAt,
        });
        if (totp != null) {
          totps.add(totp);
        }
      }
      await ref.read(totpRepositoryProvider.notifier).addTotps(totps);
      return const ResultSuccess();
    } catch (ex, stackTrace) {
      return ResultError(
        exception: ex,
        stackTrace: stackTrace,
      );
    }
  }

  /// Migrates the Firebase user to the new backend.
  Future<Result<StorageType>> _migrateFirebaseUser() async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw _NoFirebaseUserException();
      }
      String? idToken = await user.getIdToken(forceRefresh: true);
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
          'userId': user.uid,
          'idToken': idToken,
          'debug': kDebugMode,
        }),
      );
      Map<String, dynamic> json = {'success': false};
      try {
        json = jsonDecode(response.body);
      } on FormatException catch (_) {
        throw _HttpErrorException(response: response);
      }
      if (!json['success']) {
        String errorCode = json['data']?['errorCode'] ?? 'migration';
        if (errorCode == 'userAlreadyExists') {
          return const ResultSuccess();
        }
        throw _MigrationRequestException(
          errorCode: errorCode,
          message: json['data']?['message'],
        );
      }
      return const ResultSuccess();
    } catch (ex, stackTrace) {
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

/// Thrown when the Firebase user could not be retrieved.
class _NoFirebaseUserException extends LocalizableException {
  /// Creates a new no firebase user exception instance.
  _NoFirebaseUserException()
    : super(
        localizedErrorMessage: translations.error.migrator.noFirebaseUser,
      );
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

/// Thrown when the migration request failed.
class _MigrationRequestException extends LocalizableException {
  /// The message.
  final String? message;

  /// Creates a new migration request exception instance.
  _MigrationRequestException({
    String errorCode = 'migration',
    this.message,
  }) : super(
         localizedErrorMessage: switch (errorCode) {
           'firebaseUserNotFound' => translations.error.migrator.firebaseUserNotFound,
           'invalidIdToken' => translations.error.migrator.invalidIdToken,
           'invalidUserId' => translations.error.migrator.invalidUserId,
           'userAlreadyMigrated' || 'userAlreadyExists' => translations.error.migrator.userAlreadyMigrated,
           'noSupportedAuthenticationProvider' => translations.error.migrator.noSupportedAuthenticationProvider,
           'userWithProviderIdAlreadyExists' => translations.error.migrator.userWithProviderIdAlreadyExists,
           'userCreationFailed' => translations.error.migrator.userCreationFailed,
           _ => translations.error.generic.withException(exception: errorCode),
         },
       );

  @override
  String toString() => [
    super.toString(),
    if (message != null && message!.isNotEmpty) message,
  ].join('\n');
}
