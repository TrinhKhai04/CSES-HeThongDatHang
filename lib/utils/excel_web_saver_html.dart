// utils/excel_web_saver_html.dart

// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

Future<String> saveExcelFile(
    List<int> bytes, {
      required String baseName,
    }) async {
  final now = DateTime.now();
  String two(int n) => n.toString().padLeft(2, '0');
  final ts =
      '${now.year}${two(now.month)}${two(now.day)}_${two(now.hour)}${two(now.minute)}';
  final fileName = '${baseName}_$ts.xlsx';

  final blob = html.Blob(
    [bytes],
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
  );
  final url = html.Url.createObjectUrlFromBlob(blob);

  final anchor = html.AnchorElement(href: url)
    ..setAttribute('download', fileName)
    ..click();

  html.Url.revokeObjectUrl(url);
  anchor.remove();

  // Web không có path local, trả lại tên file
  return fileName;
}
