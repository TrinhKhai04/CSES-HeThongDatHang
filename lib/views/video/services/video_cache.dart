import 'dart:io';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

class VideoCache {
  static final CacheManager _cm = CacheManager(
    Config(
      'videoCache',
      stalePeriod: const Duration(days: 7),
      maxNrOfCacheObjects: 30,
    ),
  );

  static Future<File> getFile(String url) => _cm.getSingleFile(url);
}
