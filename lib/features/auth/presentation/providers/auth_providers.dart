import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qent/features/auth/data/datasources/firebase_auth_datasource.dart';
import 'package:qent/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:qent/features/auth/domain/repositories/auth_repository.dart';
import 'package:qent/features/auth/domain/usecases/send_password_reset_email.dart';
import 'package:qent/features/auth/domain/usecases/sign_in_with_email_password.dart';
import 'package:qent/features/auth/presentation/controllers/auth_controller.dart';
import 'package:qent/features/auth/presentation/controllers/auth_state.dart';

// Low-level FirebaseAuth instance (override in tests if needed)
final firebaseAuthProvider = Provider<fb.FirebaseAuth>((ref) => fb.FirebaseAuth.instance);

// Data source and repository bindings
final firebaseAuthDataSourceProvider = Provider<FirebaseAuthDataSource>((ref) {
  final auth = ref.watch(firebaseAuthProvider);
  return FirebaseAuthDataSource(auth: auth);
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final ds = ref.watch(firebaseAuthDataSourceProvider);
  return AuthRepositoryImpl(ds);
});

// Use cases
final signInWithEmailAndPasswordProvider = Provider<SignInWithEmailAndPassword>((ref) {
  final repo = ref.watch(authRepositoryProvider);
  return SignInWithEmailAndPassword(repo);
});

final sendPasswordResetEmailProvider = Provider<SendPasswordResetEmail>((ref) {
  final repo = ref.watch(authRepositoryProvider);
  return SendPasswordResetEmail(repo);
});

// Controller
final authControllerProvider = NotifierProvider<AuthController, AuthState>(AuthController.new);


