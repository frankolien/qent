import 'package:firebase_auth/firebase_auth.dart' as fb;

/// Abstraction for authentication operations.
///
/// Keeps upper layers independent of Firebase-specific details.
abstract class AuthRepository {
  Future<fb.User?> signInWithEmailAndPassword({required String email, required String password});

  Future<void> sendPasswordResetEmail({required String email});

  Future<void> signOut();

  /// Emits the current user and any subsequent auth state changes.
  Stream<fb.User?> authStateChanges();
}


