import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qent/core/services/online_status_service.dart';
import 'package:qent/features/auth/presentation/providers/auth_providers.dart';
import 'package:qent/features/auth/presentation/controllers/auth_state.dart';

class AuthController extends Notifier<AuthState> {
  StreamSubscription? _authStateSubscription;

  @override
  AuthState build() {
    // Initialize with current user if available
    final currentUser = ref.read(firebaseAuthProvider).currentUser;
    
    // Only set up listener if subscription doesn't exist (avoid re-setup on hot restart)
    if (_authStateSubscription == null) {
      // Listen to auth state changes
      _authStateSubscription = ref.read(firebaseAuthProvider).authStateChanges().listen((user) {
        if (user != null && state.user?.uid != user.uid) {
          // User logged in or switched accounts
          state = state.copyWith(user: user, isLoading: false);
          OnlineStatusService().setOnline();
        } else if (user == null && state.user != null) {
          // User logged out
          state = state.copyWith(user: null, isLoading: false);
          OnlineStatusService().setOffline();
        }
      });

      // Cleanup subscription when provider is disposed
      ref.onDispose(() {
        _authStateSubscription?.cancel();
        _authStateSubscription = null;
      });
    }

    // Return initial state with current user
    return AuthState.initial().copyWith(user: currentUser);
  }

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


