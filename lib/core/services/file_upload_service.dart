import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FileUploadService {
  /// Upload a file and return its URL
  static Future<String?> upload(File file) async {
    final baseUrl = dotenv.env['API_BASE_URL'] ?? 'http://127.0.0.1:8080/api';
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token') ?? '';

    final uri = Uri.parse('$baseUrl/upload');
    final request = http.MultipartRequest('POST', uri)
      ..headers['Authorization'] = 'Bearer $token';

    final filename = file.path.split('/').last;
    final ext = filename.split('.').last.toLowerCase();

    // Determine MIME type
    String mimeType;
    String mimeSubtype;
    if (['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(ext)) {
      mimeType = 'image';
      mimeSubtype = ext == 'jpg' ? 'jpeg' : ext;
    } else if (['mp3', 'm4a', 'aac', 'ogg', 'wav', 'opus'].contains(ext)) {
      mimeType = 'audio';
      mimeSubtype = ext;
    } else {
      mimeType = 'application';
      mimeSubtype = 'octet-stream';
    }

    request.files.add(await http.MultipartFile.fromPath(
      'file',
      file.path,
      contentType: MediaType(mimeType, mimeSubtype),
    ));

    try {
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      if (response.statusCode == 200) {
        final body = response.body;
        // Parse {"url": "/uploads/..."}
        final match = RegExp(r'"url"\s*:\s*"([^"]+)"').firstMatch(body);
        if (match != null) {
          final url = match.group(1)!;
          // If relative, prepend base URL (without /api)
          if (url.startsWith('/')) {
            final serverBase = baseUrl.replaceFirst('/api', '');
            return '$serverBase$url';
          }
          return url;
        }
      }
    } catch (e) {
      // Upload failed
    }
    return null;
  }
}
