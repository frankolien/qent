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

  void _log(String message) {
    if (kDebugMode) debugPrint('[Qent Email] $message');
  }

  /// Request the backend to generate and send a verification code.
  Future<bool> sendVerificationCode(String email) async {
    _log('> Sending verification code to $email');
    final sw = Stopwatch()..start();
    try {
      final resp = await _api.post(
        '/auth/send-code',
        body: {'email': email},
        auth: false,
      );
      sw.stop();

      if (resp.isSuccess) {
        _log('OK: Code sent to $email (${sw.elapsedMilliseconds}ms)');
        return true;
      } else {
        _log('FAIL: Failed to send code: ${resp.errorMessage} (${sw.elapsedMilliseconds}ms)');
        return false;
      }
    } catch (e) {
      sw.stop();
      _log('ERROR: Error sending code: $e (${sw.elapsedMilliseconds}ms)');
      return false;
    }
  }

  /// Verify the code entered by the user against the backend.
  Future<bool> verifyCode(String email, String code) async {
    _log('> Verifying code for $email (code: ${code.replaceRange(1, code.length - 1, '**')})');
    final sw = Stopwatch()..start();
    try {
      final resp = await _api.post(
        '/auth/verify-code',
        body: {'email': email, 'code': code},
        auth: false,
      );
      sw.stop();

      if (resp.isSuccess && resp.body['verified'] == true) {
        _log('OK: Email $email verified (${sw.elapsedMilliseconds}ms)');
        return true;
      } else {
        _log('FAIL: Verification failed: ${resp.errorMessage} (${sw.elapsedMilliseconds}ms)');
        return false;
      }
    } catch (e) {
      sw.stop();
      _log('ERROR: Error verifying code: $e (${sw.elapsedMilliseconds}ms)');
      return false;
    }
  }

  /// Resend verification code (just calls sendVerificationCode again).
  Future<bool> resendVerificationCode(String email) async {
    _log('> Resending verification code to $email');
    return sendVerificationCode(email);
  }
}
