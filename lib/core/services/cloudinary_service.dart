import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class CloudinaryService {
  static final CloudinaryService _instance = CloudinaryService._internal();
  factory CloudinaryService() => _instance;
  CloudinaryService._internal();

  late String _cloudName;
  late String _apiKey;
  late String _apiSecret;

  void _log(String message) {
    if (kDebugMode) debugPrint('[Qent Cloudinary] $message');
  }

  void initialize({
    String? cloudName,
    String? apiKey,
    String? apiSecret,
  }) {
    if (cloudName == null || apiKey == null || apiSecret == null) {
      throw Exception('Cloudinary credentials must be provided via .env');
    }
    _cloudName = cloudName;
    _apiKey = apiKey;
    _apiSecret = apiSecret;
    _log('Initialized | cloud: $_cloudName');
  }

  Future<String?> uploadImage({
    required File imageFile,
    String? folder,
    String? publicId,
  }) async {
    _log('> Uploading file: ${imageFile.path} | folder: $folder');
    final sw = Stopwatch()..start();
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      final url = 'https://api.cloudinary.com/v1_1/$_cloudName/image/upload';

      final request = http.MultipartRequest('POST', Uri.parse(url));
      request.fields['timestamp'] = timestamp;
      if (folder != null) request.fields['folder'] = folder;
      if (publicId != null) request.fields['public_id'] = publicId;

      request.files.add(
        await http.MultipartFile.fromPath('file', imageFile.path),
      );

      final params = <String, String>{'timestamp': timestamp};
      if (folder != null) params['folder'] = folder;
      if (publicId != null) params['public_id'] = publicId;

      final sortedParams = Map.fromEntries(
        params.entries.toList()..sort((a, b) => a.key.compareTo(b.key))
      );
      final queryString = sortedParams.entries
          .map((e) => '${e.key}=${e.value}')
          .join('&');
      final signature = sha1.convert(utf8.encode('$queryString$_apiSecret')).toString();

      request.fields['api_key'] = _apiKey;
      request.fields['signature'] = signature;

      final response = await request.send();
      final responseBody = await response.stream.bytesToString();
      sw.stop();

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(responseBody) as Map<String, dynamic>;
        final secureUrl = jsonResponse['secure_url'] as String?;
        _log('OK: Upload success (${sw.elapsedMilliseconds}ms) -> $secureUrl');
        return secureUrl;
      } else {
        _log('FAIL: Upload failed: ${response.statusCode} (${sw.elapsedMilliseconds}ms)');
        _log('  Response: $responseBody');
        return null;
      }
    } catch (e) {
      sw.stop();
      _log('ERROR: Upload error (${sw.elapsedMilliseconds}ms): $e');
      return null;
    }
  }

  /// Upload a non-image file (audio, video, etc.) via Cloudinary's raw upload.
  Future<String?> uploadRaw({
    required File file,
    String? folder,
  }) async {
    _log('> Uploading raw file: ${file.path} | folder: $folder');
    final sw = Stopwatch()..start();
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      final url = 'https://api.cloudinary.com/v1_1/$_cloudName/raw/upload';

      final request = http.MultipartRequest('POST', Uri.parse(url));
      request.fields['timestamp'] = timestamp;
      if (folder != null) request.fields['folder'] = folder;

      request.files.add(
        await http.MultipartFile.fromPath('file', file.path),
      );

      final params = <String, String>{'timestamp': timestamp};
      if (folder != null) params['folder'] = folder;

      final sortedParams = Map.fromEntries(
        params.entries.toList()..sort((a, b) => a.key.compareTo(b.key))
      );
      final queryString = sortedParams.entries
          .map((e) => '${e.key}=${e.value}')
          .join('&');
      final signature = sha1.convert(utf8.encode('$queryString$_apiSecret')).toString();

      request.fields['api_key'] = _apiKey;
      request.fields['signature'] = signature;

      final response = await request.send();
      final responseBody = await response.stream.bytesToString();
      sw.stop();

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(responseBody) as Map<String, dynamic>;
        final secureUrl = jsonResponse['secure_url'] as String?;
        _log('OK: Raw upload success (${sw.elapsedMilliseconds}ms) -> $secureUrl');
        return secureUrl;
      } else {
        _log('FAIL: Raw upload failed: ${response.statusCode} (${sw.elapsedMilliseconds}ms)');
        _log('  Response: $responseBody');
        return null;
      }
    } catch (e) {
      sw.stop();
      _log('ERROR: Raw upload error (${sw.elapsedMilliseconds}ms): $e');
      return null;
    }
  }

  Future<String?> uploadImageFromBytes({
    required List<int> imageBytes,
    required String fileName,
    String? folder,
  }) async {
    _log('> Uploading bytes: $fileName (${imageBytes.length} bytes) | folder: $folder');
    final sw = Stopwatch()..start();
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      final url = 'https://api.cloudinary.com/v1_1/$_cloudName/image/upload';

      final request = http.MultipartRequest('POST', Uri.parse(url));
      request.fields['timestamp'] = timestamp;
      if (folder != null) request.fields['folder'] = folder;

      request.files.add(
        http.MultipartFile.fromBytes('file', imageBytes, filename: fileName),
      );

      final params = <String, String>{'timestamp': timestamp};
      if (folder != null) params['folder'] = folder;

      final sortedParams = Map.fromEntries(
        params.entries.toList()..sort((a, b) => a.key.compareTo(b.key))
      );
      final queryString = sortedParams.entries
          .map((e) => '${e.key}=${e.value}')
          .join('&');
      final signature = sha1.convert(utf8.encode('$queryString$_apiSecret')).toString();

      request.fields['api_key'] = _apiKey;
      request.fields['signature'] = signature;

      final response = await request.send();
      final responseBody = await response.stream.bytesToString();
      sw.stop();

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(responseBody) as Map<String, dynamic>;
        final secureUrl = jsonResponse['secure_url'] as String?;
        _log('OK: Bytes upload success (${sw.elapsedMilliseconds}ms) -> $secureUrl');
        return secureUrl;
      } else {
        _log('FAIL: Bytes upload failed: ${response.statusCode} (${sw.elapsedMilliseconds}ms)');
        _log('  Response: $responseBody');
        return null;
      }
    } catch (e) {
      sw.stop();
      _log('ERROR: Bytes upload error (${sw.elapsedMilliseconds}ms): $e');
      return null;
    }
  }

  Future<bool> deleteImage(String publicId) async {
    _log('> Deleting image: $publicId');
    final sw = Stopwatch()..start();
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch.toString();

      final params = <String, String>{
        'public_id': publicId,
        'timestamp': timestamp,
      };
      final sortedParams = Map.fromEntries(
        params.entries.toList()..sort((a, b) => a.key.compareTo(b.key))
      );
      final queryString = sortedParams.entries
          .map((e) => '${e.key}=${e.value}')
          .join('&');
      final signature = sha1.convert(utf8.encode('$queryString$_apiSecret')).toString();

      final url = Uri.parse('https://api.cloudinary.com/v1_1/$_cloudName/image/destroy').replace(
        queryParameters: {
          'public_id': publicId,
          'timestamp': timestamp,
          'api_key': _apiKey,
          'signature': signature,
        },
      );

      final response = await http.delete(url);
      sw.stop();

      if (response.statusCode == 200) {
        _log('OK: Deleted $publicId (${sw.elapsedMilliseconds}ms)');
        return true;
      } else {
        _log('FAIL: Delete failed: ${response.statusCode} (${sw.elapsedMilliseconds}ms) - ${response.body}');
        return false;
      }
    } catch (e) {
      sw.stop();
      _log('ERROR: Delete error (${sw.elapsedMilliseconds}ms): $e');
      return false;
    }
  }

  String? getPublicIdFromUrl(String url) {
    try {
      final uri = Uri.parse(url);
      final pathSegments = uri.pathSegments;
      if (pathSegments.isNotEmpty) {
        final lastSegment = pathSegments.last;
        final publicId = lastSegment.split('.').first;
        return publicId;
      }
      return null;
    } catch (e) {
      _log('ERROR: Error extracting public ID from $url: $e');
      return null;
    }
  }
}
