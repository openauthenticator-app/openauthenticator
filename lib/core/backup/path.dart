part of 'backup.dart';

/// Represents a backup path.
class BackupPath implements Comparable<BackupPath> {
  /// The backup filename regex.
  static const String _kBackupFilenameRegex = r'^\d{13}\.bak$';

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
    final DateTime? dateTime = _extractFromBackupPath(File(path));
    return dateTime == null
        ? null
        : BackupPath._(
            path: path,
            timestamp: dateTime,
          );
  }

  /// Creates a new backup path.
  static Future<BackupPath> create({DateTime? dateTime}) async {
    final Directory directory = await getBackupsDirectory(create: true);
    int timestamp = (dateTime ?? DateTime.now()).millisecondsSinceEpoch;
    while (true) {
      final File destination = File(join(directory.path, '$timestamp.bak'));
      try {
        await destination.create(exclusive: true);
        return BackupPath._(path: destination.path, timestamp: DateTime.fromMillisecondsSinceEpoch(timestamp));
      } on PathExistsException {
        timestamp++;
      }
    }
  }

  /// Extracts the backup timestamp from the given [file].
  static DateTime? _extractFromBackupPath(File file) {
    if (!file.existsSync()) {
      return null;
    }
    final RegExp backupRegex = RegExp(_kBackupFilenameRegex);
    final String filename = file.uri.pathSegments.last;
    if (backupRegex.hasMatch(filename)) {
      return DateTime.fromMillisecondsSinceEpoch(int.parse(filename.substring(0, filename.length - '.bak'.length)));
    }
    return null;
  }

  @override
  int compareTo(BackupPath other) => other.timestamp.compareTo(timestamp);

  /// Reads the backup content.
  Future<Backup> read(CryptoStore currentCryptoStore, String password) => Backup._read(this, currentCryptoStore, password);

  /// Returns the backup file.
  File get file => File(path);

  /// Returns the backup filename.
  String get filename => file.uri.pathSegments.last;

  /// Deletes this backup.
  Future<void> delete() async {
    final File file = this.file;
    if (file.existsSync()) {
      await file.delete();
    }
  }

  static const String _directoryName = '${App.appName} Backups${kDebugMode ? ' (Debug)' : ''}';

  static bool get _useAppDirectory => Platform.isLinux || Platform.isWindows;

  /// Returns the directory where new backups are stored.
  static Future<Directory> getBackupsDirectory({bool create = false}) async {
    final Directory parent = _useAppDirectory ? await getApplicationSupportDirectory() : await getApplicationDocumentsDirectory();
    final directory = Directory(join(parent.path, _directoryName));
    if (create) {
      await directory.create(recursive: true);
    }
    return directory;
  }

  /// Lists current backups, including accessible collections in Documents.
  static Stream<BackupPath> list() async* {
    final Directory directory = await getBackupsDirectory();
    yield* _listDirectory(directory);
    if (_useAppDirectory) {
      try {
        final documents = Directory(join((await getApplicationDocumentsDirectory()).path, _directoryName));
        if (documents.path != directory.path) {
          yield* _listDirectory(documents);
        }
      } on PathAccessException {
        // Sandboxed apps may not have access to Documents.
      } on MissingPlatformDirectoryException {
        // Documents may be unavailable on this device.
      }
    }
  }

  static Stream<BackupPath> _listDirectory(Directory directory) async* {
    if (await directory.exists()) {
      await for (final FileSystemEntity entity in directory.list(followLinks: false)) {
        if (entity is File) {
          final BackupPath? backup = fromPath(path: entity.path);
          if (backup != null) {
            yield backup;
          }
        }
      }
    }
  }
}
