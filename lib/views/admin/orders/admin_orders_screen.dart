import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart' as xls; // 👈 alias để tránh trùng Border
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import 'dart:io'; // 👈 để ghi file Excel tạm trên mobile
import 'package:path_provider/path_provider.dart'; // đã khai báo trong pubspec
import 'package:share_plus/share_plus.dart'; // để mở share sheet (Drive, Gmail...)

// 👇 thêm Clipboard, ClipboardData
import 'package:flutter/services.dart' show rootBundle, Clipboard, ClipboardData;

import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart' as pdf;
import 'package:printing/printing.dart';

import '../../../controllers/order_controller.dart';
import '../../../controllers/auth_controller.dart';
import '../../../utils/excel_web_saver.dart'; // <-- KHÔNG dùng result.dart nữa

/// ===================== ENUM + MODEL BỘ LỌC =====================

enum _OrderDateFilter { all, today, last7, last30 }

enum _OrderAmountFilterType { none, greater, less }

class _OrderFilterConfig {
  final _OrderDateFilter dateFilter;
  final _OrderAmountFilterType amountType;
  final double? amountThreshold;

  const _OrderFilterConfig({
    required this.dateFilter,
    required this.amountType,
    required this.amountThreshold,
  });
}

/// ============================================================================
/// 🍏 AdminOrdersScreen – Danh sách đơn hàng (Admin)
/// ============================================================================

class AdminOrdersScreen extends StatefulWidget {
  const AdminOrdersScreen({super.key});

  @override
  State<AdminOrdersScreen> createState() => _AdminOrdersScreenState();
}

class _AdminOrdersScreenState extends State<AdminOrdersScreen> {
  String? _statusFilter; // null = tất cả
  _OrderDateFilter _dateFilter = _OrderDateFilter.all;
  _OrderAmountFilterType _amountType = _OrderAmountFilterType.none;
  double? _amountThreshold;

  Future<void> _openFilterSheet(ColorScheme cs) async {
    final result = await showModalBottomSheet<_OrderFilterConfig>(
      context: context,
      isScrollControlled: true,
      backgroundColor: cs.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return _OrderFilterBottomSheet(
          colorScheme: cs,
          initialDateFilter: _dateFilter,
          initialAmountType: _amountType,
          initialAmountThreshold: _amountThreshold,
        );
      },
    );

