import 'package:qent/core/services/api_client.dart';
import 'package:qent/features/auth/domain/models/auth_user.dart';

/// REST API datasource replacing Firebase Auth + Firestore user profiles.
class ApiAuthDataSource {
  final ApiClient _client;

  ApiAuthDataSource({ApiClient? client}) : _client = client ?? ApiClient();

  /// Sign in with email and password. Returns AuthUser with JWT token.
  Future<AuthUser> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    final response = await _client.post(
      '/auth/signin',
      body: {'email': email, 'password': password},
      auth: false,
    );

    if (!response.isSuccess) {
      throw Exception(response.errorMessage);
    }

    final data = response.body;
    await _client.setToken(data['token']);

    return AuthUser.fromJson(data['user']);
  }

  /// Sign up with email and password. Returns AuthUser with JWT token.
  Future<AuthUser> signUpWithEmailAndPassword({
    required String email,
    required String password,
    required String fullName,
    required String country,
  }) async {
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

    if (!response.isSuccess) {
      throw Exception(response.errorMessage);
    }

    final data = response.body;
    await _client.setToken(data['token']);

    return AuthUser.fromJson(data['user']);
  }

  /// Get current user profile from the backend.
  Future<AuthUser?> getProfile() async {
    if (!_client.isAuthenticated) return null;

    final response = await _client.get('/auth/profile');
    if (!response.isSuccess) return null;

    return AuthUser.fromJson(response.body);
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

    final response = await _client.put('/auth/profile', body: body);
    if (!response.isSuccess) {
      throw Exception(response.errorMessage);
    }
  }

  /// Submit identity verification documents.
  Future<void> verifyIdentity({
    required String driversLicenseUrl,
    String? idCardUrl,
  }) async {
    final response = await _client.post(
      '/auth/verify-identity',
      body: {
        'drivers_license_url': driversLicenseUrl,
        'id_card_url': idCardUrl,
      },
    );

    if (!response.isSuccess) {
      throw Exception(response.errorMessage);
    }
  }

  /// Sign out (clear local token).
  Future<void> signOut() async {
    await _client.clearToken();
  }

  /// Check if user is currently authenticated.
  bool get isAuthenticated => _client.isAuthenticated;
}
