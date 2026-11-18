import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Contains some useful functions to use alongside SQLite.
class SqliteUtils {
  /// Opens a connection to a local database.
  static QueryExecutor openConnection(String dbFileName) => driftDatabase(
    name: getDbFileName(dbFileName),
    native: const DriftNativeOptions(
      databaseDirectory: getApplicationSupportDirectory,
    ),
  );

  /// Returns the database file name (without extension), with a suffix in debug mode.
  static String getDbFileName(String dbFileName) => kDebugMode ? '${dbFileName}_debug' : dbFileName;
}
