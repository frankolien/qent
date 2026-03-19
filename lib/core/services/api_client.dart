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

  // Production API on Render
  String _baseUrl = 'https://qent-backend.onrender.com/api';
  String? _token;
  SharedPreferences? _prefs;

  String get baseUrl => _baseUrl;

  /// Initialize with optional custom base URL.
  /// Call this once at app startup.
  Future<void> initialize({String? baseUrl}) async {
    if (baseUrl != null) _baseUrl = baseUrl;
    _prefs = await SharedPreferences.getInstance();
    _token = _prefs?.getString('auth_token');
    _log('ApiClient initialized | baseUrl: $_baseUrl | hasToken: ${_token != null}');
  }

  /// Set the base URL (useful for switching environments).
  void setBaseUrl(String url) {
    _baseUrl = url;
    _log('Base URL changed to: $url');
  }

  /// Store JWT token after login/signup.
  Future<void> setToken(String token) async {
    _token = token;
    await _prefs?.setString('auth_token', token);
    _log('Token stored (${token.length} chars)');
  }

  /// Get current token.
  String? get token => _token;

  /// Check if user is authenticated.
  bool get isAuthenticated => _token != null;

  /// Clear token on logout.
  Future<void> clearToken() async {
    _token = null;
    await _prefs?.remove('auth_token');
    _log('Token cleared');
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

  /// Debug logger — only prints in debug mode
  void _log(String message) {
    if (kDebugMode) {
      debugPrint('[Qent API] $message');
    }
  }

  /// Log request details
  void _logRequest(String method, String url, {Map<String, dynamic>? body, bool auth = true}) {
    _log('> $method $url');
    if (auth) _log('  Auth: ${_token != null ? "Bearer ${_token!.substring(0, 20)}..." : "none"}');
    if (body != null) {
      // Redact sensitive fields
      final safeBody = Map<String, dynamic>.from(body);
      for (final key in ['password', 'token', 'card_number', 'cvc']) {
        if (safeBody.containsKey(key)) safeBody[key] = '***';
      }
      _log('  Body: ${jsonEncode(safeBody)}');
    }
  }

  /// Log response details
  void _logResponse(String method, String url, int statusCode, dynamic body, Duration elapsed) {
    final tag = statusCode >= 200 && statusCode < 300 ? 'OK' : 'FAIL';
    _log('$tag $method $url -> $statusCode (${elapsed.inMilliseconds}ms)');
    if (body != null) {
      final bodyStr = body is Map ? jsonEncode(body) : body.toString();
      // Truncate long responses
      final truncated = bodyStr.length > 500 ? '${bodyStr.substring(0, 500)}...' : bodyStr;
      _log('  Response: $truncated');
    }
  }

  /// GET request.
  Future<ApiResponse> get(
    String path, {
    bool auth = true,
    Map<String, String>? queryParams,
  }) async {
    final url = '$_baseUrl$path';
    _logRequest('GET', url, auth: auth);
    final stopwatch = Stopwatch()..start();
    try {
      var uri = Uri.parse(url);
      if (queryParams != null) {
        uri = uri.replace(queryParameters: queryParams);
      }
      final response = await http.get(uri, headers: _headers(auth: auth));
      stopwatch.stop();
      final apiResponse = ApiResponse.fromHttpResponse(response);
      _logResponse('GET', url, response.statusCode, apiResponse.body, stopwatch.elapsed);
      return apiResponse;
    } catch (e) {
      stopwatch.stop();
      _log('ERROR GET $url FAILED (${stopwatch.elapsed.inMilliseconds}ms): $e');
      return ApiResponse(statusCode: 0, body: {'error': e.toString()});
    }
  }

  /// POST request.
  Future<ApiResponse> post(
    String path, {
    Map<String, dynamic>? body,
    bool auth = true,
  }) async {
    final url = '$_baseUrl$path';
    _logRequest('POST', url, body: body, auth: auth);
    final stopwatch = Stopwatch()..start();
    try {
      final response = await http.post(
        Uri.parse(url),
        headers: _headers(auth: auth),
        body: body != null ? jsonEncode(body) : null,
      );
      stopwatch.stop();
      final apiResponse = ApiResponse.fromHttpResponse(response);
      _logResponse('POST', url, response.statusCode, apiResponse.body, stopwatch.elapsed);
      return apiResponse;
    } catch (e) {
      stopwatch.stop();
      _log('ERROR POST $url FAILED (${stopwatch.elapsed.inMilliseconds}ms): $e');
      return ApiResponse(statusCode: 0, body: {'error': e.toString()});
    }
  }

  /// PUT request.
  Future<ApiResponse> put(
    String path, {
    Map<String, dynamic>? body,
    bool auth = true,
  }) async {
    final url = '$_baseUrl$path';
    _logRequest('PUT', url, body: body, auth: auth);
    final stopwatch = Stopwatch()..start();
    try {
      final response = await http.put(
        Uri.parse(url),
        headers: _headers(auth: auth),
        body: body != null ? jsonEncode(body) : null,
      );
      stopwatch.stop();
      final apiResponse = ApiResponse.fromHttpResponse(response);
      _logResponse('PUT', url, response.statusCode, apiResponse.body, stopwatch.elapsed);
      return apiResponse;
    } catch (e) {
      stopwatch.stop();
      _log('ERROR PUT $url FAILED (${stopwatch.elapsed.inMilliseconds}ms): $e');
      return ApiResponse(statusCode: 0, body: {'error': e.toString()});
    }
  }

  /// DELETE request.
  Future<ApiResponse> delete(
    String path, {
    bool auth = true,
  }) async {
    final url = '$_baseUrl$path';
    _logRequest('DELETE', url, auth: auth);
    final stopwatch = Stopwatch()..start();
    try {
      final response = await http.delete(
        Uri.parse(url),
        headers: _headers(auth: auth),
      );
      stopwatch.stop();
      final apiResponse = ApiResponse.fromHttpResponse(response);
      _logResponse('DELETE', url, response.statusCode, apiResponse.body, stopwatch.elapsed);
      return apiResponse;
    } catch (e) {
      stopwatch.stop();
      _log('ERROR DELETE $url FAILED (${stopwatch.elapsed.inMilliseconds}ms): $e');
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
