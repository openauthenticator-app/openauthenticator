import 'package:open_authenticator/model/migrator/firebase_auth/firebase_auth.dart';

/// A Firebase Auth implementation that does nothing.
class FirebaseAuthSub extends FirebaseAuth {
  @override
  User? get currentUser => null;

  @override
  Future<void> deleteUser() async {}

  @override
  Future<void> signOut() async {}

  @override
  Future<SignInResult> unlinkFrom(String providerId) => Future.value(const SignInResult());

  @override
  Stream<User?> get userChanges => Stream.value(currentUser);
}
