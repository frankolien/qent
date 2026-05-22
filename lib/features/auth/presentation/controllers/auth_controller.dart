import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:qent/core/utils/friendly_error.dart';
import 'package:qent/features/auth/domain/models/auth_user.dart';
import 'package:qent/features/auth/presentation/providers/auth_providers.dart';
import 'package:qent/features/auth/presentation/controllers/auth_state.dart';
import 'package:qent/features/home/presentation/providers/car_providers.dart';
import 'package:qent/core/services/websocket_service.dart';
import 'package:qent/features/chat/data/datasources/chat_cache.dart';

/// Google Web client ID. Must be in backend's GOOGLE_CLIENT_IDS allowlist.
const _googleServerClientId =
    '482124898845-mgk3ufab64iv2nccmto8622t94u5c1hi.apps.googleusercontent.com';

const _cachedUserPrefsKey = 'auth.cached_user_v1';

class AuthController extends Notifier<AuthState> {
  @override
  AuthState build() {
    Future.microtask(_tryRestoreSession);
    return AuthState.initial().copyWith(isLoading: true);
  }

  Future<void> _tryRestoreSession() async {
    final dataSource = ref.read(apiAuthDataSourceProvider);
    if (!dataSource.isAuthenticated) {
      state = state.copyWith(isLoading: false);
      return;
    }

    final cached = await _loadCachedUser();
    if (cached != null) {
      state = state.copyWith(isLoading: false, user: cached);
      ref.read(wsServiceProvider).connect();
    } else {
      state = state.copyWith(isLoading: true);
    }

    unawaited(_refreshSessionInBackground());
  }

  Future<void> _refreshSessionInBackground() async {
    final dataSource = ref.read(apiAuthDataSourceProvider);
    try {
      final user = await dataSource.getProfile().timeout(
            const Duration(seconds: 10),
          );
      if (user == null) {
        await dataSource.signOut();
        await _clearCachedUser();
        state = state.copyWith(isLoading: false, clearUser: true);
        return;
      }
      await _cacheUser(user);
      state = state.copyWith(isLoading: false, user: user);
      ref.read(wsServiceProvider).connect();
    } on TimeoutException {
      debugPrint('[Qent Auth] background refresh timed out');
      state = state.copyWith(isLoading: false);
    } catch (e) {
      debugPrint('[Qent Auth] background refresh failed: $e');
      // Keep cached user on transient errors; only sign out if we never had one.
      if (state.user == null) {
        await dataSource.signOut();
        await _clearCachedUser();
        state = state.copyWith(isLoading: false, clearUser: true);
      } else {
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
      await _cacheUser(user);
      state = state.copyWith(isLoading: false, user: user);
      ref.read(wsServiceProvider).connect();
    } catch (e, st) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: friendlyError(e, tag: 'Auth/signIn', stack: st),
      );
    }
  }

  /// Apple only returns givenName/familyName on the first authorization ever.
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
      await _cacheUser(user);
      state = state.copyWith(isLoading: false, user: user);
      ref.read(wsServiceProvider).connect();
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) {
        state = state.copyWith(isLoading: false);
      } else {
        state = state.copyWith(isLoading: false, errorMessage: e.message);
      }
    } catch (e, st) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: friendlyError(e, tag: 'Auth/apple', stack: st),
      );
    }
  }

  Future<void> signInWithGoogle() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final googleSignIn = GoogleSignIn(
        serverClientId: _googleServerClientId,
        scopes: ['email', 'profile'],
      );

      await googleSignIn.signOut();

      final account = await googleSignIn.signIn();
      if (account == null) {
        state = state.copyWith(isLoading: false);
        return;
      }

      final auth = await account.authentication;
      final idToken = auth.idToken;
      if (idToken == null || idToken.isEmpty) {
        throw Exception('Google did not return an ID token');
      }

      final dataSource = ref.read(apiAuthDataSourceProvider);
      final user = await dataSource.signInWithGoogle(
        idToken: idToken,
        fullName: account.displayName,
        email: account.email,
      );
      await _cacheUser(user);
      state = state.copyWith(isLoading: false, user: user);
      ref.read(wsServiceProvider).connect();
    } catch (e, st) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: friendlyError(e, tag: 'Auth/google', stack: st),
      );
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
      await _cacheUser(user);
      state = state.copyWith(isLoading: false, user: user);
      ref.read(wsServiceProvider).connect();
    } catch (e, st) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: friendlyError(e, tag: 'Auth/signUp', stack: st),
      );
    }
  }

  Future<void> refreshProfile() async {
    final dataSource = ref.read(apiAuthDataSourceProvider);
    try {
      final user = await dataSource.getProfile();
      if (user != null) {
        await _cacheUser(user);
        state = state.copyWith(user: user);
      }
    } catch (e) {
      debugPrint('[AuthController] refreshProfile failed: $e');
    }
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
      await _clearCachedUser();
      ref.read(wsServiceProvider).disconnect();

      ref.invalidate(carsProvider);
      ref.invalidate(favoriteCarsProvider);
      ref.invalidate(favoriteIdsProvider);
      unawaited(ref.read(chatCacheProvider).clearAll());

      state = state.copyWith(isLoading: false, clearUser: true);
    } catch (e, st) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: friendlyError(e, tag: 'Auth/signOut', stack: st),
      );
    }
  }

  Future<AuthUser?> _loadCachedUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cachedUserPrefsKey);
      if (raw == null || raw.isEmpty) return null;
      return AuthUser.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (e) {
      debugPrint('[Qent Auth] cache load failed: $e');
      return null;
    }
  }

  Future<void> _cacheUser(AuthUser user) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cachedUserPrefsKey, jsonEncode(user.toJson()));
    } catch (e) {
      debugPrint('[Qent Auth] cache write failed: $e');
    }
  }

  Future<void> _clearCachedUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_cachedUserPrefsKey);
    } catch (e) {
      debugPrint('[Qent Auth] cache clear failed: $e');
    }
  }
}
