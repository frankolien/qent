import 'package:qent/features/auth/domain/repositories/auth_repository.dart';

class SendPasswordResetEmail {
  final AuthRepository _repository;
  const SendPasswordResetEmail(this._repository);

  Future<void> call({required String email}) {
    return _repository.sendPasswordResetEmail(email: email);
  }
}


