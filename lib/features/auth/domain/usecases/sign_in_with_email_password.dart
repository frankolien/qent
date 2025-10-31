import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:qent/features/auth/domain/repositories/auth_repository.dart';

class SignInWithEmailAndPassword {
  final AuthRepository _repository;
  const SignInWithEmailAndPassword(this._repository);

  Future<fb.User?> call({required String email, required String password}) {
    return _repository.signInWithEmailAndPassword(email: email, password: password);
  }
}


