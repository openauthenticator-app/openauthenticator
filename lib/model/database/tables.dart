part of 'database.dart';

/// Represents a [Totp].
@DataClassName('_DriftTotp')
class Totps extends Table {
  /// Maps to [Totp.uuid].
  TextColumn get uuid => text()();

  /// Maps to [Totp.encryptedData.encryptedSecret].
  TextColumn get secret => text().map(const Uint8ListConverter())();

  /// Maps to [Totp.encryptedData.encryptedLabel].
  TextColumn get label => text().map(const Uint8ListConverter()).nullable()();

  /// Maps to [Totp.encryptedData.encryptedIssuer].
  TextColumn get issuer => text().map(const Uint8ListConverter()).nullable()();

  /// Maps to [Totp.algorithm].
  TextColumn get algorithm => textEnum<Algorithm>().nullable()();

  /// Maps to [Totp.digits].
  IntColumn get digits => integer().nullable()();

  /// Maps to [Totp.validity].
  IntColumn get validity => integer().map(const DurationConverter()).nullable()();

  /// Maps to [Totp.encryptedData.encryptedImageUrl].
  TextColumn get imageUrl => text().map(const Uint8ListConverter()).nullable()();

  /// Maps to [Totp.encryptedData.encryptionSalt].
  TextColumn get encryptionSalt => text().map(const Uint8ListConverter())();

  /// Maps to [Totp.updatedAt].
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {uuid};
}

/// Represents a deleted [Totp].
@DataClassName('_DriftDeletedTotp')
class DeletedTotps extends Table {
  /// Maps to [Totp.uuid].
  TextColumn get uuid => text()();

  @override
  Set<Column> get primaryKey => {uuid};
}

/// Represents a pending [PushOperation].
@DataClassName('_DriftBackendPushOperation')
class PendingBackendPushOperations extends Table {
  /// Maps to [PushOperation.uuid].
  TextColumn get uuid => text()();

  /// The push operation kind.
  TextColumn get kind => textEnum<PushOperationKind>()();

  /// Maps to [PushOperation.payload].
  TextColumn get jsonPayload => text()();

  /// Maps to [PushOperation.createdAt].
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {uuid};
}

/// Represents a backend push operation error.
@DataClassName('_DriftBackendPushOperationError')
class BackendPushOperationErrors extends Table {
  /// Maps to [PushOperationResult.operationUuid].
  TextColumn get operationUuid => text()();

  /// Maps to [PushOperationResult.totpUuid].
  TextColumn get totpUuid => text()();

  /// Maps to [PushOperationResult.errorKind].
  TextColumn get errorKind => textEnum<PushOperationErrorKind>()();

  /// Maps to [PushOperationResult.errorDetails].
  TextColumn get errorDetails => text().nullable()();

  /// Maps to [PushOperationResult.createdAt].
  IntColumn get createdAt => integer()();
}

/// Represents a push operation kind.
enum PushOperationKind {
  /// Represents a set operation.
  set,

  /// Represents a delete operation.
  delete,
}
