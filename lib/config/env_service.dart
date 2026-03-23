import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

class EnvService {
  static Map<String, dynamic>? _data;

  static Future<void> load() async {
    final jsonStr = await rootBundle.loadString('assets/config/env.json');
    _data = json.decode(jsonStr);
  }

  static String get(String key) {
    final value = _data?[key];
    if (value == null || value.isEmpty) {
      throw Exception('Missing $key in env.json');
    }
    return value;
  }
}
