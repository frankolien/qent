import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:qent/core/services/online_status_service.dart';
import 'package:qent/features/auth/data/datasources/firebase_auth_datasource.dart';
import 'package:qent/features/auth/domain/models/user_profile.dart';
import 'package:qent/features/auth/domain/repositories/auth_repository.dart';
import 'package:qent/features/auth/domain/repositories/user_profile_repository.dart';

class AuthRepositoryImpl implements AuthRepository {
  final FirebaseAuthDataSource _dataSource;
  final UserProfileRepository _profileRepository;

  AuthRepositoryImpl(this._dataSource, this._profileRepository);

  @override
  Future<fb.User?> signInWithEmailAndPassword({required String email, required String password}) {
    return _dataSource.signInWithEmailAndPassword(email: email, password: password);
  }

  @override
  Future<fb.User?> signUpWithEmailAndPassword({
    required String email,
    required String password,
    required String fullName,
    required String country,
  }) async {
    // Create auth account
    final user = await _dataSource.signUpWithEmailAndPassword(
      email: email,
      password: password,
    );

    // Create user profile in Firestore
    if (user != null) {
      final profile = UserProfile(
        uid: user.uid,
        email: email,
        fullName: fullName,
        country: country,
        createdAt: DateTime.now(),
      );
      await _profileRepository.createUserProfile(profile);
      
      // Set user as online when they sign up
      OnlineStatusService().setOnline();
    }

    return user;
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


