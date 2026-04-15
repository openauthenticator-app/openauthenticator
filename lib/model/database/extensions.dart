part of 'database.dart';

/// Contains some useful methods for the generated [_DriftTotp] class.
extension _ToOpenAuthenticatorTotp on _DriftTotp {
  /// Converts this instance to a [Totp].
  Totp get asTotp => Totp(
    uuid: uuid,
    encryptedData: EncryptedData(
      encryptedSecret: secret,
      encryptedLabel: label,
      encryptedIssuer: issuer,
      encryptedImageUrl: imageUrl,
      encryptionSalt: Salt.fromRawValue(value: encryptionSalt),
    ),
    algorithm: algorithm,
    digits: digits,
    validity: validity,
    updatedAt: updatedAt,
  );
}

/// Contains some useful methods for the generated [_DriftBackendPushOperation] class.
extension _ToOpenAuthenticatorBackendPushOperation on _DriftBackendPushOperation {
  /// Converts this instance to a [PushOperation].
  PushOperation get asBackendPushOperation => switch (kind) {
    PushOperationKind.set => SetTotpsPushOperation.raw(
      uuid: uuid,
      payload: jsonDecode(jsonPayload),
      createdAt: createdAt,
    ),
    PushOperationKind.delete => DeleteTotpsPushOperation.raw(
      uuid: uuid,
      payload: jsonDecode(jsonPayload).cast<String>(),
      createdAt: createdAt,
    ),
  };
}

/// Contains some useful methods for the generated [_DriftBackendPushOperationError] class.
extension _ToOpenAuthenticatorBackendPushOperationError on _DriftBackendPushOperationError {
  /// Converts this instance to a [PushOperationResult].
  PushOperationResult get asBackendPushOperationResult => PushOperationResult(
    operationUuid: operationUuid,
    totpUuid: totpUuid,
    errorCode: errorKind.name,
    errorDetails: errorDetails,
    createdAt: createdAt,
  );
}

/// Contains some useful methods to use [Totp] with Drift.
extension _ToDriftTotp on Totp {
  /// Converts this instance to a Drift generated [_DriftTotp].
  _DriftTotp get asDriftTotp => _DriftTotp(
    uuid: uuid,
    algorithm: algorithm,
    digits: digits,
    validity: validity,
    secret: encryptedData.encryptedSecret,
    label: encryptedData.encryptedLabel,
    issuer: encryptedData.encryptedIssuer,
    imageUrl: encryptedData.encryptedImageUrl,
    encryptionSalt: encryptedData.encryptionSalt.value,
    updatedAt: updatedAt,
  );
}

/// Contains some useful methods to use [PushOperation] with Drift.
extension _ToDriftBackendPushOperation on PushOperation {
  /// Converts this instance to a Drift generated [_DriftBackendPushOperation].
  _DriftBackendPushOperation get asDriftBackendPushOperation => _DriftBackendPushOperation(
    uuid: uuid,
    kind: switch (this) {
      SetTotpsPushOperation() => PushOperationKind.set,
      DeleteTotpsPushOperation() => PushOperationKind.delete,
    },
    jsonPayload: jsonEncode(payload),
    createdAt: createdAt,
  );
}

/// Contains some useful methods to use [PushOperationResult] with Drift.
extension _ToDriftBackendPushOperationError on PushOperationResult {
  /// Converts this instance to a Drift generated [_DriftBackendPushOperationError].
  _DriftBackendPushOperationError get asDriftBackendPushOperationError {
    assert(errorKind != null, '`errorKind` must not be null.');
    return _DriftBackendPushOperationError(
      operationUuid: operationUuid,
      totpUuid: totpUuid,
      errorKind: errorKind!,
      errorDetails: errorDetails,
      createdAt: createdAt,
    );
  }
}