    if (result != null) {
      setState(() {
        _dateFilter = result.dateFilter;
        _amountType = result.amountType;
        _amountThreshold = result.amountThreshold;
      });
    }
  }

  bool get _hasActiveFilter {
    if (_dateFilter != _OrderDateFilter.all) return true;
    if (_amountType != _OrderAmountFilterType.none &&
        _amountThreshold != null) return true;
    return false;
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _applyFilters(
      List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
      ) {
    var filtered = List<QueryDocumentSnapshot<Map<String, dynamic>>>.from(docs);

    // Lọc theo trạng thái
    if (_statusFilter != null) {
      filtered = filtered
          .where(
            (d) =>
        (d.data()['status'] ?? 'pending').toString() == _statusFilter,
      )
          .toList();
    }

    final now = DateTime.now();

    // Lọc theo ngày
    filtered = filtered.where((d) {
      if (_dateFilter == _OrderDateFilter.all) return true;

      final dt = _parseTimeAny(d.data()['createdAt']);
      if (dt == null) return true;

      final dayStart = DateTime(dt.year, dt.month, dt.day);
      final todayStart = DateTime(now.year, now.month, now.day);

      switch (_dateFilter) {
        case _OrderDateFilter.today:
          return dayStart == todayStart;
        case _OrderDateFilter.last7:
          return dayStart.isAfter(todayStart.subtract(const Duration(days: 7)));
        case _OrderDateFilter.last30:
          return dayStart
              .isAfter(todayStart.subtract(const Duration(days: 30)));
        case _OrderDateFilter.all:
          return true;
      }
    }).toList();

    // Lọc theo tổng tiền
    if (_amountType != _OrderAmountFilterType.none &&
        _amountThreshold != null) {
      filtered = filtered.where((d) {
        final total = _toDouble(d.data()['total']);
        if (_amountType == _OrderAmountFilterType.greater) {
          return total >= _amountThreshold!;
        } else {
          return total <= _amountThreshold!;
        }
      }).toList();
    }

    return filtered;
  }

  /// 🆕 Fallback mã đơn từ orderId nếu Firestore chưa có field orderCode
  static String _fallbackOrderCode(String orderId) {
    if (orderId.isEmpty) return '';
    final suffix =
    orderId.length <= 6 ? orderId : orderId.substring(orderId.length - 6);
    return 'CSES-$suffix'.toUpperCase();
  }

  /// ================== Xuất danh sách đơn (đã lọc) ra file Excel ==================
  Future<void> _exportOrdersToExcel(
      List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
      ) async {
    final messenger = ScaffoldMessenger.of(context);

    if (docs.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Không có đơn nào để xuất Excel')),
      );
      return;
    }

    // 1. Tạo workbook
    final excel = xls.Excel.createExcel();

    // 👉 Dùng sheet mặc định, đổi tên thành 'Orders'
    final String? defaultSheet = excel.getDefaultSheet();
    if (defaultSheet != null && defaultSheet != 'Orders') {
      excel.rename(defaultSheet, 'Orders');
    }

    // Dùng sheet 'Orders' để ghi dữ liệu
    final sheet = excel['Orders'];

    // Header
    sheet.appendRow([
      xls.TextCellValue('STT'),
      xls.TextCellValue('Mã đơn'),
      xls.TextCellValue('Khách hàng'),
      xls.TextCellValue('Trạng thái'),
      xls.TextCellValue('Thành tiền'),
      xls.TextCellValue('Thời gian tạo'),
    ]);

    // 🎨 Style cho header: in đậm, nền xám nhạt, căn giữa
    final headerStyle = xls.CellStyle(
      bold: true,
      horizontalAlign: xls.HorizontalAlign.Center,
      backgroundColorHex: xls.ExcelColor.grey200,
    );

    for (int col = 0; col < 6; col++) {
      final cell = sheet.cell(
        xls.CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 0),
      );
      cell.cellStyle = headerStyle;
    }

    // 2. Ghi từng dòng
    for (int i = 0; i < docs.length; i++) {
      final d = docs[i];
      final data = d.data();
      final orderId = d.id;

      // 🆕 Lấy orderCode (hoặc fallback)
      final rawCode = (data['orderCode'] ?? '').toString().trim();
      final orderCode =
      rawCode.isNotEmpty ? rawCode : _fallbackOrderCode(orderId);

      final customerId = (data['customerId'] ?? '').toString();
      final status = (data['status'] ?? 'pending').toString();
      final total = _toDouble(data['total']);
      final createdAtText = _fmtTimeAny(data['createdAt']);

      sheet.appendRow([
        xls.IntCellValue(i + 1),
        xls.TextCellValue(orderCode),
        xls.TextCellValue(customerId),
        xls.TextCellValue(_viLabel(status)),
        xls.DoubleCellValue(total.toDouble()),
        xls.TextCellValue(createdAtText),
      ]);
    }

    // 2b. Thêm dòng "Tổng" ở cuối
    final int dataStartRow = 2; // dòng data đầu (E2)
    final int dataEndRow = docs.length + 1; // dòng data cuối (header = 1)

    sheet.appendRow([
      xls.TextCellValue(''),
      xls.TextCellValue(''),
      xls.TextCellValue(''),
      xls.TextCellValue('Tổng'),
      xls.FormulaCellValue('SUM(E$dataStartRow:E$dataEndRow)'),
      xls.TextCellValue(''),
    ]);

    // Style cho dòng tổng: in đậm, căn phải
    final totalRowIndex = docs.length + 1; // 0-based
    final totalLabelCell = sheet.cell(
      xls.CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: totalRowIndex),
    );
    final totalValueCell = sheet.cell(
      xls.CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: totalRowIndex),
    );
    final totalStyle = xls.CellStyle(
      bold: true,
      horizontalAlign: xls.HorizontalAlign.Right,
    );
    totalLabelCell.cellStyle = totalStyle;
    totalValueCell.cellStyle = totalStyle;

    // 3. Encode Excel thành bytes
    final bytes = excel.encode();
    if (bytes == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Lỗi mã hóa file Excel')),
      );
      return;
    }

    // 4. Web: tải file bình thường | Mobile: mở share sheet (Drive, Gmail...)
    try {
      if (kIsWeb) {
        // 🌐 WEB: dùng helper cũ để tải file
        final String savedInfo =
        await saveExcelFile(bytes, baseName: 'cses_orders');

        messenger.showSnackBar(
          SnackBar(content: Text('Đã xuất Excel: $savedInfo')),
        );
      } else {
        // 📱 MOBILE: ghi file tạm rồi share
        final now = DateTime.now();
        String two(int n) => n.toString().padLeft(2, '0');
        final fileName =
            'cses_orders_${now.year}${two(now.month)}${two(now.day)}_${two(now.hour)}${two(now.minute)}.xlsx';

        final dir = await getTemporaryDirectory();
        final file = File('${dir.path}/$fileName');
        await file.writeAsBytes(bytes, flush: true);

        await Share.shareXFiles(
          [
            XFile(
              file.path,
              name: fileName,
              mimeType:
              'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
            ),
          ],
          text: 'Danh sách đơn hàng CSES (Excel)',
          subject: 'Danh sách đơn hàng CSES',
        );

        messenger.showSnackBar(
          SnackBar(content: Text('Đã xuất Excel: $fileName')),
        );
      }
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Lỗi lưu / chia sẻ Excel: $e')),
      );
    }
  }

  /// ================== Xuất danh sách đơn (đã lọc) ra PDF ==================
  Future<void> _exportOrdersToPdf(
      List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
      String exportedBy,
      ) async {
    final messenger = ScaffoldMessenger.of(context);

    if (docs.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Không có đơn nào để xuất PDF')),
      );
      return;
    }

    try {
      // 1️⃣ Font tiếng Việt
      final regularData =
      await rootBundle.load('assets/fonts/Roboto-Regular.ttf');
      final boldData = await rootBundle.load('assets/fonts/Roboto-Bold.ttf');

      final fontRegular = pw.Font.ttf(regularData);
      final fontBold = pw.Font.ttf(boldData);

      // 2️⃣ Logo CSES
      final logoImage =
      await imageFromAssetBundle('assets/images/cses_logo.png');

      final pdfDoc = pw.Document(
        theme: pw.ThemeData.withFont(
          base: fontRegular,
          bold: fontBold,
        ),
      );

      final now = DateTime.now();
      String two(int n) => n.toString().padLeft(2, '0');

      final String dateStr =
          '${two(now.day)}/${two(now.month)}/${now.year}';
      final String timeStr = '${two(now.hour)}:${two(now.minute)}';
      final String exportedAt = '$timeStr · $dateStr';

      // 3️⃣ Chuẩn bị data + tính doanh thu theo trạng thái & đếm số lượng
      final List<List<String>> tableRows = [];

      num totalDone = 0; // chỉ đơn Hoàn tất
      num totalOpen = 0; // pending + processing + shipping
      num totalCancelled = 0; // đã huỷ

      int countPending = 0;
      int countProcessing = 0;
      int countShipping = 0;
      int countDone = 0;
      int countCancelled = 0;

      for (int i = 0; i < docs.length; i++) {
        final d = docs[i];
        final data = d.data();
        final orderId = d.id;

        // 🆕 lấy mã đơn
        final rawCode = (data['orderCode'] ?? '').toString().trim();
        final orderCode =
        rawCode.isNotEmpty ? rawCode : _fallbackOrderCode(orderId);

        final customerId = (data['customerId'] ?? '').toString();
        final status = (data['status'] ?? 'pending').toString();
        final total = _toDouble(data['total']);
        final createdAtText = _fmtTimeAny(data['createdAt']);

        // rút gọn mã đơn cho đẹp trong bảng
        final displayOrderCode =
        orderCode.length > 18 ? '${orderCode.substring(0, 18)}…' : orderCode;

        // cộng tiền & số lượng
        switch (status) {
          case 'done':
            totalDone += total;
            countDone++;
            break;
          case 'pending':
            totalOpen += total;
            countPending++;
            break;
          case 'processing':
            totalOpen += total;
            countProcessing++;
            break;
          case 'shipping':
            totalOpen += total;
            countShipping++;
            break;
          case 'cancelled':
            totalCancelled += total;
            countCancelled++;
            break;
          default:
            break;
        }

        tableRows.add([
          (i + 1).toString(), // STT
          displayOrderCode, // 🆕 Mã đơn
          customerId, // Khách hàng
          _viLabel(status), // Trạng thái
          _vnd(total), // Thành tiền
          createdAtText, // Thời gian
        ]);
      }

      final openLabelValue = _vnd(totalOpen);
      final doneLabelValue = _vnd(totalDone);
      final cancelledLabelValue = _vnd(totalCancelled);

      // 4️⃣ MultiPage
      pdfDoc.addPage(
        pw.MultiPage(
          pageFormat: pdf.PdfPageFormat.a4,
          margin: const pw.EdgeInsets.fromLTRB(26, 26, 26, 24),
          footer: (context) => pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'CSES · Báo cáo đơn hàng',
                style: const pw.TextStyle(fontSize: 9),
              ),
              pw.Text(
                'Trang ${context.pageNumber} / ${context.pagesCount}',
                style: const pw.TextStyle(fontSize: 9),
              ),
            ],
          ),
          build: (context) {
            return [
              // ───────── HEADER: logo + mã báo cáo ─────────
              pw.Container(
                padding: const pw.EdgeInsets.only(bottom: 8),
                decoration: const pw.BoxDecoration(
                  border: pw.Border(
                    bottom: pw.BorderSide(
                      color: pdf.PdfColors.grey300,
                      width: 0.6,
                    ),
                  ),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    // Logo + tên hệ thống
                    pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.center,
                      children: [
                        pw.Container(
                          width: 40,
                          height: 40,
                          decoration: pw.BoxDecoration(
                            color: pdf.PdfColor.fromHex('#e6f0ff'),
                            borderRadius: pw.BorderRadius.circular(12),
                          ),
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Center(
                            child: pw.Image(
                              logoImage,
                              fit: pw.BoxFit.contain,
                            ),
                          ),
                        ),
                        pw.SizedBox(width: 10),
                        pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(
                              'Báo cáo đơn hàng',
                              style: pw.TextStyle(
                                fontSize: 13,
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    // Mã báo cáo + thời gian in
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text(
                          'Mã báo cáo: CSES-ORD-${now.year}${two(now.month)}${two(now.day)}',
                          style: pw.TextStyle(
                            fontSize: 9,
                            color: pdf.PdfColors.grey700,
                          ),
                        ),
                        pw.Text(
                          'In lúc: $exportedAt',
                          style: pw.TextStyle(
                            fontSize: 9,
                            color: pdf.PdfColors.grey700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 14),

              // ───────── TIÊU ĐỀ CHÍNH ─────────
              pw.Center(
                child: pw.Text(
                  'DANH SÁCH ĐƠN HÀNG CSES',
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.SizedBox(height: 12),

              // ───────── Thông tin báo cáo + Thời gian xuất ─
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    flex: 3,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'Thông tin báo cáo',
                          style: pw.TextStyle(
                            fontSize: 11,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          '• Tổng số đơn: ${docs.length}',
                          style: const pw.TextStyle(fontSize: 10),
                        ),
                        pw.Text(
                          '• Người xuất: $exportedBy',
                          style: const pw.TextStyle(fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                  pw.SizedBox(width: 12),
                  pw.Expanded(
                    flex: 2,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text(
                          'Thời gian xuất',
                          style: pw.TextStyle(
                            fontSize: 11,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          'Ngày: $dateStr',
                          style: const pw.TextStyle(fontSize: 10),
                        ),
                        pw.Text(
                          'Giờ:  $timeStr',
                          style: const pw.TextStyle(fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 12),

              // ───────── CARD TỔNG QUAN DOANH THU ─────────
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  borderRadius: pw.BorderRadius.circular(18),
                  border: pw.Border.all(
                    color: pdf.PdfColors.grey300,
                    width: 0.8,
                  ),
                  color: pdf.PdfColors.grey100,
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Tổng quan doanh thu',
                      style: pw.TextStyle(
                        fontSize: 11,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      '• Doanh thu đã ghi nhận (đơn Hoàn tất): $doneLabelValue',
                      style: const pw.TextStyle(fontSize: 10),
                    ),
                    pw.Text(
                      '• Giá trị đơn đang xử lý (Chờ xác nhận / Đang xử lý / Đang giao): $openLabelValue',
                      style: const pw.TextStyle(fontSize: 10),
                    ),
                    if (totalCancelled > 0)
                      pw.Text(
                        '• Giá trị đơn đã hủy: $cancelledLabelValue',
                        style: const pw.TextStyle(fontSize: 10),
                      ),
                    pw.SizedBox(height: 6),
                    pw.Text(
                      'Số lượng đơn theo từng trạng thái:',
                      style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      '• Chờ xác nhận: $countPending · Đang xử lý: $countProcessing · Đang giao: $countShipping',
                      style: const pw.TextStyle(fontSize: 10),
                    ),
                    pw.Text(
                      '• Hoàn tất: $countDone · Đã hủy: $countCancelled',
                      style: const pw.TextStyle(fontSize: 10),
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 16),

              // ───────── BẢNG DỮ LIỆU ─────────
              pw.Table.fromTextArray(
                headerStyle: pw.TextStyle(
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                ),
                cellStyle: const pw.TextStyle(fontSize: 9),
                headerDecoration: pw.BoxDecoration(
                  color: pdf.PdfColors.grey300,
                ),
                oddRowDecoration: pw.BoxDecoration(
                  color: pdf.PdfColors.grey100,
                ),
                rowDecoration: const pw.BoxDecoration(
                  color: pdf.PdfColors.white,
                ),
                border: pw.TableBorder.all(
                  color: pdf.PdfColors.grey400,
                  width: 0.6,
                ),
                cellAlignment: pw.Alignment.centerLeft,
                cellAlignments: {
                  0: pw.Alignment.center,
                  4: pw.Alignment.centerRight,
                },
                columnWidths: {
                  0: const pw.FlexColumnWidth(0.7), // STT
                  1: const pw.FlexColumnWidth(1.9), // Mã đơn
                  2: const pw.FlexColumnWidth(2.3), // Khách hàng
                  3: const pw.FlexColumnWidth(1.3), // Trạng thái
                  4: const pw.FlexColumnWidth(1.4), // Thành tiền
                  5: const pw.FlexColumnWidth(1.6), // Thời gian
                },
                cellPadding: const pw.EdgeInsets.symmetric(
                  horizontal: 4,
                  vertical: 4,
                ),
                headerPadding: const pw.EdgeInsets.symmetric(
                  horizontal: 4,
                  vertical: 6,
                ),
                headers: const [
                  'STT',
                  'Mã đơn',
                  'Khách hàng',
                  'Trạng thái',
                  'Thành tiền',
                  'Thời gian',
                ],
                data: tableRows,
              ),

              pw.SizedBox(height: 24),

              // ───────── CHỖ KÝ TÊN ─────────
              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Text(
                      'Ngày $dateStr',
                      style: const pw.TextStyle(fontSize: 10),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'NGƯỜI LẬP BÁO CÁO',
                      style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      '(Ký, ghi rõ họ tên)',
                      style: pw.TextStyle(
                        fontSize: 9,
                        color: pdf.PdfColors.grey600,
                      ),
                    ),
                    pw.SizedBox(height: 32),
                    pw.Container(
                      width: 150,
                      decoration: pw.BoxDecoration(
                        border: pw.Border(
                          bottom: pw.BorderSide(
                            color: pdf.PdfColors.grey700,
                            width: 0.7,
                          ),
                        ),
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      exportedBy,
                      style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ];
          },
        ),
      );

      final bytes = await pdfDoc.save();

      final fileName =
          'cses_orders_${now.year}${two(now.month)}${two(now.day)}_${two(now.hour)}${two(now.minute)}.pdf';

      if (kIsWeb) {
        await Printing.layoutPdf(
          onLayout: (_) async => bytes,
          name: fileName,
        );
      } else {
        await Printing.sharePdf(bytes: bytes, filename: fileName);
      }

      messenger.showSnackBar(
        SnackBar(content: Text('Đã tạo PDF: $fileName')),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Lỗi xuất PDF: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final parentContext = context;

    // 🔐 Lấy thông tin người đang đăng nhập để ghi "Người xuất"
    final auth = context.watch<AuthController>();
    final profile = auth.profile; // Map<String, dynamic>?

    final exportedBy = (profile != null
        ? (profile['fullName'] ??
        profile['displayName'] ??
        profile['name'])
        : null) ??
        auth.user?.email ??
        'Admin';

    // 🔥 Lấy toàn bộ đơn hàng mới nhất từ Firestore (realtime)
    final ordersRef = FirebaseFirestore.instance
        .collection('orders')
        .orderBy('createdAt', descending: true);

    return Scaffold(
      backgroundColor:
      CupertinoColors.systemGroupedBackground.resolveFrom(context),
      appBar: AppBar(
        backgroundColor: cs.surface,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: cs.onSurface),
        titleSpacing: 0,
        title: Text(
          'Đơn hàng (Admin)',
          style: TextStyle(
            color: cs.onSurface,
            fontWeight: FontWeight.w700,
            fontSize: 18,
            letterSpacing: -0.3,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Rebuild soldCount',
            icon: const Icon(CupertinoIcons.arrow_2_squarepath),
            onPressed: () async {
              final ctl = parentContext.read<OrderController>();
              final messenger = ScaffoldMessenger.of(parentContext);
              final navigator =
              Navigator.of(parentContext, rootNavigator: true);

              showCupertinoDialog(
                context: parentContext,
                builder: (_) => const Center(
                  child: CupertinoActivityIndicator(),
                ),
              );

              try {
                await ctl.rebuildSoldCountFromOrders();
                if (navigator.canPop()) navigator.pop();
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text('Đã rebuild soldCount từ lịch sử đơn'),
                  ),
                );
              } catch (e) {
                if (navigator.canPop()) navigator.pop();
                messenger.showSnackBar(
                  SnackBar(content: Text('Lỗi rebuild: $e')),
                );
              }
            },
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(
            height: 1,
            thickness: 1,
            color: cs.outlineVariant.withOpacity(0.6),
          ),
        ),
      ),

      // ⚡ Lắng nghe thay đổi realtime
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: ordersRef.snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CupertinoActivityIndicator());
          }
          if (snap.hasError) {
            return Center(
              child: Text(
                'Lỗi: ${snap.error}',
                style: TextStyle(color: cs.error),
              ),
            );
          }
          if (!snap.hasData || snap.data!.docs.isEmpty) {
            return Center(
              child: Text(
                'Chưa có đơn hàng',
                style: TextStyle(color: cs.onSurfaceVariant),
              ),
            );
          }

          final docs = snap.data!.docs;
          final filteredDocs = _applyFilters(docs);

          return Column(
            children: [
              const SizedBox(height: 8),
              _buildFilterChipsRow(cs),

              // 👉 Hàng tổng số đơn + nút Xuất Excel/PDF
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                child: Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Tổng: ${filteredDocs.length} đơn',
                          style: TextStyle(
                            fontSize: 12,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Xuất theo bộ lọc hiện tại',
                          style: TextStyle(
                            fontSize: 11,
                            color: cs.onSurfaceVariant.withOpacity(0.7),
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _ExportPillButton(
                          label: 'Excel',
                          icon: Icons.table_view_rounded,
                          foreground: cs.primary,
                          background: cs.primary.withOpacity(0.06),
                          borderColor: cs.primary.withOpacity(0.18),
                          onTap: () => _exportOrdersToExcel(filteredDocs),
                        ),
                        const SizedBox(width: 8),
                        _ExportPillButton(
                          label: 'PDF',
                          icon: Icons.picture_as_pdf_rounded,
                          foreground: cs.error,
                          background: cs.error.withOpacity(0.05),
                          borderColor: cs.error.withOpacity(0.25),
                          onTap: () =>
                              _exportOrdersToPdf(filteredDocs, exportedBy),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 4),
              Expanded(
                child: filteredDocs.isEmpty
                    ? Center(
                  child: Text(
                    'Không có đơn phù hợp bộ lọc',
                    style: TextStyle(color: cs.onSurfaceVariant),
                  ),
                )
                    : ListView.separated(
                  padding:
                  const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  separatorBuilder: (_, __) =>
                  const SizedBox(height: 12),
                  itemCount: filteredDocs.length,
                  itemBuilder: (_, i) {
                    final doc = filteredDocs[i];
                    return _buildOrderCard(
                      doc: doc,
                      cs: cs,
                      isDark: isDark,
                      parentContext: parentContext,
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Hàng các chip: Bộ lọc + Tất cả / Chờ xác nhận / ...
  Widget _buildFilterChipsRow(ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            // Chip Bộ lọc (slider icon)
            _buildFilterPill(
              cs: cs,
              selected: _hasActiveFilter,
              onTap: () => _openFilterSheet(cs),
            ),
            const SizedBox(width: 10),

            // Các chip trạng thái
            _buildStatusPill(
              cs: cs,
              label: 'Tất cả',
              selected: _statusFilter == null,
              onTap: () => setState(() => _statusFilter = null),
            ),
            const SizedBox(width: 6),
            _buildStatusPill(
              cs: cs,
              label: 'Chờ xác nhận',
              selected: _statusFilter == 'pending',
              onTap: () => setState(() => _statusFilter = 'pending'),
            ),
            const SizedBox(width: 6),
            _buildStatusPill(
              cs: cs,
              label: 'Đang xử lý',
              selected: _statusFilter == 'processing',
              onTap: () => setState(() => _statusFilter = 'processing'),
            ),
            const SizedBox(width: 6),
            _buildStatusPill(
              cs: cs,
              label: 'Đang giao',
              selected: _statusFilter == 'shipping',
              onTap: () => setState(() => _statusFilter = 'shipping'),
            ),
            const SizedBox(width: 6),
            _buildStatusPill(
              cs: cs,
              label: 'Hoàn tất',
              selected: _statusFilter == 'done',
              onTap: () => setState(() => _statusFilter = 'done'),
            ),
            const SizedBox(width: 6),
            _buildStatusPill(
              cs: cs,
              label: 'Đã hủy',
              selected: _statusFilter == 'cancelled',
              onTap: () => setState(() => _statusFilter = 'cancelled'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterPill({
    required ColorScheme cs,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final bg =
    selected ? cs.primaryContainer : cs.surfaceVariant.withOpacity(0.9);
    final fg = selected ? cs.onPrimaryContainer : cs.onSurface;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          children: [
            Icon(
              CupertinoIcons.slider_horizontal_3,
              size: 16,
              color: fg,
            ),
            const SizedBox(width: 6),
            Text(
              'Bộ lọc',
              style: TextStyle(
                color: fg,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 2),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 16,
              color: fg,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusPill({
    required ColorScheme cs,
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final bg = selected ? cs.primary.withOpacity(0.14) : Colors.transparent;
    final borderColor =
    selected ? Colors.transparent : cs.outlineVariant.withOpacity(0.8);
    final fg = selected ? cs.primary : cs.onSurfaceVariant;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: borderColor, width: 0.7),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: fg,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  /// ========================================================================
  /// Card đơn hàng – style giống màn “Đơn đã mua”
  /// ========================================================================
  static Widget _buildOrderCard({
    required QueryDocumentSnapshot<Map<String, dynamic>> doc,
    required ColorScheme cs,
    required bool isDark,
    required BuildContext parentContext,
  }) {
    final data = doc.data();
    final orderId = doc.id;

    // 🆕 lấy mã đơn để hiển thị & copy
    final rawCode = (data['orderCode'] ?? '').toString().trim();
    final orderCode = rawCode.isNotEmpty
        ? rawCode
        : _AdminOrdersScreenState._fallbackOrderCode(orderId);

    // Thông tin cơ bản
    final customerId = (data['customerId'] ?? '').toString();
    final status = (data['status'] ?? 'pending').toString();

    final total = _toDouble(data['total']);
    final createdAtText = _fmtTimeAny(data['createdAt']);

    final isTerminal = status == 'done' || status == 'cancelled';
    final nexts = _nextOptions(status);

    // rút gọn mã Firestore để đặt tiêu đề
    final String shortId =
    orderId.length > 12 ? '${orderId.substring(0, 8)}…' : orderId;

    final screenWidth = MediaQuery.of(parentContext).size.width;
    final bool isCompact = screenWidth < 360;

    // ⚙️ Hàm đổi trạng thái
    Future<void> _handleChangeStatus(String newStatus) async {
      final orderController = parentContext.read<OrderController>();
      final messenger = ScaffoldMessenger.of(parentContext);
      final navigator =
      Navigator.of(parentContext, rootNavigator: true);

      if (newStatus == status) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Đã ở trạng thái này rồi')),
        );
        return;
      }

      showCupertinoDialog(
        context: parentContext,
        builder: (_) => const Center(
          child: CupertinoActivityIndicator(),
        ),
      );

      String? err;
      bool ok = false;
      try {
        ok = await orderController.adminUpdateStatusGuarded(
          orderId: orderId,
          customerId: customerId,
          newStatus: newStatus,
        );
      } catch (e) {
        err = e.toString();
      } finally {
        if (navigator.canPop()) navigator.pop();
      }

      messenger.showSnackBar(
        SnackBar(
          content: Text(
            ok
                ? '✅ Đã đổi sang: ${_viLabel(newStatus)}'
                : (err ??
                '❌ Không thể đổi trạng thái (đơn đã kết thúc hoặc có ràng buộc).'),
          ),
        ),
      );
    }

    final statusColor = _statusColor(status);

    return Container(
      decoration: _cardDecoration(cs, isDark),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ───────── HEADER: Đơn + trạng thái ─────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: cs.primary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    CupertinoIcons.bag_fill,
                    size: 15,
                    color: cs.primary,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Đơn #$shortId',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: cs.onSurface,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                if (isTerminal || nexts.isEmpty)
                  _StatusChip(
                    status: status,
                    colorScheme: cs,
                    isDark: isDark,
                  )
                else
                  _StatusChipDropdown(
                    status: status,
                    nextStatuses: nexts,
                    colorScheme: cs,
                    isDark: isDark,
                    onChanged: _handleChangeStatus,
                  ),
              ],
            ),
            const SizedBox(height: 6),

            // 🆕 Hàng “Mã đơn” + icon copy
            Row(
              children: [
                Icon(
                  CupertinoIcons.number,
                  size: 14,
                  color: cs.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    orderCode,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: () async {
                    await Clipboard.setData(
                      ClipboardData(text: orderCode),
                    );
                    ScaffoldMessenger.of(parentContext).showSnackBar(
                      const SnackBar(content: Text('Đã copy mã đơn')),
                    );
                  },
                  child: Icon(
                    CupertinoIcons.doc_on_clipboard,
                    size: 16,
                    color: cs.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),

            // thời gian + id khách
            Row(
              children: [
                Icon(
                  CupertinoIcons.time,
                  size: 14,
                  color: cs.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    createdAtText,
                    style: TextStyle(
                      fontSize: 12,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  CupertinoIcons.person,
                  size: 14,
                  color: cs.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    customerId,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Divider(color: cs.outlineVariant.withOpacity(0.6)),
            const SizedBox(height: 8),

            // ───────── Thành tiền + mô tả trạng thái ─────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Thành tiền',
                      style: TextStyle(
                        fontSize: 12,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _vnd(total),
                      style: TextStyle(
                        fontSize: isCompact ? 18 : 20,
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Flexible(
                  child: Text(
                    _statusDescription(status),
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: 12,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // ───────── Hàng "Xem chi tiết" ─────────
            InkWell(
              onTap: () {
                Navigator.pushNamed(
                  parentContext,
                  '/admin/order_detail',
                  arguments: {
                    'orderId': orderId,
                    'customerId': customerId,
                  },
                );
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Icon(
                      CupertinoIcons.doc_text_search,
                      size: 18,
                      color: cs.primary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Xem chi tiết',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: cs.primary,
                      ),
                    ),
                    const Spacer(),
                    Icon(
                      CupertinoIcons.chevron_right,
                      size: 16,
                      color: cs.primary,
                    ),
                  ],
                ),
              ),
            ),

            // ───────── Nút Hủy đơn (nếu đang chờ) ─────────
            if (status == 'pending') ...[
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 6),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    backgroundColor: const Color(0xFFFFE5E7),
                    foregroundColor: const Color(0xFFFF3B30),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  onPressed: () => _handleChangeStatus('cancelled'),
                  icon: const Icon(
                    CupertinoIcons.xmark_circle,
                    size: 16,
                  ),
                  label: const Text(
                    'Hủy đơn',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ===== Helper parse & format =====

  static double _toDouble(dynamic x) =>
      x is num ? x.toDouble() : double.tryParse('$x') ?? 0.0;

  static DateTime? _parseTimeAny(dynamic raw) {
    if (raw == null) return null;

    if (raw is Timestamp) return raw.toDate();
    if (raw is DateTime) return raw;
    if (raw is int) {
      return DateTime.fromMillisecondsSinceEpoch(raw);
    }
    if (raw is num) {
      return DateTime.fromMillisecondsSinceEpoch(raw.toInt());
    }
    final parsed = int.tryParse('$raw');
    if (parsed == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(parsed);
  }

  static String _fmtTimeAny(dynamic raw) {
    final dt = _parseTimeAny(raw);
    if (dt == null) return '';

    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(dt.hour)}:${two(dt.minute)} · '
        '${two(dt.day)}/${two(dt.month)}/${dt.year}';
  }

  // ===== Trợ giúp chuyển trạng thái =====
  static List<String> _nextOptions(String current) {
    switch (current) {
      case 'pending':
        return const ['processing', 'cancelled'];
      case 'processing':
        return const ['shipping', 'cancelled'];
      case 'shipping':
        return const ['done'];
      default:
        return const [];
    }
  }

  // ===== Nhãn tiếng Việt =====
  static String _viLabel(String s) {
    switch (s) {
      case 'pending':
        return 'Chờ xác nhận';
      case 'processing':
        return 'Đang xử lý';
      case 'shipping':
        return 'Đang giao';
      case 'done':
        return 'Hoàn tất';
      case 'cancelled':
        return 'Đã hủy';
      default:
        return s;
    }
  }

  // ===== Mô tả dài cho trạng thái (hiển thị bên phải thành tiền) =====
  static String _statusDescription(String s) {
    switch (s) {
      case 'pending':
        return 'Đơn đang chờ xác nhận...';
      case 'processing':
        return 'Đang xử lý đơn hàng...';
      case 'shipping':
        return 'Đơn đang được giao đến khách...';
      case 'done':
        return 'Đơn hàng đã hoàn tất.';
      case 'cancelled':
        return 'Đơn hàng đã bị hủy.';
      default:
        return '';
    }
  }

  // ===== Format tiền tệ (₫ có dấu phẩy ngăn 3 số) =====
  static String _vnd(num value) {
    final s = value.toStringAsFixed(0);
    final buffer = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      final rev = s.length - i;
      buffer.write(s[i]);
      if (rev > 1 && rev % 3 == 1) buffer.write(',');
    }
    return '₫${buffer.toString()}';
  }

  // ===== Card decoration theo theme =====
  static BoxDecoration _cardDecoration(ColorScheme cs, bool isDark) {
    return BoxDecoration(
      color: cs.surface,
      borderRadius: BorderRadius.circular(20),
      boxShadow: isDark
          ? [
        BoxShadow(
          color: Colors.black.withOpacity(0.25),
          blurRadius: 12,
          offset: const Offset(0, 5),
        ),
      ]
          : [
        BoxShadow(
          color: Colors.black.withOpacity(0.05),
          blurRadius: 12,
          offset: const Offset(0, 5),
        ),
      ],
      border: Border.all(
        color: cs.outlineVariant.withOpacity(0.5),
        width: 0.7,
      ),
    );
  }
}

// ============================================================================
// 🍏 Chip trạng thái — view-only
// ============================================================================

class _StatusChip extends StatelessWidget {
  final String status;
  final ColorScheme colorScheme;
  final bool isDark;
  const _StatusChip({
    required this.status,
    required this.colorScheme,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final fg = _statusColor(status);
    final bg = fg.withOpacity(isDark ? 0.22 : 0.12);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        _AdminOrdersScreenState._viLabel(status),
        style: TextStyle(
          color: fg,
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
      ),
    );
  }
}

// ============================================================================
// 🍏 Chip trạng thái có dropdown — bấm vào chip để đổi trạng thái
// ============================================================================

class _StatusChipDropdown extends StatelessWidget {
  final String status;
  final List<String> nextStatuses;
  final ColorScheme colorScheme;
  final bool isDark;
  final ValueChanged<String> onChanged;

  const _StatusChipDropdown({
    required this.status,
    required this.nextStatuses,
    required this.colorScheme,
    required this.isDark,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final fg = _statusColor(status);
    final bg = fg.withOpacity(isDark ? 0.22 : 0.12);

    return PopupMenuButton<String>(
      tooltip: 'Đổi trạng thái',
      color: colorScheme.surface,
      surfaceTintColor: colorScheme.surfaceTint,
      elevation: 10,
      offset: const Offset(0, 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      onSelected: onChanged,
      itemBuilder: (_) => nextStatuses.map((s) {
        final c = _statusColor(s);
        final label = _AdminOrdersScreenState._viLabel(s);
        return PopupMenuItem<String>(
          value: s,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: c,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: colorScheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: fg.withOpacity(0.5),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: fg,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              _AdminOrdersScreenState._viLabel(status),
              style: TextStyle(
                color: fg,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 18,
              color: colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

// ===== Màu trạng thái theo Apple pastel =====
Color _statusColor(String s) {
  switch (s) {
    case 'done':
      return const Color(0xFF34C759); // xanh Apple
    case 'cancelled':
      return const Color(0xFFFF3B30); // đỏ Apple
    case 'pending':
      return const Color(0xFFFF9500); // cam Apple
    case 'processing':
      return const Color(0xFF5AC8FA); // xanh dương nhạt
    case 'shipping':
      return const Color(0xFF007AFF); // xanh dương Apple
    default:
      return Colors.grey;
  }
}

/// ============================================================================
/// 🎚 Bottom sheet “Bộ lọc” – kiểu YouTube Studio
/// ============================================================================

class _OrderFilterBottomSheet extends StatefulWidget {
  final ColorScheme colorScheme;
  final _OrderDateFilter initialDateFilter;
  final _OrderAmountFilterType initialAmountType;
  final double? initialAmountThreshold;

  const _OrderFilterBottomSheet({
    required this.colorScheme,
    required this.initialDateFilter,
    required this.initialAmountType,
    required this.initialAmountThreshold,
  });

  @override
  State<_OrderFilterBottomSheet> createState() =>
      _OrderFilterBottomSheetState();
}

class _OrderFilterBottomSheetState extends State<_OrderFilterBottomSheet> {
  late _OrderDateFilter _dateFilter;
  late _OrderAmountFilterType _amountType;
  late TextEditingController _amountController;

  @override
  void initState() {
    super.initState();
    _dateFilter = widget.initialDateFilter;
    _amountType = widget.initialAmountType;
    _amountController = TextEditingController(
      text: widget.initialAmountThreshold != null
          ? widget.initialAmountThreshold!.toStringAsFixed(0)
          : '',
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  void _reset() {
    setState(() {
      _dateFilter = _OrderDateFilter.all;
      _amountType = _OrderAmountFilterType.none;
      _amountController.text = '';
    });
  }

  void _apply() {
    final raw = _amountController.text.trim();
    double? threshold;
    if (raw.isNotEmpty) {
      final clean = raw.replaceAll('.', '').replaceAll(',', '');
      threshold = double.tryParse(clean);
    }

    final cfg = _OrderFilterConfig(
      dateFilter: _dateFilter,
      amountType:
      (threshold == null) ? _OrderAmountFilterType.none : _amountType,
      amountThreshold: threshold,
    );
    Navigator.of(context).pop(cfg);
  }

  @override
  Widget build(BuildContext context) {
    final cs = widget.colorScheme;
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // drag handle
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: cs.outlineVariant,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Bộ lọc',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: _reset,
                      child: const Text(
                        'Đặt lại',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Divider(color: cs.outlineVariant),

                // ----- Khoảng thời gian -----
                const SizedBox(height: 8),
                const Text(
                  'Khoảng thời gian',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                RadioListTile<_OrderDateFilter>(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Tất cả'),
                  value: _OrderDateFilter.all,
                  groupValue: _dateFilter,
                  onChanged: (v) => setState(() => _dateFilter = v!),
                ),
                RadioListTile<_OrderDateFilter>(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Hôm nay'),
                  value: _OrderDateFilter.today,
                  groupValue: _dateFilter,
                  onChanged: (v) => setState(() => _dateFilter = v!),
                ),
                RadioListTile<_OrderDateFilter>(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('7 ngày qua'),
                  value: _OrderDateFilter.last7,
                  groupValue: _dateFilter,
                  onChanged: (v) => setState(() => _dateFilter = v!),
                ),
                RadioListTile<_OrderDateFilter>(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('30 ngày qua'),
                  value: _OrderDateFilter.last30,
                  groupValue: _dateFilter,
                  onChanged: (v) => setState(() => _dateFilter = v!),
                ),

                const SizedBox(height: 12),
                Divider(color: cs.outlineVariant),

                // ----- Tổng tiền -----
                const SizedBox(height: 8),
                const Text(
                  'Tổng tiền (₫)',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                RadioListTile<_OrderAmountFilterType>(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Không lọc theo tổng tiền'),
                  value: _OrderAmountFilterType.none,
                  groupValue: _amountType,
                  onChanged: (v) => setState(() => _amountType = v!),
                ),
                RadioListTile<_OrderAmountFilterType>(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Nhiều hơn'),
                  value: _OrderAmountFilterType.greater,
                  groupValue: _amountType,
                  onChanged: (v) => setState(() => _amountType = v!),
                ),
                RadioListTile<_OrderAmountFilterType>(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Ít hơn'),
                  value: _OrderAmountFilterType.less,
                  groupValue: _amountType,
                  onChanged: (v) => setState(() => _amountType = v!),
                ),
                const SizedBox(height: 4),
                TextField(
                  controller: _amountController,
                  keyboardType:
                  const TextInputType.numberWithOptions(decimal: false),
                  decoration: InputDecoration(
                    labelText: 'Nhập một số (vd: 1000000)',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    isDense: true,
                  ),
                ),

                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: cs.primary,
                      foregroundColor: cs.onPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    onPressed: _apply,
                    child: const Text(
                      'Áp dụng',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// 🎯 Pill button Excel / PDF
// ============================================================================

class _ExportPillButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color foreground;
  final Color background;
  final Color borderColor;
  final VoidCallback onTap;

  const _ExportPillButton({
    required this.label,
    required this.icon,
    required this.foreground,
    required this.background,
    required this.borderColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: background,
      borderRadius: BorderRadius.circular(999),
      elevation: 0,
      shadowColor: Colors.black.withOpacity(0.05),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 6,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: borderColor, width: 0.7),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 16,
                color: foreground,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: foreground,
                  letterSpacing: -0.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
