part of 'backup.dart';

/// Represents a backup path.
class BackupPath implements Comparable<BackupPath> {
  /// The backup filename regex.
  static const String _kBackupFilenameRegex = r'^\d{13}\.bak$';

  /// The name of the folder containing the vault backups.
  static const String _directoryName = '${App.appName} Backups${kDebugMode ? ' (Debug)' : ''}';

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
    final int timestamp = (dateTime ?? DateTime.now()).millisecondsSinceEpoch;
    try {
      return await _createIn(await getBackupsDirectory(create: true), timestamp);
    } on FileSystemException {
      if (!_hasFallbackDirectory) {
        rethrow;
      }
      // Documents may be read-only for the app (eg. sandboxes or Windows controlled folder access).
      final Directory fallback = await _getFallbackBackupsDirectory();
      await fallback.create(recursive: true);
      return await _createIn(fallback, timestamp);
    }
  }

  /// Creates a new backup file in [directory], incrementing [initialTimestamp] until the filename is available.
  static Future<BackupPath> _createIn(Directory directory, int initialTimestamp) async {
    int timestamp = initialTimestamp;
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

  /// Whether backups can be stored in the app support directory when Documents is not usable.
  /// Documents is preferred, because it is kept when the app is uninstalled and is often synchronized by the user.
  static bool get _hasFallbackDirectory => Platform.isLinux || Platform.isWindows;

  /// Returns the directory where new backups are stored.
  static Future<Directory> getBackupsDirectory({bool create = false}) async {
    final Directory directory = await _getDocumentsBackupsDirectory() ?? await _getFallbackBackupsDirectory();
    if (create) {
      await directory.create(recursive: true);
    }
    return directory;
  }

  /// Returns the backups directory inside Documents, if Documents is available.
  static Future<Directory?> _getDocumentsBackupsDirectory() async {
    try {
      return Directory(join((await getApplicationDocumentsDirectory()).path, _directoryName));
    } on MissingPlatformDirectoryException {
      if (!_hasFallbackDirectory) {
        rethrow;
      }
      return null;
    }
  }

  /// Returns the backups directory inside the app support directory.
  static Future<Directory> _getFallbackBackupsDirectory() async => Directory(join((await getApplicationSupportDirectory()).path, _directoryName));

  /// Lists current backups, including the ones stored in the fallback directory.
  static Stream<BackupPath> list() async* {
    final Set<String> listed = {};
    for (final Directory? directory in [
      await _getDocumentsBackupsDirectory(),
      if (_hasFallbackDirectory) await _getFallbackBackupsDirectory(),
    ]) {
      if (directory != null && listed.add(directory.absolute.path)) {
        yield* Stream.fromIterable(await _listDirectory(directory));
      }
    }
  }

  /// Enumerates backup files directly inside [directory].
  static Future<List<BackupPath>> _listDirectory(Directory directory) async {
    final List<BackupPath> result = [];
    try {
      if (await directory.exists()) {
        await for (final FileSystemEntity entity in directory.list(followLinks: false)) {
          if (entity is File) {
            final BackupPath? backup = fromPath(path: entity.path);
            if (backup != null) {
              result.add(backup);
            }
          }
        }
      }
    } on FileSystemException {
      if (!_hasFallbackDirectory) {
        rethrow;
      }
      // An inaccessible directory (eg. sandboxed Documents) must not hide the other backups.
    }
    return result;
  }
}
