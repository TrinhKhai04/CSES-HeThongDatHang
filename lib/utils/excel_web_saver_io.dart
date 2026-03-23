// utils/excel_web_saver_io.dart
import 'dart:io';
import 'package:path_provider/path_provider.dart';

Future<String> saveExcelFile(
    List<int> bytes, {
      required String baseName,
    }) async {
  final now = DateTime.now();
  String two(int n) => n.toString().padLeft(2, '0');
  final ts =
      '${now.year}${two(now.month)}${two(now.day)}_${two(now.hour)}${two(now.minute)}';
  final fileName = '${baseName}_$ts.xlsx';

  final dir = await getApplicationDocumentsDirectory(); // thư mục riêng của app
  final path = '${dir.path}/$fileName';

  final file = File(path);
  await file.writeAsBytes(bytes, flush: true);

  return path; // để show trong SnackBar
}
