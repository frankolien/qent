import 'dart:convert';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

/// Service for email verification using Resend
class EmailVerificationService {
  static final EmailVerificationService _instance = EmailVerificationService._internal();
  factory EmailVerificationService() => _instance;
  EmailVerificationService._internal();

  // Resend Configuration
  String get _apiKey => dotenv.env['RESEND_API_KEY'] ?? '';
  static const String _sender = 'Qent <noreply@qent.online>';
  static const String _resendApiUrl = 'https://api.resend.com/emails';

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const Duration _codeExpiry = Duration(minutes: 5);

  /// Generate a random 4-digit verification code
  String generateVerificationCode() {
    final random = Random();
    // Generate 4-digit code (1000 to 9999)
    return (1000 + random.nextInt(8999)).toString();
  }

  /// Send verification code via Resend
  Future<bool> sendVerificationCode(String email, String code) async {
    try {
      if (kDebugMode) {
        print('📧 Sending verification email to: $email');
        print('📧 Using Resend API');
      }

      final url = Uri.parse(_resendApiUrl);

      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $_apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'from': _sender,
          'to': email,
          'subject': 'Your Qent Verification Code',
          'html': _buildEmailTemplate(code),
        }),
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          if (kDebugMode) {
            print('Resend request timed out');
          }
          throw Exception('Request timeout');
        },
      );

      if (kDebugMode) {
        print('Resend response status: ${response.statusCode}');
        print('Response body: ${response.body}');
      }

      if (response.statusCode == 200) {
        if (kDebugMode) {
          print('Verification code sent successfully to $email');
        }
        return true;
      } else {
        final responseBody = response.body;
        if (kDebugMode) {
          print('Failed to send email. Status: ${response.statusCode}');
          print('Response: $responseBody');
        }
        
        // Check for Resend domain verification error
        if (response.statusCode == 403 && responseBody.contains('verify a domain')) {
          if (kDebugMode) {
            print('Resend domain not verified. Please verify your domain at resend.com/domains');
            print('Currently, Resend sandbox only allows sending to verified email addresses');
          }
        }
        
        return false;
      }
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('Error sending verification email: $e');
        print('Stack trace: $stackTrace');
      }
      return false;
    }
  }

  /// Build HTML email template for verification code
  String _buildEmailTemplate(String code) {
    return '''
    <!DOCTYPE html>
    <html>
    <head>
      <meta charset="UTF-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <title>Verification Code</title>
      <style>
        body {
          font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, Cantarell, sans-serif;
          line-height: 1.6;
          color: #333;
          max-width: 600px;
          margin: 0 auto;
          padding: 20px;
          background-color: #f5f5f5;
        }
        .container {
          background-color: #ffffff;
          border-radius: 12px;
          padding: 40px;
          box-shadow: 0 2px 4px rgba(0,0,0,0.1);
        }
        .logo {
          text-align: center;
          margin-bottom: 30px;
        }
        .logo h1 {
          color: #000;
          font-size: 28px;
          font-weight: bold;
          margin: 0;
        }
        .code-container {
          background-color: #f8f8f8;
          border-radius: 8px;
          padding: 20px;
          text-align: center;
          margin: 30px 0;
        }
        .code {
          font-size: 32px;
          font-weight: bold;
          color: #000;
          letter-spacing: 8px;
          font-family: 'Courier New', monospace;
        }
        .footer {
          text-align: center;
          margin-top: 30px;
          color: #666;
          font-size: 12px;
        }
      </style>
    </head>
    <body>
      <div class="container">
        <div class="logo">
          <h1>Qent</h1>
        </div>
        <h2 style="color: #000; font-size: 24px; margin-bottom: 20px;">Enter verification code</h2>
        <p style="color: #666; font-size: 14px; margin-bottom: 30px;">
          We have sent a code to your email address. Please enter the code below to verify your account.
        </p>
        <div class="code-container">
          <div class="code">$code</div>
        </div>
        <p style="color: #666; font-size: 14px; margin-top: 30px;">
          This code will expire in 5 minutes.
        </p>
        <p style="color: #666; font-size: 14px;">
          If you didn't request this code, please ignore this email.
        </p>
        <div class="footer">
          <p>© 2024 Qent. All rights reserved.</p>
        </div>
      </div>
    </body>
    </html>
    ''';
  }

  /// Save verification code to Firestore with expiry
  Future<void> saveVerificationCode(String email, String code) async {
    try {
      await _firestore.collection('verifications').doc(email).set({
        'code': code,
        'email': email,
        'timestamp': FieldValue.serverTimestamp(),
        'expiresAt': Timestamp.fromDate(
          DateTime.now().add(_codeExpiry),
        ),
        'verified': false,
      });
    } catch (e) {
      if (kDebugMode) {
        print('Error saving verification code: $e');
      }
      rethrow;
    }
  }

  /// Verify the code entered by the user
  Future<bool> verifyCode(String email, String inputCode) async {
    try {
      final doc = await _firestore.collection('verifications').doc(email).get();
      
      if (!doc.exists) {
        if (kDebugMode) {
          print('No verification code found for $email');
        }
        return false;
      }

      final data = doc.data();
      if (data == null) return false;

      final storedCode = data['code'] as String?;
      final verified = data['verified'] as bool? ?? false;
      final expiresAt = (data['expiresAt'] as Timestamp?)?.toDate();

      // Check if already verified
      if (verified) {
        if (kDebugMode) {
          print('Code already used');
        }
        return false;
      }

      // Check if expired
      if (expiresAt == null || DateTime.now().isAfter(expiresAt)) {
        if (kDebugMode) {
          print('Verification code expired');
        }
        return false;
      }

      // Check if code matches
      if (storedCode != inputCode) {
        if (kDebugMode) {
          print('Invalid verification code');
        }
        return false;
      }

      // Mark as verified
      await _firestore.collection('verifications').doc(email).update({
        'verified': true,
        'verifiedAt': FieldValue.serverTimestamp(),
      });

      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Error verifying code: $e');
      }
      return false;
    }
  }

  /// Resend verification code
  Future<bool> resendVerificationCode(String email) async {
    try {
      // Generate new code
      final code = generateVerificationCode();

      // Save to Firestore
      await saveVerificationCode(email, code);

      // Send email
      return await sendVerificationCode(email, code);
    } catch (e) {
      if (kDebugMode) {
        print('Error resending verification code: $e');
      }
      return false;
    }
  }

  /// Delete verification code after successful verification
  Future<void> deleteVerificationCode(String email) async {
    try {
      await _firestore.collection('verifications').doc(email).delete();
    } catch (e) {
      if (kDebugMode) {
        print(' Error deleting verification code: $e');
      }
    }
  }

  /// Check if email is already verified
  Future<bool> isEmailVerified(String email) async {
    try {
      final doc = await _firestore.collection('verifications').doc(email).get();
      if (!doc.exists) return false;
      
      final data = doc.data();
      return data?['verified'] == true;
    } catch (e) {
      return false;
    }
  }
}

