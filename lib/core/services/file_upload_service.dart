import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:qent/core/services/cloudinary_service.dart';

class FileUploadService {
  /// Upload a file (image or audio) to Cloudinary and return its URL.
  static Future<String?> upload(File file) async {
    final filename = file.path.split('/').last;
    final ext = filename.split('.').last.toLowerCase();
    final isAudio = ['mp3', 'm4a', 'aac', 'ogg', 'wav', 'opus'].contains(ext);
    final isImage = ['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(ext);

    if (kDebugMode) debugPrint('[FileUpload] Uploading: $filename (${isAudio ? "audio" : isImage ? "image" : "other"})');

    try {
      final cloudinary = CloudinaryService();

      if (isImage) {
        return await cloudinary.uploadImage(
          imageFile: file,
          folder: 'qent/chat',
        );
      } else if (isAudio) {
        // Use raw upload for audio files
        return await cloudinary.uploadRaw(
          file: file,
          folder: 'qent/voice',
        );
      } else {
        return await cloudinary.uploadRaw(
          file: file,
          folder: 'qent/files',
        );
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[FileUpload] FAILED: $e');
      return null;
    }
  }
}
