import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Central HTTP client for the Qent Rust backend.
/// Manages JWT token storage, authenticated requests, and base URL config.
class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;
  ApiClient._internal();

  // Change this to your deployed backend URL in production
  String _baseUrl = 'http://10.0.2.2:8080/api'; // Android emulator default
  String? _token;
  SharedPreferences? _prefs;

  String get baseUrl => _baseUrl;

  /// Initialize with optional custom base URL.
  /// Call this once at app startup.
  Future<void> initialize({String? baseUrl}) async {
    if (baseUrl != null) _baseUrl = baseUrl;
    _prefs = await SharedPreferences.getInstance();
    _token = _prefs?.getString('auth_token');
  }

  /// Set the base URL (useful for switching environments).
  void setBaseUrl(String url) {
    _baseUrl = url;
  }

  /// Store JWT token after login/signup.
  Future<void> setToken(String token) async {
    _token = token;
    await _prefs?.setString('auth_token', token);
  }

  /// Get current token.
  String? get token => _token;

  /// Check if user is authenticated.
  bool get isAuthenticated => _token != null;

  /// Clear token on logout.
  Future<void> clearToken() async {
    _token = null;
    await _prefs?.remove('auth_token');
  }

  /// Build headers with optional auth token.
  Map<String, String> _headers({bool auth = true}) {
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };
    if (auth && _token != null) {
      headers['Authorization'] = 'Bearer $_token';
    }
    return headers;
  }

  /// GET request.
  Future<ApiResponse> get(
    String path, {
    bool auth = true,
    Map<String, String>? queryParams,
  }) async {
    try {
      var uri = Uri.parse('$_baseUrl$path');
      if (queryParams != null) {
        uri = uri.replace(queryParameters: queryParams);
      }
      final response = await http.get(uri, headers: _headers(auth: auth));
      return ApiResponse.fromHttpResponse(response);
    } catch (e) {
      debugPrint('API GET error: $e');
      return ApiResponse(statusCode: 0, body: {'error': e.toString()});
    }
  }

  /// POST request.
  Future<ApiResponse> post(
    String path, {
    Map<String, dynamic>? body,
    bool auth = true,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl$path'),
        headers: _headers(auth: auth),
        body: body != null ? jsonEncode(body) : null,
      );
      return ApiResponse.fromHttpResponse(response);
    } catch (e) {
      debugPrint('API POST error: $e');
      return ApiResponse(statusCode: 0, body: {'error': e.toString()});
    }
  }

  /// PUT request.
  Future<ApiResponse> put(
    String path, {
    Map<String, dynamic>? body,
    bool auth = true,
  }) async {
    try {
      final response = await http.put(
        Uri.parse('$_baseUrl$path'),
        headers: _headers(auth: auth),
        body: body != null ? jsonEncode(body) : null,
      );
      return ApiResponse.fromHttpResponse(response);
    } catch (e) {
      debugPrint('API PUT error: $e');
      return ApiResponse(statusCode: 0, body: {'error': e.toString()});
    }
  }

  /// DELETE request.
  Future<ApiResponse> delete(
    String path, {
    bool auth = true,
  }) async {
    try {
      final response = await http.delete(
        Uri.parse('$_baseUrl$path'),
        headers: _headers(auth: auth),
      );
      return ApiResponse.fromHttpResponse(response);
    } catch (e) {
      debugPrint('API DELETE error: $e');
      return ApiResponse(statusCode: 0, body: {'error': e.toString()});
    }
  }
}

/// Unified API response wrapper.
class ApiResponse {
  final int statusCode;
  final dynamic body;

  ApiResponse({required this.statusCode, required this.body});

  factory ApiResponse.fromHttpResponse(http.Response response) {
    dynamic parsedBody;
    try {
      parsedBody = jsonDecode(response.body);
    } catch (_) {
      parsedBody = response.body;
    }
    return ApiResponse(statusCode: response.statusCode, body: parsedBody);
  }

  bool get isSuccess => statusCode >= 200 && statusCode < 300;

  String get errorMessage {
    if (body is Map && body['error'] != null) {
      return body['error'].toString();
    }
    if (body is Map && body['errors'] != null) {
      return body['errors'].toString();
    }
    return 'Request failed with status $statusCode';
  }
}
