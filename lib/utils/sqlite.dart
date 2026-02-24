import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Contains some useful functions to use alongside SQLite.
class SqliteUtils {
  /// Gets the path to the database file.
  static Future<File> getDatabaseFile(String dbFileName, {bool addDebugModeSuffix = true}) async {
    if (addDebugModeSuffix && kDebugMode) {
      dbFileName += '_debug';
    }
    Directory directory = await getApplicationSupportDirectory();
    return File('${directory.path}/$dbFileName');
  }

  /// Opens a connection to a local database.
  static QueryExecutor openConnection(String dbFileName, {bool addDebugModeSuffix = true}) {
    if (addDebugModeSuffix && kDebugMode) {
      dbFileName += '_debug';
    }
    return driftDatabase(
      name: dbFileName,
      native: const DriftNativeOptions(
        databaseDirectory: getApplicationSupportDirectory,
      ),
    );
  }
}
