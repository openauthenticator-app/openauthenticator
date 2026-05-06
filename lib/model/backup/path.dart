part of 'backup.dart';

/// Represents a backup path.
class BackupPath implements Comparable<BackupPath> {
  /// The backup filename regex.
  static const String _kBackupFilenameRegex = r'\d{13}\.bak';

  /// The backup path.
  final String path;

  /// The backup timestamp.
  final DateTime timestamp;

  /// Creates a new backup path instance.
  const BackupPath._({
    required this.path,
    required this.timestamp,
  });

  /// Returns the backup path from the given [path].
  static BackupPath? fromPath({required String path}) {
    DateTime? dateTime = _extractFromBackupPath(File(path));
    return dateTime == null
        ? null
        : BackupPath._(
            path: path,
            timestamp: dateTime,
          );
  }

  /// Creates a new backup path.
  static Future<BackupPath> create({DateTime? dateTime}) async {
    dateTime ??= DateTime.now();
    return BackupPath._(
      path: join((await getBackupsDirectory()).path, '${dateTime.millisecondsSinceEpoch}.bak'),
      timestamp: dateTime,
    );
  }

  /// Extracts the backup timestamp from the given [file].
  static DateTime? _extractFromBackupPath(File file) {
    if (!file.existsSync()) {
      return null;
    }
    RegExp backupRegex = RegExp(_kBackupFilenameRegex);
    String filename = file.uri.pathSegments.last;
    if (backupRegex.hasMatch(filename)) {
      return DateTime.fromMillisecondsSinceEpoch(int.parse(filename.substring(0, filename.length - '.bak'.length)));
    }
    return null;
  }

  @override
  int compareTo(BackupPath other) => other.timestamp.compareTo(timestamp);

  /// Reads the backup content.
  Backup read(CryptoStore currentCryptoStore, String password) => Backup._read(this, currentCryptoStore, password);

  /// Returns the backup file.
  File get file => File(path);

  /// Returns the backup filename.
  String get filename => file.uri.pathSegments.last;

  /// Creates the backup file if it doesn't exist.
  Future<File> createFile() async {
    File file = this.file;
    if (!file.existsSync()) {
      await file.create(recursive: true);
    }
    return file;
  }

  /// Deletes this backup.
  Future<void> delete() async {
    File file = this.file;
    if (file.existsSync()) {
      await file.delete();
    }
  }

  /// Returns the backup directory.
  static Future<Directory> getBackupsDirectory({bool create = false}) async {
    String name = '${App.appName} Backups${kDebugMode ? ' (Debug)' : ''}';
    Directory directory = Directory(join((await getApplicationDocumentsDirectory()).path, name));
    if (create && !directory.existsSync()) {
      directory.createSync(recursive: true);
    }
    return directory;
  }
}
