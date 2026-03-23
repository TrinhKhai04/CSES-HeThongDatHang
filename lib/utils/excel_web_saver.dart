// lib/utils/excel_web_saver.dart
import 'dart:io';
import 'dart:typed_data';

import 'package:file_saver/file_saver.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

String _timestamp() {
  final now = DateTime.now();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${now.year}'
      '${two(now.month)}'
      '${two(now.day)}_'
      '${two(now.hour)}'
      '${two(now.minute)}';
}

/// Lưu file Excel.
/// - Web / Android / iOS / desktop: dùng FileSaver (trình duyệt tải xuống
///   hoặc hệ thống mở hộp thoại lưu / share).
/// - Nếu FileSaver lỗi → fallback về thư mục documents của app.
Future<String> saveExcelFile(
    List<int> bytes, {
      String baseName = 'cses_orders',
    }) async {
  final fileName = '${baseName}_${_timestamp()}';
  final data = Uint8List.fromList(bytes);

  // 1️⃣ Thử dùng FileSaver cho mọi nền tảng
  try {
    final savedPath = await FileSaver.instance.saveFile(
      name: fileName,
      bytes: data,
      fileExtension: 'xlsx',
      mimeType: MimeType.microsoftExcel,
    );

    if (savedPath.isNotEmpty) {
      // Android/iOS có thể trả về path hoặc chỉ tên file
      return savedPath;
    }
  } catch (e) {
    debugPrint('FileSaver error: $e');
  }

  // 2️⃣ Fallback: lưu vào documents của app (mobile/desktop)
  if (kIsWeb) {
    // web mà FileSaver lỗi thì chỉ báo tên file
    return '$fileName.xlsx';
  }

  final dir = await getApplicationDocumentsDirectory();
  final file = File('${dir.path}/$fileName.xlsx');
  await file.writeAsBytes(bytes, flush: true);

  return file.path;
}
