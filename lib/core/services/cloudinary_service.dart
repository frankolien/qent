import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Cloudinary uploader using unsigned upload presets. Operations requiring
/// the API secret (delete, admin) must run on the backend, not here.
class CloudinaryService {
  static final CloudinaryService _instance = CloudinaryService._internal();
  factory CloudinaryService() => _instance;
  CloudinaryService._internal();

  late String _cloudName;
  late String _uploadPreset;

  void _log(String message) {
    if (kDebugMode) debugPrint('[Qent Cloudinary] $message');
  }

  void initialize({
    String? cloudName,
    String? uploadPreset,
  }) {
    if (cloudName == null || cloudName.isEmpty ||
        uploadPreset == null || uploadPreset.isEmpty) {
      throw Exception(
        'Cloudinary needs CLOUDINARY_CLOUD_NAME and CLOUDINARY_UPLOAD_PRESET '
        'in .env. The upload preset must be configured as "Unsigned" in the '
        'Cloudinary dashboard.',
      );
    }
    _cloudName = cloudName;
    _uploadPreset = uploadPreset;
    _log('Initialized | cloud: $_cloudName | preset: $_uploadPreset');
  }

  Future<String?> uploadImage({
    required File imageFile,
    String? folder,
    String? publicId,
  }) {
    return _upload(
      resourceType: 'image',
      fileBytes: null,
      filePath: imageFile.path,
      fileName: null,
      folder: folder,
      publicId: publicId,
    );
  }

  /// Upload a non-image file (audio, video, etc.) via the raw endpoint.
  Future<String?> uploadRaw({
    required File file,
    String? folder,
  }) {
    return _upload(
      resourceType: 'raw',
      fileBytes: null,
      filePath: file.path,
      fileName: null,
      folder: folder,
      publicId: null,
    );
  }

  Future<String?> uploadImageFromBytes({
    required List<int> imageBytes,
    required String fileName,
    String? folder,
  }) {
    return _upload(
      resourceType: 'image',
      fileBytes: imageBytes,
      filePath: null,
      fileName: fileName,
      folder: folder,
      publicId: null,
    );
  }

  Future<String?> _upload({
    required String resourceType,
    required List<int>? fileBytes,
    required String? filePath,
    required String? fileName,
    required String? folder,
    required String? publicId,
  }) async {
    final label = filePath ?? fileName ?? '<bytes>';
    _log('> Uploading ($resourceType): $label | folder: $folder');
    final sw = Stopwatch()..start();
    try {
      final url = Uri.parse(
        'https://api.cloudinary.com/v1_1/$_cloudName/$resourceType/upload',
      );
      final request = http.MultipartRequest('POST', url);
      request.fields['upload_preset'] = _uploadPreset;
      if (folder != null) request.fields['folder'] = folder;
      if (publicId != null) request.fields['public_id'] = publicId;

      if (filePath != null) {
        request.files.add(await http.MultipartFile.fromPath('file', filePath));
      } else {
        request.files.add(
          http.MultipartFile.fromBytes('file', fileBytes!, filename: fileName),
        );
      }

      final response = await request.send();
      final body = await response.stream.bytesToString();
      sw.stop();

      if (response.statusCode == 200) {
        final json = jsonDecode(body) as Map<String, dynamic>;
        final secureUrl = json['secure_url'] as String?;
        _log('OK (${sw.elapsedMilliseconds}ms) -> $secureUrl');
        return secureUrl;
      }
      _log('FAIL ${response.statusCode} (${sw.elapsedMilliseconds}ms): $body');
      return null;
    } catch (e) {
      sw.stop();
      _log('ERROR (${sw.elapsedMilliseconds}ms): $e');
      return null;
    }
  }

  String? getPublicIdFromUrl(String url) {
    try {
      final uri = Uri.parse(url);
      final pathSegments = uri.pathSegments;
      if (pathSegments.isEmpty) return null;
      return pathSegments.last.split('.').first;
    } catch (e) {
      _log('ERROR: extracting public ID from $url: $e');
      return null;
    }
  }
}
