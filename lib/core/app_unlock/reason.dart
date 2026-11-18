/// Configures the unlock reason for [UnlockChallenge]s.
enum UnlockReason {
  /// The user tries the unlock challenge for opening the app.
  openApp,

  /// The user tries to do a sensible action.
  sensibleAction,

  /// The user tries the unlock challenge for enabling the current method.
  enable,

  /// The user tries the unlock challenge for disabling the current method.
  disable,
}
