import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:qent/features/auth/domain/repositories/auth_repository.dart';

class SignUpWithEmailAndPassword {
  final AuthRepository _repository;
  const SignUpWithEmailAndPassword(this._repository);

  Future<fb.User?> call({
    required String email,
    required String password,
    required String fullName,
    required String country,
  }) {
    return _repository.signUpWithEmailAndPassword(
      email: email,
      password: password,
      fullName: fullName,
      country: country,
    );
  }
}

