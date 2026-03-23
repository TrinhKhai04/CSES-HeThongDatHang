import 'dart:convert';
import 'dart:io' show File;

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
    String? filePath,               // ✅ dùng path thay vì File để UI không cần dart:io
    List<int>? bytes,               // không dùng ở IO
    String filename = 'video.mp4',
    String folder = 'cses/videos',
    void Function(double p)? onProgress,
  }) async {
    if (filePath == null || filePath.isEmpty) {
      throw Exception('MOBILE upload cần filePath');
    }

    final file = File(filePath);
    final uri = Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/video/upload');

    final total = await file.length();
    int sent = 0;

    Stream<List<int>> progressStream(Stream<List<int>> input) async* {
      await for (final chunk in input) {
        sent += chunk.length;
        if (onProgress != null && total > 0) {
          onProgress((sent / total).clamp(0.0, 1.0));
        }
        yield chunk;
      }
    }

    final stream = http.ByteStream(progressStream(file.openRead()));

    final req = http.MultipartRequest('POST', uri)
      ..fields['upload_preset'] = uploadPreset
      ..fields['folder'] = folder
      ..files.add(http.MultipartFile('file', stream, total, filename: filename));

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
