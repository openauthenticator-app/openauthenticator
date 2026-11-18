/// Allows to interact with the app unlock.
mixin AppUnlockInteraction {
  /// Prompts the user for a master password.
  Future<String?> promptMasterPassword({String? message});

  /// Whether the app can be unlocked.
  bool get canInteract;
}
