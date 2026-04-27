import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:qent/core/services/api_client.dart';
import 'package:qent/core/services/notification_service.dart';
import 'package:qent/features/auth/domain/models/auth_user.dart';

/// REST API datasource replacing Firebase Auth + Firestore user profiles.
class ApiAuthDataSource {
  final ApiClient _client;

  ApiAuthDataSource({ApiClient? client}) : _client = client ?? ApiClient();

  void _log(String message) {
    if (kDebugMode) debugPrint('[Qent Auth] $message');
  }

  /// Sign in with email and password. Returns AuthUser with JWT token.
  Future<AuthUser> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    _log('> Sign in: $email');
    final sw = Stopwatch()..start();

    final response = await _client.post(
      '/auth/signin',
      body: {'email': email, 'password': password},
      auth: false,
    );
    sw.stop();

    if (!response.isSuccess) {
      _log('FAIL: Sign in failed (${sw.elapsedMilliseconds}ms): ${response.errorMessage}');
      throw Exception(response.errorMessage);
    }

    final data = response.body;
    await _client.setToken(data['token']);
    final user = AuthUser.fromJson(data['user']);
    unawaited(NotificationService().registerCurrentDeviceWithBackend());
    _log('OK: Signed in as ${user.email} | uid: ${user.uid} (${sw.elapsedMilliseconds}ms)');

    return user;
  }

  /// Sign in with Apple. The [identityToken] is the JWT Apple returns after
  /// a successful authorization; the backend verifies it against Apple's JWKS.
  ///
  /// [fullName] and [email] are only populated on the user's FIRST authorization
  /// ever for this app — Apple never sends them again. Pass them through so the
  /// backend can save them to a newly created account.
  Future<AuthUser> signInWithApple({
    required String identityToken,
    String? fullName,
    String? email,
  }) async {
    _log('> Sign in with Apple');
    final sw = Stopwatch()..start();

    final response = await _client.post(
      '/auth/signin/apple',
      body: {
        'identity_token': identityToken,
        if (fullName != null && fullName.isNotEmpty) 'full_name': fullName,
        if (email != null && email.isNotEmpty) 'email': email,
      },
      auth: false,
    );
    sw.stop();

    if (!response.isSuccess) {
      _log('FAIL: Apple sign in failed (${sw.elapsedMilliseconds}ms): ${response.errorMessage}');
      throw Exception(response.errorMessage);
    }

    final data = response.body;
    await _client.setToken(data['token']);
    final user = AuthUser.fromJson(data['user']);
    unawaited(NotificationService().registerCurrentDeviceWithBackend());
    _log('OK: Signed in with Apple as ${user.email} | uid: ${user.uid} (${sw.elapsedMilliseconds}ms)');

    return user;
  }

  /// Sign up with email and password. Returns AuthUser with JWT token.
  Future<AuthUser> signUpWithEmailAndPassword({
    required String email,
    required String password,
    required String fullName,
    required String country,
  }) async {
    _log('> Sign up: $email | name: $fullName | country: $country');
    final sw = Stopwatch()..start();

    final response = await _client.post(
      '/auth/signup',
      body: {
        'email': email,
        'password': password,
        'full_name': fullName,
        'country': country,
        'role': 'Renter',
      },
      auth: false,
    );
    sw.stop();

    if (!response.isSuccess) {
      _log('FAIL: Sign up failed (${sw.elapsedMilliseconds}ms): ${response.errorMessage}');
      throw Exception(response.errorMessage);
    }

    final data = response.body;
    await _client.setToken(data['token']);
    final user = AuthUser.fromJson(data['user']);
    unawaited(NotificationService().registerCurrentDeviceWithBackend());
    _log('OK: Signed up as ${user.email} | uid: ${user.uid} (${sw.elapsedMilliseconds}ms)');

    return user;
  }

  /// Get current user profile from the backend.
  Future<AuthUser?> getProfile() async {
    if (!_client.isAuthenticated) {
      _log('WARN: getProfile called without auth token');
      return null;
    }

    _log('> Fetching profile');
    final sw = Stopwatch()..start();
    final response = await _client.get('/profile');
    sw.stop();

    if (!response.isSuccess) {
      _log('FAIL: Profile fetch failed (${sw.elapsedMilliseconds}ms): ${response.errorMessage}');
      return null;
    }

    final user = AuthUser.fromJson(response.body);
    _log('OK: Profile loaded: ${user.email} | role: ${response.body['role'] ?? 'unknown'} (${sw.elapsedMilliseconds}ms)');
    return user;
  }

  /// Update user profile.
  Future<void> updateProfile({
    String? fullName,
    String? phone,
    String? profilePhotoUrl,
  }) async {
    final body = <String, dynamic>{};
    if (fullName != null) body['full_name'] = fullName;
    if (phone != null) body['phone'] = phone;
    if (profilePhotoUrl != null) body['profile_photo_url'] = profilePhotoUrl;

    _log('> Updating profile: ${body.keys.join(', ')}');
    final sw = Stopwatch()..start();
    final response = await _client.put('/profile', body: body);
    sw.stop();

    if (!response.isSuccess) {
      _log('FAIL: Profile update failed (${sw.elapsedMilliseconds}ms): ${response.errorMessage}');
      throw Exception(response.errorMessage);
    }
    _log('OK: Profile updated (${sw.elapsedMilliseconds}ms)');
  }

  /// Submit identity verification documents.
  Future<void> verifyIdentity({
    required String driversLicenseUrl,
    String? idCardUrl,
  }) async {
    _log('> Submitting identity verification');
    final sw = Stopwatch()..start();
    final response = await _client.post(
      '/profile/verify-identity',
      body: {
        'drivers_license_url': driversLicenseUrl,
        'id_card_url': idCardUrl,
      },
    );
    sw.stop();

    if (!response.isSuccess) {
      _log('FAIL: Identity verification failed (${sw.elapsedMilliseconds}ms): ${response.errorMessage}');
      throw Exception(response.errorMessage);
    }
    _log('OK: Identity verification submitted (${sw.elapsedMilliseconds}ms)');
  }

  /// Sign out (clear local token).
  Future<void> signOut() async {
    _log('> Signing out');
    await NotificationService().unregisterCurrentDeviceFromBackend();
    await _client.clearToken();
    _log('OK: Signed out');
  }

  /// Check if user is currently authenticated.
  bool get isAuthenticated => _client.isAuthenticated;
}
