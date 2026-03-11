import 'package:flutter/foundation.dart';
import 'package:qent/core/services/api_client.dart';

/// Service for email verification via the Rust backend.
/// The backend handles code generation, storage in PostgreSQL, and email
/// delivery via Resend — keeping the API key server-side.
class EmailVerificationService {
  static final EmailVerificationService _instance =
      EmailVerificationService._internal();
  factory EmailVerificationService() => _instance;
  EmailVerificationService._internal();

  final ApiClient _api = ApiClient();

  /// Request the backend to generate and send a verification code.
  /// Returns true if the code was sent successfully.
  Future<bool> sendVerificationCode(String email) async {
    try {
      final resp = await _api.post(
        '/auth/send-code',
        body: {'email': email},
        auth: false,
      );

      if (resp.isSuccess) {
        if (kDebugMode) {
          print('Verification code sent to $email');
        }
        return true;
      } else {
        if (kDebugMode) {
          print('Failed to send code: ${resp.errorMessage}');
        }
        return false;
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error sending verification code: $e');
      }
      return false;
    }
  }

  /// Verify the code entered by the user against the backend.
  Future<bool> verifyCode(String email, String code) async {
    try {
      final resp = await _api.post(
        '/auth/verify-code',
        body: {'email': email, 'code': code},
        auth: false,
      );

      if (resp.isSuccess && resp.body['verified'] == true) {
        if (kDebugMode) {
          print('Email $email verified successfully');
        }
        return true;
      } else {
        if (kDebugMode) {
          print('Verification failed: ${resp.errorMessage}');
        }
        return false;
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error verifying code: $e');
      }
      return false;
    }
  }

  /// Resend verification code (just calls sendVerificationCode again).
  Future<bool> resendVerificationCode(String email) async {
    return sendVerificationCode(email);
  }
}
