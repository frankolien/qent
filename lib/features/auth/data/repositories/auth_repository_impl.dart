import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:qent/features/auth/data/datasources/firebase_auth_datasource.dart';
import 'package:qent/features/auth/domain/repositories/auth_repository.dart';

class AuthRepositoryImpl implements AuthRepository {
  final FirebaseAuthDataSource _dataSource;
  AuthRepositoryImpl(this._dataSource);

  @override
  Future<fb.User?> signInWithEmailAndPassword({required String email, required String password}) {
    return _dataSource.signInWithEmailAndPassword(email: email, password: password);
  }

  @override
  Future<void> sendPasswordResetEmail({required String email}) {
    return _dataSource.sendPasswordResetEmail(email: email);
  }

  @override
  Future<void> signOut() => _dataSource.signOut();

  @override
  Stream<fb.User?> authStateChanges() => _dataSource.authStateChanges();
}


