import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'cloudinary_upload_result.dart';

class CloudinaryVideoUploader {
  final String cloudName;
  final String uploadPreset;

  CloudinaryVideoUploader({
    required this.cloudName,
    required this.uploadPreset,
  });

  Future<CloudinaryVideoUploadResult> uploadVideoAuto({
    String? filePath,               // không dùng ở WEB
    Uint8List? bytes,               // ✅ dùng bytes cho web
    String filename = 'video.mp4',
    String folder = 'cses/videos',
    void Function(double p)? onProgress,
  }) async {
    if (bytes == null || bytes.isEmpty) {
      throw Exception('WEB upload cần bytes');
    }

    final uri = Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/video/upload');

    const chunkSize = 64 * 1024;
    final total = bytes.length;
    int sent = 0;

    Stream<List<int>> chunkedStream() async* {
      for (int i = 0; i < bytes.length; i += chunkSize) {
        final end = (i + chunkSize < bytes.length) ? i + chunkSize : bytes.length;
        final chunk = bytes.sublist(i, end);
        sent += chunk.length;
        if (onProgress != null && total > 0) {
          onProgress((sent / total).clamp(0.0, 1.0));
        }
        yield chunk;
      }
    }

    final req = http.MultipartRequest('POST', uri)
      ..fields['upload_preset'] = uploadPreset
      ..fields['folder'] = folder
      ..files.add(
        http.MultipartFile('file', http.ByteStream(chunkedStream()), total, filename: filename),
      );

    final streamed = await req.send();
    final resp = await http.Response.fromStream(streamed);

    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception('Cloudinary upload failed (${resp.statusCode}): ${resp.body}');
    }

    final map = jsonDecode(resp.body) as Map<String, dynamic>;
    final secureUrl = (map['secure_url'] ?? '').toString();
    final publicId = (map['public_id'] ?? '').toString();

    if (secureUrl.isEmpty || publicId.isEmpty) {
      throw Exception('Thiếu secure_url/public_id: ${resp.body}');
    }

    onProgress?.call(1.0);

    return CloudinaryVideoUploadResult(
      secureUrl: secureUrl,
      publicId: publicId,
      bytes: total,
    );
  }

  String buildThumbUrl(String publicId, {int second = 0, int width = 480}) {
    final transform = 'so_$second,w_$width,c_fill,q_auto,f_jpg';
    return 'https://res.cloudinary.com/$cloudName/video/upload/$transform/$publicId.jpg';
  }
}
