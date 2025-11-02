import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qent/core/services/online_status_service.dart';
import 'package:qent/features/auth/presentation/providers/auth_providers.dart';
import 'package:qent/features/auth/presentation/controllers/auth_state.dart';

class AuthController extends Notifier<AuthState> {
  @override
  AuthState build() => AuthState.initial();

  Future<void> signIn({required String email, required String password}) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final user = await ref.read(signInWithEmailAndPasswordProvider)(
        email: email,
        password: password,
      );
      state = state.copyWith(isLoading: false, user: user);
      // Set user as online when they sign in
      if (user != null) {
        OnlineStatusService().setOnline();
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  Future<void> signUp({
    required String email,
    required String password,
    required String fullName,
    required String country,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final user = await ref.read(signUpWithEmailAndPasswordProvider)(
        email: email,
        password: password,
        fullName: fullName,
        country: country,
      );
      state = state.copyWith(isLoading: false, user: user);
      // Set user as online when they sign up
      if (user != null) {
        OnlineStatusService().setOnline();
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  Future<void> sendResetPassword({required String email}) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      await ref.read(sendPasswordResetEmailProvider)(email: email);
      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  Future<void> signOut() async {
    state = state.copyWith(isLoading: true);
    try {
      // Set user as offline before signing out
      OnlineStatusService().setOffline();
      final repository = ref.read(authRepositoryProvider);
      await repository.signOut();
      state = state.copyWith(isLoading: false, user: null);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }
}


