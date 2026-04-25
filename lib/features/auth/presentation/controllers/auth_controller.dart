import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
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

  /// Launch the native Apple Sign-In flow and exchange the returned
  /// identityToken for our own JWT via the backend.
  ///
  /// Apple only returns the user's given/family name on the *first* sign-in
  /// ever — we forward it to the backend so it lands on the new account.
  Future<void> signInWithApple() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      final idToken = credential.identityToken;
      if (idToken == null || idToken.isEmpty) {
        throw Exception('Apple did not return an identity token');
      }

      final fullName = [credential.givenName, credential.familyName]
          .whereType<String>()
          .where((s) => s.isNotEmpty)
          .join(' ');

      final dataSource = ref.read(apiAuthDataSourceProvider);
      final user = await dataSource.signInWithApple(
        identityToken: idToken,
        fullName: fullName.isEmpty ? null : fullName,
        email: credential.email,
      );
      state = state.copyWith(isLoading: false, user: user);
      ref.read(wsServiceProvider).connect();
    } on SignInWithAppleAuthorizationException catch (e) {
      // User-cancelled should be silent, not an error banner.
      if (e.code == AuthorizationErrorCode.canceled) {
        state = state.copyWith(isLoading: false);
      } else {
        state = state.copyWith(isLoading: false, errorMessage: e.message);
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

  void clearError() {
    if (state.errorMessage != null) {
      state = state.copyWith(errorMessage: null);
    }
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
