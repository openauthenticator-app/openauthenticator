import 'package:equatable/equatable.dart';
import 'package:open_authenticator/i18n/translations.g.dart';

/// Represents a push operation result.
class PushOperationResult with EquatableMixin {
  /// The operation UUID.
  final String operationUuid;

  /// The TOTP UUID.
  final String totpUuid;

  /// The error code.
  final String? errorCode;

  /// The error details.
  final String? errorDetails;

  /// The operation creation date.
  final DateTime createdAt;

  /// Creates a new push operation result instance.
  PushOperationResult._({
    required this.operationUuid,
    required this.totpUuid,
    this.errorCode,
    this.errorDetails,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  /// Creates a new push operation result instance, returning a [PushOperationError] if [errorCode] is not null.
  factory PushOperationResult({
    required String operationUuid,
    required String totpUuid,
    String? errorCode,
    String? errorDetails,
    DateTime? createdAt,
  }) => errorCode == null
      ? PushOperationResult._(
          operationUuid: operationUuid,
          totpUuid: totpUuid,
          errorCode: errorCode,
          errorDetails: errorDetails,
          createdAt: createdAt,
        )
      : PushOperationError._(
          operationUuid: operationUuid,
          totpUuid: totpUuid,
          errorCode: errorCode,
          errorDetails: errorDetails,
          createdAt: createdAt,
        );

  /// Creates a new push operation result instance from a JSON map.
  PushOperationResult.fromJson(Map<String, dynamic> json)
    : this._(
        operationUuid: json['operationUuid'],
        totpUuid: json['totpUuid'],
        errorCode: json['errorCode'],
        errorDetails: json['errorDetails'],
      );

  /// Converts the push operation result to a JSON map.
  PushOperationErrorKind? get errorKind => success
      ? null
      : PushOperationErrorKind.values.firstWhere(
          (value) => value.name == errorCode,
          orElse: () => PushOperationErrorKind.genericError,
        );

  /// Whether the operation succeeded.
  bool get success => errorCode == null;

  @override
  List<Object?> get props => [
    operationUuid,
    totpUuid,
    errorCode,
    errorDetails,
    createdAt,
  ];
}

/// Represents a push operation error.
class PushOperationError extends PushOperationResult {
  /// Creates a new push operation error instance.
  PushOperationError._({
    required super.operationUuid,
    required super.totpUuid,
    required String super.errorCode,
    required super.errorDetails,
    super.createdAt,
  }) : super._();

  @override
  String get errorCode => super.errorCode!;

  @override
  PushOperationErrorKind get errorKind => super.errorKind!;
}

/// Represents a push operation error kind.
enum PushOperationErrorKind {
  /// The operation UUID is invalid.
  invalidUuid(isPermanent: true),

  /// The operation payload is invalid.
  invalidTotp(isPermanent: true),

  /// The update timestamp is invalid.
  invalidUpdateTimestamp(isPermanent: true),

  /// The TOTP has been deleted more recently.
  deletedTotp(isPermanent: true),

  /// The delete timestamp is invalid.
  invalidDeleteTimestamp(isPermanent: true),

  /// The maximum operations count has been exceeded.
  maxOperationsCountExceeded,

  /// The max TOTPs count has been exceeded.
  tooManyTotps,

  /// Any other error occurred.
  genericError
  ;

  /// Whether the error is permanent.
  final bool isPermanent;

  /// Creates a new push operation error kind instance.
  const PushOperationErrorKind({
    this.isPermanent = false,
  });

  /// Returns the localized message.
  String get localizedMessage => switch (this) {
    invalidUuid => translations.error.pushOperationErrorKind.invalidUuid,
    invalidTotp => translations.error.pushOperationErrorKind.invalidTotp,
    invalidUpdateTimestamp => translations.error.pushOperationErrorKind.invalidUpdateTimestamp,
    deletedTotp => translations.error.pushOperationErrorKind.deletedTotp,
    invalidDeleteTimestamp => translations.error.pushOperationErrorKind.invalidDeleteTimestamp,
    maxOperationsCountExceeded => translations.error.pushOperationErrorKind.maxOperationsCountExceeded,
    tooManyTotps => translations.error.pushOperationErrorKind.tooManyTotps,
    genericError => translations.error.pushOperationErrorKind.genericError,
  };
}
