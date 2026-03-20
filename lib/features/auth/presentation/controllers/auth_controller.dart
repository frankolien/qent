import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qent/features/auth/presentation/providers/auth_providers.dart';
import 'package:qent/features/auth/presentation/controllers/auth_state.dart';
import 'package:qent/features/home/presentation/providers/car_providers.dart';
import 'package:qent/core/services/websocket_service.dart';

class AuthController extends Notifier<AuthState> {
  @override
  AuthState build() {
    // Start with loading = true so splash screen waits for us
    Future.microtask(() => _tryRestoreSession());
    return AuthState.initial().copyWith(isLoading: true);
  }

  Future<void> _tryRestoreSession() async {
    final dataSource = ref.read(apiAuthDataSourceProvider);
    if (dataSource.isAuthenticated) {
      try {
        final user = await dataSource.getProfile();
        if (user != null) {
          state = state.copyWith(isLoading: false, user: user);
          ref.read(wsServiceProvider).connect();
          return;
        } else {
          await dataSource.signOut();
        }
      } catch (e) {
        // Token might be expired, clear it
        await dataSource.signOut();
      }
    }
    state = state.copyWith(isLoading: false);
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
      ref.read(wsServiceProvider).connect();
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
      ref.read(wsServiceProvider).connect();
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  Future<void> refreshProfile() async {
    final dataSource = ref.read(apiAuthDataSourceProvider);
    try {
      final user = await dataSource.getProfile();
      if (user != null) {
        state = state.copyWith(user: user);
      }
    } catch (_) {}
  }

  Future<void> signOut() async {
    state = state.copyWith(isLoading: true);
    try {
      final dataSource = ref.read(apiAuthDataSourceProvider);
      await dataSource.signOut();
      ref.read(wsServiceProvider).disconnect();

      // Clear all cached data from the previous user
      ref.invalidate(carsProvider);
      ref.invalidate(favoriteCarsProvider);
      ref.invalidate(favoriteIdsProvider);

      state = state.copyWith(isLoading: false, clearUser: true);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }
}
