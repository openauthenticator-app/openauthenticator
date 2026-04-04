/// An error that can be displayed to the user.
class LocalizableException implements Exception {
  /// The localized error message.
  final String localizedErrorMessage;

  /// Creates a new app error instance.
  const LocalizableException({
    required this.localizedErrorMessage,
  });

  @override
  String toString() => 'An error occurred : $runtimeType. Localized error message : $localizedErrorMessage.';
}
