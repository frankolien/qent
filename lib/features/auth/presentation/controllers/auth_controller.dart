import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qent/features/auth/presentation/providers/auth_providers.dart';
import 'package:qent/features/auth/presentation/controllers/auth_state.dart';

class AuthController extends Notifier<AuthState> {
  @override
  AuthState build() {
    // Schedule session restore after state is initialized
    Future.microtask(() => _tryRestoreSession());
    return AuthState.initial();
  }

  Future<void> _tryRestoreSession() async {
    final dataSource = ref.read(apiAuthDataSourceProvider);
    if (dataSource.isAuthenticated) {
      state = state.copyWith(isLoading: true);
      try {
        final user = await dataSource.getProfile();
        if (user != null) {
          state = state.copyWith(isLoading: false, user: user);
        } else {
          await dataSource.signOut();
          state = state.copyWith(isLoading: false);
        }
      } catch (e) {
        state = state.copyWith(isLoading: false);
      }
    }
  }

  Future<void> signIn({required String email, required String password}) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final dataSource = ref.read(apiAuthDataSourceProvider);
      final user = await dataSource.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      state = state.copyWith(isLoading: false, user: user);
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
      final dataSource = ref.read(apiAuthDataSourceProvider);
      final user = await dataSource.signUpWithEmailAndPassword(
        email: email,
        password: password,
        fullName: fullName,
        country: country,
      );
      state = state.copyWith(isLoading: false, user: user);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  Future<void> signOut() async {
    state = state.copyWith(isLoading: true);
    try {
      final dataSource = ref.read(apiAuthDataSourceProvider);
      await dataSource.signOut();
      state = state.copyWith(isLoading: false, clearUser: true);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }
}
