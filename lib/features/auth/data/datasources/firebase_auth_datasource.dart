import 'package:firebase_auth/firebase_auth.dart' as fb;

/// Thin wrapper around FirebaseAuth to allow testability and separation.
class FirebaseAuthDataSource {
  final fb.FirebaseAuth _auth;
  FirebaseAuthDataSource({fb.FirebaseAuth? auth}) : _auth = auth ?? fb.FirebaseAuth.instance;

  Future<fb.User?> signInWithEmailAndPassword({required String email, required String password}) async {
    final credential = await _auth.signInWithEmailAndPassword(email: email, password: password);
    return credential.user;
  }

  Future<void> sendPasswordResetEmail({required String email}) {
    return _auth.sendPasswordResetEmail(email: email);
  }

  Future<void> signOut() => _auth.signOut();

  Stream<fb.User?> authStateChanges() => _auth.authStateChanges();
}


