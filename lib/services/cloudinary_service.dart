import 'dart:io';
import 'package:cloudinary_public/cloudinary_public.dart';
import '../config/cloudinary_config.dart';

class CloudinaryService {
  final _cli = CloudinaryPublic(
    CloudinaryConfig.cloudName,
    CloudinaryConfig.uploadPreset,
    cache: false,
  );

  Future<String> uploadImage(File file, {String folder = 'products'}) async {
    final res = await _cli.uploadFile(
      CloudinaryFile.fromFile(file.path, folder: folder),
    );
    return res.secureUrl;
  }
}
