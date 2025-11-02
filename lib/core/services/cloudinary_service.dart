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

  // Initialize with your Cloudinary credentials
  void initialize({
    String? cloudName,
    String? apiKey,
    String? apiSecret,
  }) {
    _cloudName = cloudName ?? 'dz9nzikbp';
    _apiKey = apiKey ?? '913914774249252';
    _apiSecret = apiSecret ?? 'HOl54F8CO4B2o6nxnvElqYskR04';
  }

  // Upload image file to Cloudinary
  Future<String?> uploadImage({
    required File imageFile,
    String? folder,
    String? publicId,
  }) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      
      // For authenticated uploads using API key and signature
      final url = 'https://api.cloudinary.com/v1_1/$_cloudName/image/upload';
      
      final request = http.MultipartRequest('POST', Uri.parse(url));
      
      // Add timestamp and public_id if provided
      request.fields['timestamp'] = timestamp;
      if (folder != null) {
        request.fields['folder'] = folder;
      }
      if (publicId != null) {
        request.fields['public_id'] = publicId;
      }
      
      // Add file
      request.files.add(
        await http.MultipartFile.fromPath(
          'file',
          imageFile.path,
        ),
      );

      // Generate signature for authenticated upload
      final params = <String, String>{
        'timestamp': timestamp,
      };
      if (folder != null) params['folder'] = folder;
      if (publicId != null) params['public_id'] = publicId;
      
      final sortedParams = Map.fromEntries(
        params.entries.toList()..sort((a, b) => a.key.compareTo(b.key))
      );
      
      final queryString = sortedParams.entries
          .map((e) => '${e.key}=${e.value}')
          .join('&');
      
      final signatureString = '$queryString$_apiSecret';
      final signature = sha1.convert(utf8.encode(signatureString)).toString();
      
      request.fields['api_key'] = _apiKey;
      request.fields['signature'] = signature;

      final response = await request.send();
      final responseBody = await response.stream.bytesToString();
      
      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(responseBody) as Map<String, dynamic>;
        final secureUrl = jsonResponse['secure_url'] as String?;
        return secureUrl;
      } else {
        if (kDebugMode) {
          print('Cloudinary upload error: ${response.statusCode} - $responseBody');
        }
        return null;
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error uploading image to Cloudinary: $e');
      }
      return null;
    }
  }

  // Upload image from bytes
  Future<String?> uploadImageFromBytes({
    required List<int> imageBytes,
    required String fileName,
    String? folder,
  }) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      final url = 'https://api.cloudinary.com/v1_1/$_cloudName/image/upload';
      
      final request = http.MultipartRequest('POST', Uri.parse(url));
      
      request.fields['timestamp'] = timestamp;
      if (folder != null) {
        request.fields['folder'] = folder;
      }
      
      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          imageBytes,
          filename: fileName,
        ),
      );

      // Generate signature
      final params = <String, String>{
        'timestamp': timestamp,
      };
      if (folder != null) params['folder'] = folder;
      
      final sortedParams = Map.fromEntries(
        params.entries.toList()..sort((a, b) => a.key.compareTo(b.key))
      );
      
      final queryString = sortedParams.entries
          .map((e) => '${e.key}=${e.value}')
          .join('&');
      
      final signatureString = '$queryString$_apiSecret';
      final signature = sha1.convert(utf8.encode(signatureString)).toString();
      
      request.fields['api_key'] = _apiKey;
      request.fields['signature'] = signature;

      final response = await request.send();
      final responseBody = await response.stream.bytesToString();
      
      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(responseBody) as Map<String, dynamic>;
        final secureUrl = jsonResponse['secure_url'] as String?;
        return secureUrl;
      } else {
        if (kDebugMode) {
          print('Cloudinary upload error: ${response.statusCode} - $responseBody');
        }
        return null;
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error uploading image to Cloudinary: $e');
      }
      return null;
    }
  }

  // Delete image from Cloudinary
  Future<bool> deleteImage(String publicId) async {
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
      
      final signatureString = '$queryString$_apiSecret';
      final signature = sha1.convert(utf8.encode(signatureString)).toString();
      
      final url = Uri.parse('https://api.cloudinary.com/v1_1/$_cloudName/image/destroy').replace(
        queryParameters: {
          'public_id': publicId,
          'timestamp': timestamp,
          'api_key': _apiKey,
          'signature': signature,
        },
      );
      
      final response = await http.delete(url);
      
      if (response.statusCode == 200) {
        return true;
      } else {
        if (kDebugMode) {
          print('Cloudinary delete error: ${response.statusCode} - ${response.body}');
        }
        return false;
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error deleting image from Cloudinary: $e');
      }
      return false;
    }
  }

  // Extract public ID from Cloudinary URL
  String? getPublicIdFromUrl(String url) {
    try {
      final uri = Uri.parse(url);
      final pathSegments = uri.pathSegments;
      if (pathSegments.isNotEmpty) {
        final lastSegment = pathSegments.last;
        // Remove extension
        final publicId = lastSegment.split('.').first;
        return publicId;
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        print('Error extracting public ID: $e');
      }
      return null;
    }
  }
}
