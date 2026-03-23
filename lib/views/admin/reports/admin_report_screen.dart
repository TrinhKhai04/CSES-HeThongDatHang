import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart' as xls;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart' as pdf;
import 'package:share_plus/share_plus.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';

import '../../../controllers/auth_controller.dart';
import '../../../utils/excel_web_saver.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// =============================================================================
/// 🍏 AdminReportScreen – Apple style dashboard (Dark/Light aware)
/// =============================================================================
class AdminReportScreen extends StatefulWidget {
  const AdminReportScreen({super.key});
  @override
  State<AdminReportScreen> createState() => _AdminReportScreenState();
}

class _AdminReportScreenState extends State<AdminReportScreen> {
  // ── Trạng thái tải dữ liệu
  bool loading = true;

  // ── Số liệu tổng quan
  int userCount = 0;
  int productCount = 0;
  int orderCount = 0;
  double totalRevenue = 0;

  // ── Breakdowns cho biểu đồ
  Map<String, double> monthlyRevenue = {}; // 'T1'..'T12' -> doanh thu
  Map<String, int> orderStatus = {}; // 'status' -> số đơn
  Map<String, double> dailyRevenue = {}; // 'dd/MM' -> doanh thu

  // ── So sánh kỳ trước
  double previousRevenue = 0;
  double growthPercent = 0;

  // 🔥 Top sản phẩm bán chạy trong kỳ lọc hiện tại
  List<_TopProduct> topProducts = [];
  int topProductsCount = 0; // tổng số sản phẩm có đơn trong kỳ lọc

  // 🔥 Danh sách FULL sản phẩm theo doanh số (để xuất Excel/PDF)
  List<_TopProduct> allProducts = [];

  // 🔥 Người dùng – thống kê chi tiết
  List<_UserSummary> userDetails = []; // top user theo doanh thu
  Map<String, int> userByRole = {}; // role -> count
  int newUsersInFilter = 0; // user mới trong khoảng lọc
  int activeUsersInFilter = 0; // user có đơn trong kỳ lọc

  // ── Bộ lọc thời gian
  String selectedFilter =
      'month'; // 'week' | 'month' | 'year' | 'all' | 'custom'
  DateTime? customStart;
  DateTime? customEnd;

  @override
  void initState() {
    super.initState();
    _loadSavedFilter();
  }

  // ────────────────────────────────────────────────────────────────────────────
  // SharedPreferences
  // ────────────────────────────────────────────────────────────────────────────
  Future<void> _saveFilter() async {
    final p = await SharedPreferences.getInstance();
    await p.setString('report_filter', selectedFilter);
    if (customStart != null) {
      await p.setString('report_custom_start', customStart!.toIso8601String());
    }
    if (customEnd != null) {
      await p.setString('report_custom_end', customEnd!.toIso8601String());
    }
  }

  Future<void> _loadSavedFilter() async {
    final p = await SharedPreferences.getInstance();
    selectedFilter = p.getString('report_filter') ?? 'month';
    final s = p.getString('report_custom_start');
    final e = p.getString('report_custom_end');
    if (s != null) customStart = DateTime.tryParse(s);
    if (e != null) customEnd = DateTime.tryParse(e);
    await _loadData();
  }

  // ────────────────────────────────────────────────────────────────────────────
  // Helpers: mốc bắt đầu & chọn filter
  // ────────────────────────────────────────────────────────────────────────────
  DateTime? _getFilterStartDate() {
    final now = DateTime.now();
    switch (selectedFilter) {
      case 'week':
        return now.subtract(const Duration(days: 7));
      case 'month':
        return DateTime(now.year, now.month, 1);
      case 'year':
        return DateTime(now.year, 1, 1);
      case 'custom':
        return customStart;
      case 'all':
      default:
        return null;
    }
  }

  Future<void> _chooseFilter(String value) async {
    if (value == 'custom') {
      final picked = await showDateRangePicker(
        context: context,
        firstDate: DateTime(2022, 1, 1),
        lastDate: DateTime.now(),
        locale: const Locale('vi', 'VN'),
        initialDateRange: (customStart != null && customEnd != null)
            ? DateTimeRange(start: customStart!, end: customEnd!)
            : null,
      );
      if (picked == null) return;
      setState(() {
        selectedFilter = 'custom';
        customStart =
            DateTime(picked.start.year, picked.start.month, picked.start.day);
        customEnd = DateTime(picked.end.year, picked.end.month, picked.end.day);
      });
      await _saveFilter();
      await _loadData();
    } else {
      setState(() => selectedFilter = value);
      await _saveFilter();
      await _loadData();
    }
  }

  String _filterName() {
    switch (selectedFilter) {
      case 'week':
        return '7 ngày gần nhất';
      case 'month':
        return 'Tháng này';
      case 'year':
        return 'Năm nay';
      case 'custom':
        if (customStart != null && customEnd != null) {
          final s = DateFormat('dd/MM/yyyy').format(customStart!);
          final e = DateFormat('dd/MM/yyyy').format(customEnd!);
          return 'Từ $s đến $e';
        }
        return 'Tùy chọn thời gian';
      case 'all':
      default:
        return 'Toàn thời gian';
    }
  }

  // ────────────────────────────────────────────────────────────────────────────
  // Range hiển thị cho kỳ hiện tại & kỳ so sánh (dùng cho PDF)
  // ────────────────────────────────────────────────────────────────────────────
  DateTime _todayDateOnly() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  DateTimeRange? _currentRangeForDisplay() {
    final now = DateTime.now();
    final today = _todayDateOnly();

    switch (selectedFilter) {
      case 'week':
        final start = today.subtract(const Duration(days: 6));
        return DateTimeRange(start: start, end: today);
      case 'month':
        final start = DateTime(now.year, now.month, 1);
        final end = DateTime(now.year, now.month + 1, 0);
        return DateTimeRange(start: start, end: end);
      case 'year':
        final start = DateTime(now.year, 1, 1);
        final end = DateTime(now.year, 12, 31);
        return DateTimeRange(start: start, end: end);
      case 'custom':
        if (customStart == null || customEnd == null) return null;
        return DateTimeRange(start: customStart!, end: customEnd!);
      case 'all':
      default:
        return null;
    }
  }

  DateTimeRange? _previousRangeForDisplay() {
    final now = DateTime.now();
    final today = _todayDateOnly();

    switch (selectedFilter) {
      case 'week':
        final thisStart = today.subtract(const Duration(days: 6));
        final prevEnd = thisStart.subtract(const Duration(days: 1));
        final prevStart = prevEnd.subtract(const Duration(days: 6));
        return DateTimeRange(start: prevStart, end: prevEnd);
      case 'month':
        final thisStart = DateTime(now.year, now.month, 1);
        final prevEnd = thisStart.subtract(const Duration(days: 1));
        final prevStart = DateTime(prevEnd.year, prevEnd.month, 1);
        return DateTimeRange(start: prevStart, end: prevEnd);
      case 'year':
        final prevYear = now.year - 1;
        final start = DateTime(prevYear, 1, 1);
        final end = DateTime(prevYear, 12, 31);
        return DateTimeRange(start: start, end: end);
      case 'custom':
        if (customStart == null || customEnd == null) return null;
        final days = customEnd!.difference(customStart!).inDays;
        final prevEnd = customStart!.subtract(const Duration(days: 1));
        final prevStart = prevEnd.subtract(Duration(days: days));
        return DateTimeRange(start: prevStart, end: prevEnd);
      case 'all':
      default:
        return null;
    }
  }

  String _formatRange(DateTimeRange? range) {
    if (range == null) return 'Toàn thời gian';
    final df = DateFormat('dd/MM/yyyy');
    return '${df.format(range.start)} – ${df.format(range.end)}';
  }

  // ────────────────────────────────────────────────────────────────────────────
  // Tải dữ liệu Firestore & tính toán số liệu hiển thị
  // ────────────────────────────────────────────────────────────────────────────
  Future<void> _loadData() async {
    try {
      setState(() => loading = true);

      final fs = FirebaseFirestore.instance;

      // 3 query chính chạy song song
      final usersFuture = fs.collection('users').get();
      final productsFuture = fs.collection('products').get();
      final ordersFuture = fs.collection('orders').get();

      final usersSnap = await usersFuture;
      final productsSnap = await productsFuture;
      final ordersSnap = await ordersFuture;

      double revenue = 0;
      double prevRevenue = 0;
      final Map<String, double> revenueByMonth = {};
      final Map<String, int> orderByStatus = {};
      final Map<String, double> revenueByDay = {};

      // Map nhanh cho users & products
      final usersMap = {for (final u in usersSnap.docs) u.id: u.data()};
      final productsMap = {for (final p in productsSnap.docs) p.id: p.data()};

      // Thống kê sản phẩm & người dùng
      final Map<String, _TopProduct> productStats = {};
      final Map<String, _UserSummary> userAgg = {};
      final Map<String, int> userByRoleTmp = {};
      int newUsers = 0;

      final startDate = _getFilterStartDate();
      final now = DateTime.now();

      // Khoảng thời gian để tính user mới
      DateTime? userRangeStart;
      DateTime? userRangeEnd;
      if (selectedFilter == 'custom' &&
          customStart != null &&
          customEnd != null) {
        userRangeStart = customStart;
        userRangeEnd = customEnd!.add(const Duration(days: 1));
      } else if (startDate != null) {
        userRangeStart = startDate;
        userRangeEnd = null; // tới hiện tại
      }

      // Duyệt user: role + user mới
      for (final u in usersSnap.docs) {
        final data = u.data();

        final role = (data['role'] ?? data['type'] ?? 'user').toString();
        userByRoleTmp[role] = (userByRoleTmp[role] ?? 0) + 1;

        final rawCreated =
            data['createdAt'] ?? data['created_at'] ?? data['created_date'];
        DateTime? created;
        if (rawCreated is Timestamp) {
          created = rawCreated.toDate();
        } else if (rawCreated is int) {
          created = DateTime.fromMillisecondsSinceEpoch(rawCreated);
        } else if (rawCreated is String) {
          created = DateTime.tryParse(rawCreated);
        }

        if (created != null && userRangeStart != null) {
          final end = userRangeEnd ?? now.add(const Duration(days: 1));
          if (!created.isBefore(userRangeStart) && created.isBefore(end)) {
            newUsers++;
          }
        }
      }

      DateTime? prevStart;
      DateTime? prevEnd;
      if (selectedFilter == 'month') {
        final thisMonthStart = DateTime(now.year, now.month, 1);
        prevStart = DateTime(now.year, now.month - 1, 1);
        prevEnd = thisMonthStart;
      } else if (selectedFilter == 'week') {
        prevStart = DateTime(now.year, now.month, now.day)
            .subtract(const Duration(days: 14));
        prevEnd = DateTime(now.year, now.month, now.day)
            .subtract(const Duration(days: 7));
      } else if (selectedFilter == 'year') {
        prevStart = DateTime(now.year - 1, 1, 1);
        prevEnd = DateTime(now.year, 1, 1);
      } else if (selectedFilter == 'custom' &&
          customStart != null &&
          customEnd != null) {
        final rangeDays = customEnd!.difference(customStart!).inDays + 1;
        prevEnd =
            DateTime(customStart!.year, customStart!.month, customStart!.day);
        prevStart = prevEnd!.subtract(Duration(days: rangeDays));
      }

      double _toDouble(dynamic x) {
        if (x is num) return x.toDouble();
        if (x is String) {
          final cleaned = x.replaceAll(RegExp(r'[^\d.]'), '');
          return double.tryParse(cleaned) ?? 0.0;
        }
        return 0.0;
      }

       const Set<String> soldStatus = {
        'delivered', 'done', 'completed', 'success', 'finished',
      };

       const Set<String> validRevenueStatus = soldStatus; // hoặc bộ khác nếu bạn muốn



      // ===== LẦN 1: duyệt orders, tính doanh thu + gom những đơn cần đọc items =====
      final List<Future<QuerySnapshot<Map<String, dynamic>>>> itemFutures = [];

      for (final doc in ordersSnap.docs) {
        final data = doc.data();

        final status = (data['status'] ?? 'unknown').toString().toLowerCase();
        orderByStatus[status] = (orderByStatus[status] ?? 0) + 1;

        final total = _toDouble(data['total']);

        final raw = data['createdAt'] ?? data['created_at'];
        Timestamp? ts;
        if (raw is Timestamp) {
          ts = raw;
        } else if (raw is int) {
          ts = Timestamp.fromMillisecondsSinceEpoch(raw);
        } else if (raw is String) {
          final dt = DateTime.tryParse(raw);
          if (dt != null) ts = Timestamp.fromDate(dt);
        }
        final date = ts?.toDate();
        if (date == null) continue;

        bool inRange = true;
        if (selectedFilter == 'custom' &&
            customStart != null &&
            customEnd != null) {
          final endExclusive = customEnd!.add(const Duration(days: 1));
          inRange =
              !date.isBefore(customStart!) && date.isBefore(endExclusive);
        } else if (startDate != null) {
          inRange = !date.isBefore(startDate);
        }

        if (inRange && validRevenueStatus.contains(status)) {
          revenue += total;

          final mKey = 'T${date.month}';
          revenueByMonth[mKey] = (revenueByMonth[mKey] ?? 0) + total;

          final dKey = DateFormat('dd/MM').format(date);
          revenueByDay[dKey] = (revenueByDay[dKey] ?? 0) + total;

          // === Thống kê người dùng: số đơn & doanh thu theo user ===
          final rawUid =
              data['userId'] ?? data['userID'] ?? data['uid'] ?? data['user_id'];
          if (rawUid != null) {
            final uid = rawUid.toString();
            final uData = usersMap[uid];

            final name = (uData?['displayName'] ??
                uData?['name'] ??
                uData?['fullName'] ??
                'Người dùng')
                .toString();
            final email = (uData?['email'] ?? '').toString();

            final currentUser = userAgg[uid];
            if (currentUser == null) {
              userAgg[uid] = _UserSummary(
                id: uid,
                name: name,
                email: email.isEmpty ? null : email,
                orderCount: 1,
                revenue: total,
              );
            } else {
              userAgg[uid] = currentUser.copyWith(
                orderCount: currentUser.orderCount + 1,
                revenue: currentUser.revenue + total,
              );
            }
          }

          // 👉 chỉ gom những đơn có doanh thu trong khoảng lọc
          itemFutures.add(
            fs.collection('orders').doc(doc.id).collection('items').get(),
          );
        }

        if (prevStart != null &&
            prevEnd != null &&
            !date.isBefore(prevStart) &&
            date.isBefore(prevEnd) &&
            validRevenueStatus.contains(status)) {
          prevRevenue += total;
        }
      }

      // ===== LẦN 2: đọc toàn bộ items song song, rồi tính top sản phẩm =====
      final itemsSnapshots = await Future.wait(itemFutures);

      for (final itemsSnap in itemsSnapshots) {
        for (final itemDoc in itemsSnap.docs) {
          final it = itemDoc.data();

          final rawPid = it['productId'] ?? it['productID'] ?? it['product_id'];
          if (rawPid == null) continue;
          final pid = rawPid.toString();
          if (pid.isEmpty) continue;

          // qty
          final rawQty = it['qty'] ?? it['quantity'] ?? 0;
          int qty;
          if (rawQty is int) {
            qty = rawQty;
          } else {
            qty = int.tryParse(rawQty.toString()) ?? 0;
          }
          if (qty <= 0) continue;

          // price
          double unitPrice = _toDouble(it['price']);
          if (unitPrice <= 0) {
            final totalItem = _toDouble(it['total']);
            if (qty > 0) unitPrice = totalItem / qty;
          }

          // options (nếu có)
          Map<String, dynamic>? options;
          final rawOpt = it['options'];
          if (rawOpt is Map<String, dynamic>) {
            options = rawOpt;
          }

          final name = (it['name'] ??
              options?['name'] ??
              productsMap[pid]?['name'] ??
              productsMap[pid]?['title'] ??
              'Không tên')
              .toString();

          String? thumb;
          final rawThumb = it['imageUrl'] ??
              options?['imageUrl'] ??
              productsMap[pid]?['thumbnail'] ??
              productsMap[pid]?['image'] ??
              productsMap[pid]?['imageUrl'];
          if (rawThumb is String && rawThumb.isNotEmpty) {
            thumb = rawThumb;
          }

          final current = productStats[pid];
          final addRevenue = unitPrice * qty;

          if (current == null) {
            productStats[pid] = _TopProduct(
              id: pid,
              name: name,
              quantity: qty,
              revenue: addRevenue,
              imageUrl: thumb,
            );
          } else {
            productStats[pid] = current.copyWith(
              quantity: current.quantity + qty,
              revenue: current.revenue + addRevenue,
              name: current.name.isNotEmpty ? current.name : name,
              imageUrl: current.imageUrl ?? thumb,
            );
          }
        }
      }

      // Danh sách sản phẩm theo thống kê kỳ này (dùng cho Excel/PDF)
      final allProductsList = productStats.values.toList()
        ..sort((a, b) => b.quantity.compareTo(a.quantity));

      // Top N dùng cho card UI
      var topList = allProductsList;
      final int soldProductCount =
          productStats.length; // số SP có phát sinh đơn trong kỳ
      if (topList.length > 5) {
        topList = topList.sublist(0, 5);
      }

      final sortedDaily = Map<String, double>.fromEntries(
        revenueByDay.entries.toList()
          ..sort((a, b) =>
              DateFormat('dd/MM').parse(a.key).compareTo(
                DateFormat('dd/MM').parse(b.key),
              )),
      );

      // Người dùng: active trong kỳ + top theo doanh thu
      final activeUsers = userAgg.length;
      final userList = userAgg.values.toList()
        ..sort((a, b) => b.revenue.compareTo(a.revenue));
      final detailedUsers =
      userList.length > 50 ? userList.sublist(0, 50) : userList;

      double growth = 0;
      if (prevRevenue > 0) {
        growth = ((revenue - prevRevenue) / prevRevenue) * 100;
      }

      if (!mounted) return;
      setState(() {
        userCount = usersSnap.size;
        productCount = productsSnap.size;
        orderCount = ordersSnap.size;
        totalRevenue = revenue;
        monthlyRevenue = revenueByMonth;
        orderStatus = orderByStatus;
        dailyRevenue = sortedDaily;
        previousRevenue = prevRevenue;
        growthPercent = growth;
        topProducts = topList;
        topProductsCount = soldProductCount;
        allProducts = allProductsList;

        userDetails = detailedUsers;
        userByRole = userByRoleTmp;
        newUsersInFilter = newUsers;
        activeUsersInFilter = activeUsers;

        loading = false;
      });
    } catch (e, st) {
      debugPrint('❌ Load reports error: $e\n$st');
      if (mounted) {
        setState(() => loading = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Lỗi tải dữ liệu: $e')));
      }
    }
  }

  // ────────────────────────────────────────────────────────────────────────────
  // EXPORT helpers
  // ────────────────────────────────────────────────────────────────────────────

  String _currency(num v) =>
      NumberFormat.currency(locale: 'vi_VN', symbol: '₫', decimalDigits: 0)
          .format(v);

  DateTime _parseDdMm(String key) {
    try {
      return DateFormat('dd/MM').parse(key);
    } catch (_) {
      return DateTime.now();
    }
  }

  String _exportedByLabel() {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return 'Admin';

    final displayName = (user.displayName ?? '').trim();
    final email = (user.email ?? '').trim();

    if (displayName.isNotEmpty) return displayName; // ưu tiên tên hiển thị
    if (email.isNotEmpty) return email; // không có tên thì lấy email

    return 'Admin'; // fallback
  }

  // ────────────────────────────────────────────────────────────────────────────
  // Xuất Excel
  // ────────────────────────────────────────────────────────────────────────────
  Future<void> _exportReportToExcel() async {
    final messenger = ScaffoldMessenger.of(context);
    final exportedBy = _exportedByLabel();

    try {
      final excel = xls.Excel.createExcel();

      // ✅ Đổi tên sheet mặc định "Sheet1" thành "Doanh thu theo ngày"
      final defaultSheetName = excel.getDefaultSheet();
      if (defaultSheetName != null &&
          defaultSheetName.isNotEmpty &&
          defaultSheetName != 'Doanh thu theo ngày') {
        excel.rename(defaultSheetName, 'Doanh thu theo ngày');
      }

      // ─────────────────────────────────────────────────────────────
      // Chuẩn bị dữ liệu giống PDF
      // ─────────────────────────────────────────────────────────────
      final now = DateTime.now();
      String two(int n) => n.toString().padLeft(2, '0');
      final dateStr = '${two(now.day)}/${two(now.month)}/${now.year}';
      final timeStr = '${two(now.hour)}:${two(now.minute)}';

      // Doanh thu theo ngày
      final dailyEntries = dailyRevenue.entries.toList()
        ..sort((a, b) => _parseDdMm(a.key).compareTo(_parseDdMm(b.key)));

      // Doanh thu theo tháng
      final monthEntries = monthlyRevenue.entries.toList()
        ..sort((a, b) =>
        int.parse(a.key.replaceAll('T', '')) -
            int.parse(b.key.replaceAll('T', '')));

      // Đơn hàng theo trạng thái
      final statusEntries = orderStatus.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      // Top sản phẩm (FULL cho Excel)
      final productList =
      allProducts.isNotEmpty ? allProducts : topProducts; // fallback

      // ─────────────────────────────────────────────────────────────
      // SHEET 1: Doanh thu theo ngày
      // ─────────────────────────────────────────────────────────────
      final sheetDay = excel['Doanh thu theo ngày'];


      sheetDay.appendRow([]);
      sheetDay.appendRow([
        xls.TextCellValue('STT'),
        xls.TextCellValue('Ngày'),
        xls.TextCellValue('Doanh thu (VND)'),
      ]);

      for (int i = 0; i < dailyEntries.length; i++) {
        final e = dailyEntries[i];
        sheetDay.appendRow([
          xls.IntCellValue(i + 1),
          xls.TextCellValue(e.key),
          xls.DoubleCellValue(e.value),
        ]);
      }

      // ─────────────────────────────────────────────────────────────
      // SHEET 2: Doanh thu theo tháng
      // ─────────────────────────────────────────────────────────────
      final sheetMonth = excel['Doanh thu theo tháng'];


      sheetMonth.appendRow([]);
      sheetMonth.appendRow([
        xls.TextCellValue('Tháng'),
        xls.TextCellValue('Doanh thu (VND)'),
      ]);

      for (final e in monthEntries) {
        sheetMonth.appendRow([
          xls.TextCellValue(e.key),
          xls.DoubleCellValue(e.value),
        ]);
      }

      // ─────────────────────────────────────────────────────────────
      // SHEET 3: Đơn hàng theo trạng thái
      // ─────────────────────────────────────────────────────────────
      final sheetStatus = excel['Đơn hàng theo trạng thái'];


      sheetStatus.appendRow([]);
      sheetStatus.appendRow([
        xls.TextCellValue('Trạng thái'),
        xls.TextCellValue('Số đơn'),
      ]);

      for (final e in statusEntries) {
        sheetStatus.appendRow([
          xls.TextCellValue(e.key),
          xls.IntCellValue(e.value),
        ]);
      }

      // ─────────────────────────────────────────────────────────────
      // SHEET 4: Top sản phẩm
      // ─────────────────────────────────────────────────────────────
      final sheetProduct = excel['Top sản phẩm'];


      sheetProduct.appendRow([]);
      sheetProduct.appendRow([
        xls.TextCellValue('STT'),
        xls.TextCellValue('Tên sản phẩm'),
        xls.TextCellValue('SL bán'),
        xls.TextCellValue('Doanh thu (VND)'),
      ]);

      for (int i = 0; i < productList.length; i++) {
        final p = productList[i];
        sheetProduct.appendRow([
          xls.IntCellValue(i + 1),
          xls.TextCellValue(p.name),
          xls.IntCellValue(p.quantity),
          xls.DoubleCellValue(p.revenue),
        ]);
      }

      // Đặt sheet mặc định là "Doanh thu theo ngày"
      excel.setDefaultSheet('Doanh thu theo ngày');

      // ─────────────────────────────────────────────────────────────
      // Lưu file (Web / Mobile / Desktop)
      // ─────────────────────────────────────────────────────────────
      final bytes = excel.encode();
      if (bytes == null) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Lỗi mã hóa file Excel')),
        );
        return;
      }

      final fileName =
          'cses_report_${now.year}${two(now.month)}${two(now.day)}_${two(now.hour)}${two(now.minute)}.xlsx';

      if (kIsWeb) {
        final info = await saveExcelFile(bytes, baseName: 'cses_report');
        messenger.showSnackBar(
          SnackBar(content: Text('Đã xuất Excel: $info')),
        );
      } else {
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
          text: 'Báo cáo & Thống kê CSES (Excel)',
          subject: 'Báo cáo CSES',
        );

        messenger.showSnackBar(
          SnackBar(content: Text('Đã xuất Excel: $fileName')),
        );
      }
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Lỗi xuất Excel: $e')),
      );
    }
  }

  // ────────────────────────────────────────────────────────────────────────────
  // Xuất PDF
  // ────────────────────────────────────────────────────────────────────────────
  Future<void> _exportReportToPdf() async {
    final messenger = ScaffoldMessenger.of(context);
    final exportedBy = _exportedByLabel();

    try {
      final regularData =
      await rootBundle.load('assets/fonts/Roboto-Regular.ttf');
      final boldData = await rootBundle.load('assets/fonts/Roboto-Bold.ttf');
      final fontRegular = pw.Font.ttf(regularData);
      final fontBold = pw.Font.ttf(boldData);

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
      final dateStr = '${two(now.day)}/${two(now.month)}/${now.year}';
      final timeStr = '${two(now.hour)}:${two(now.minute)}';
      final exportedAt = '$timeStr · $dateStr';

      // ===== DỮ LIỆU BẢNG =====
      final dailyEntries = dailyRevenue.entries.toList()
        ..sort((a, b) => _parseDdMm(a.key).compareTo(_parseDdMm(b.key)));

      final monthEntries = monthlyRevenue.entries.toList()
        ..sort((a, b) =>
        int.parse(a.key.replaceAll('T', '')) -
            int.parse(b.key.replaceAll('T', '')));

      final statusEntries = orderStatus.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      final productsForPdf = (allProducts.isNotEmpty
          ? List<_TopProduct>.from(allProducts)
          : List<_TopProduct>.from(topProducts))
        ..sort((a, b) => b.quantity.compareTo(a.quantity));

      // ===== KỲ BÁO CÁO / TÓM TẮT =====
      final currentRange = _currentRangeForDisplay();
      final previousRange = _previousRangeForDisplay();
      final periodLabel = _formatRange(currentRange);
      final compareLabel =
      previousRange != null ? _formatRange(previousRange) : null;

      String? growthLabel;
      if (previousRange != null && previousRevenue > 0) {
        final sign = growthPercent >= 0 ? 'Tăng' : 'Giảm';
        growthLabel =
        '$sign ${growthPercent.abs().toStringAsFixed(1)}% so với kỳ trước';
      }

      // Tóm tắt chất lượng đơn
      final deliveredStatuses = {
        'delivered',
        'done',
        'completed',
        'success',
        'finished',
      };
      final cancelledStatuses = {'cancelled', 'canceled'};
      final inProgressStatuses = {'pending', 'processing', 'shipping'};

      int deliveredCount = 0;
      int cancelledCount = 0;
      int inProgressCount = 0;

      orderStatus.forEach((k, v) {
        final key = k.toLowerCase();
        if (deliveredStatuses.contains(key)) {
          deliveredCount += v;
        } else if (cancelledStatuses.contains(key)) {
          cancelledCount += v;
        } else if (inProgressStatuses.contains(key)) {
          inProgressCount += v;
        }
      });

      final totalOrdersInStatus =
      statusEntries.fold<int>(0, (s, e) => s + e.value);
      final completeRate = totalOrdersInStatus == 0
          ? 0.0
          : deliveredCount * 100.0 / totalOrdersInStatus;
      final cancelRate = totalOrdersInStatus == 0
          ? 0.0
          : cancelledCount * 100.0 / totalOrdersInStatus;
      final inProgressRate = totalOrdersInStatus == 0
          ? 0.0
          : inProgressCount * 100.0 / totalOrdersInStatus;

      // Top 3 sản phẩm highlight
      final highlightProducts = productsForPdf.length > 3
          ? productsForPdf.sublist(0, 3)
          : productsForPdf;
      final totalRevForHighlight =
      totalRevenue <= 0 ? 1.0 : totalRevenue.toDouble();
      final totalRevenueText = _currency(totalRevenue);

      pdfDoc.addPage(
        pw.MultiPage(
          pageFormat: pdf.PdfPageFormat.a4,
          margin: const pw.EdgeInsets.fromLTRB(26, 26, 26, 24),
          footer: (context) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              if (context.pageNumber == context.pagesCount)
                pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 4),
                  child: pw.Text(
                    'Ghi chú: Báo cáo được xuất tự động từ hệ thống CSES Store. '
                        'Dữ liệu được cập nhật đến thời điểm in.',
                    style: pw.TextStyle(
                      fontSize: 9,
                      color: pdf.PdfColors.grey600,
                    ),
                  ),
                ),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'CSES · Báo cáo & Thống kê',
                    style: pw.TextStyle(fontSize: 9),
                  ),
                  pw.Text(
                    'Trang ${context.pageNumber} / ${context.pagesCount}',
                    style: pw.TextStyle(fontSize: 9),
                  ),
                ],
              ),
            ],
          ),
          build: (context) {
            return [
              // ===== HEADER LOGO – VERSION ĐẬM HƠN =====
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
                            color: pdf.PdfColor.fromHex('#e6f0ff'), // nền xanh rất nhạt
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
                              'Báo cáo & Thống kê',
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
                          'Mã báo cáo: CSES-REP-${now.year}${two(now.month)}${two(now.day)}',
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


              // ===== TIÊU ĐỀ =====
              pw.Center(
                child: pw.Text(
                  'BÁO CÁO & THỐNG KÊ CSES',
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.SizedBox(height: 12),

              // ===== THÔNG TIN CHUNG – THẺ TÓM TẮT =====
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  color: pdf.PdfColors.grey100,
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Expanded(
                      flex: 3,
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'Thông tin chung',
                            style: pw.TextStyle(
                              fontSize: 11,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                          pw.SizedBox(height: 4),
                          pw.Text(
                            '• Kỳ báo cáo: $periodLabel',
                            style: pw.TextStyle(fontSize: 10),
                          ),
                          pw.Text(
                            '• Tổng doanh thu: $totalRevenueText',
                            style: pw.TextStyle(fontSize: 10),
                          ),
                          pw.Text(
                            '• Tổng số đơn: $orderCount',
                            style: pw.TextStyle(fontSize: 10),
                          ),
                          pw.Text(
                            '• Người xuất: $exportedBy',
                            style: pw.TextStyle(fontSize: 10),
                          ),
                          pw.SizedBox(height: 3),
                          if (compareLabel != null)
                            pw.Text(
                              'Kỳ so sánh: $compareLabel',
                              style: pw.TextStyle(
                                fontSize: 9,
                                color: pdf.PdfColors.grey700,
                              ),
                            ),
                          if (growthLabel != null)
                            pw.Text(
                              growthLabel!,
                              style: pw.TextStyle(
                                fontSize: 9,
                                color: pdf.PdfColors.grey700,
                              ),
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
                            'Ngày xuất',
                            style: pw.TextStyle(
                              fontSize: 11,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                          pw.SizedBox(height: 4),
                          pw.Text(
                            'Ngày: $dateStr',
                            style: pw.TextStyle(fontSize: 10),
                          ),
                          pw.Text(
                            'Giờ:  $timeStr',
                            style: pw.TextStyle(fontSize: 10),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 16),

              // ===== 1. DOANH THU THEO NGÀY =====
              pw.Text(
                '1. Doanh thu theo ngày',
                style: pw.TextStyle(
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 6),
              if (dailyEntries.isEmpty)
                pw.Text(
                  'Chưa có dữ liệu.',
                  style: pw.TextStyle(fontSize: 10),
                )
              else
                pw.Table.fromTextArray(
                  headerStyle: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                  ),
                  cellStyle: pw.TextStyle(fontSize: 9),
                  headerDecoration: pw.BoxDecoration(
                    color: pdf.PdfColors.grey300,
                  ),
                  oddRowDecoration:
                  pw.BoxDecoration(color: pdf.PdfColors.grey100),
                  border: pw.TableBorder.all(
                    color: pdf.PdfColors.grey400,
                    width: 0.6,
                  ),
                  columnWidths: const {
                    0: pw.FlexColumnWidth(0.8),
                    1: pw.FlexColumnWidth(1.4),
                    2: pw.FlexColumnWidth(2),
                  },
                  headers: const ['STT', 'Ngày', 'Doanh thu'],
                  data: [
                    for (int i = 0; i < dailyEntries.length; i++)
                      [
                        (i + 1).toString(),
                        dailyEntries[i].key,
                        _currency(dailyEntries[i].value),
                      ]
                  ],
                ),
              pw.SizedBox(height: 14),

              // ===== 2. DOANH THU THEO THÁNG =====
              pw.Text(
                '2. Doanh thu theo tháng',
                style: pw.TextStyle(
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 6),
              if (monthEntries.isEmpty)
                pw.Text(
                  'Chưa có dữ liệu.',
                  style: pw.TextStyle(fontSize: 10),
                )
              else
                pw.Table.fromTextArray(
                  headerStyle: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                  ),
                  cellStyle: pw.TextStyle(fontSize: 9),
                  headerDecoration: pw.BoxDecoration(
                    color: pdf.PdfColors.grey300,
                  ),
                  oddRowDecoration:
                  pw.BoxDecoration(color: pdf.PdfColors.grey100),
                  border: pw.TableBorder.all(
                    color: pdf.PdfColors.grey400,
                    width: 0.6,
                  ),
                  columnWidths: const {
                    0: pw.FlexColumnWidth(1),
                    1: pw.FlexColumnWidth(2),
                  },
                  headers: const ['Tháng', 'Doanh thu'],
                  data: [
                    for (final e in monthEntries)
                      [e.key, _currency(e.value)],
                  ],
                ),
              pw.SizedBox(height: 14),

              // ===== 3. ĐƠN HÀNG THEO TRẠNG THÁI =====
              pw.Text(
                '3. Đơn hàng theo trạng thái',
                style: pw.TextStyle(
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 6),
              if (statusEntries.isEmpty)
                pw.Text(
                  'Chưa có dữ liệu.',
                  style: pw.TextStyle(fontSize: 10),
                )
              else ...[
                pw.Table.fromTextArray(
                  headerStyle: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                  ),
                  cellStyle: pw.TextStyle(fontSize: 9),
                  headerDecoration: pw.BoxDecoration(
                    color: pdf.PdfColors.grey300,
                  ),
                  oddRowDecoration:
                  pw.BoxDecoration(color: pdf.PdfColors.grey100),
                  border: pw.TableBorder.all(
                    color: pdf.PdfColors.grey400,
                    width: 0.6,
                  ),
                  columnWidths: const {
                    0: pw.FlexColumnWidth(2),
                    1: pw.FlexColumnWidth(1),
                  },
                  headers: const ['Trạng thái', 'Số đơn'],
                  data: [
                    for (final e in statusEntries)
                      [e.key, e.value.toString()],
                  ],
                ),
                pw.SizedBox(height: 6),
                pw.Text(
                  'Tổng số đơn: $totalOrdersInStatus',
                  style: pw.TextStyle(fontSize: 10),
                ),
                pw.Text(
                  '• Hoàn tất: ${completeRate.toStringAsFixed(1)}%   '
                      '• Huỷ: ${cancelRate.toStringAsFixed(1)}%   '
                      '• Đang xử lý/giao: ${inProgressRate.toStringAsFixed(1)}%',
                  style: pw.TextStyle(fontSize: 9),
                ),
              ],
              pw.SizedBox(height: 14),

              // ===== 4. TOP SẢN PHẨM =====
              pw.Text(
                '4. Top sản phẩm',
                style: pw.TextStyle(
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 6),
              if (productsForPdf.isEmpty)
                pw.Text(
                  'Chưa có dữ liệu.',
                  style: pw.TextStyle(fontSize: 10),
                )
              else ...[
                pw.Table.fromTextArray(
                  headerStyle: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                  ),
                  cellStyle: pw.TextStyle(fontSize: 9),
                  headerDecoration: pw.BoxDecoration(
                    color: pdf.PdfColors.grey300,
                  ),
                  oddRowDecoration:
                  pw.BoxDecoration(color: pdf.PdfColors.grey100),
                  border: pw.TableBorder.all(
                    color: pdf.PdfColors.grey400,
                    width: 0.6,
                  ),
                  columnWidths: const {
                    0: pw.FlexColumnWidth(0.7),
                    1: pw.FlexColumnWidth(2.4),
                    2: pw.FlexColumnWidth(0.9),
                    3: pw.FlexColumnWidth(1.4),
                  },
                  headers: const ['STT', 'Sản phẩm', 'Lượt bán', 'Doanh thu'],
                  data: [
                    for (int i = 0; i < productsForPdf.length; i++)
                      [
                        (i + 1).toString(),
                        productsForPdf[i].name,
                        productsForPdf[i].quantity.toString(),
                        _currency(productsForPdf[i].revenue),
                      ],
                  ],
                ),
                if (highlightProducts.isNotEmpty) ...[
                  pw.SizedBox(height: 6),
                  pw.Text(
                    'Các sản phẩm đóng góp nhiều doanh thu nhất trong kỳ:',
                    style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 2),
                  for (final p in highlightProducts)
                    pw.Text(
                      '• ${p.name} – ${_currency(p.revenue)} '
                          '(~${(p.revenue * 100 / totalRevForHighlight).toStringAsFixed(1)}% tổng doanh thu)',
                      style: pw.TextStyle(fontSize: 9),
                    ),
                ],
              ],
              pw.SizedBox(height: 16),

              // ===== KÝ TÊN =====
              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Text(
                      'Ngày $dateStr',
                      style: pw.TextStyle(fontSize: 10),
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
          'cses_report_${now.year}${two(now.month)}${two(now.day)}_${two(now.hour)}${two(now.minute)}.pdf';

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

  // ────────────────────────────────────────────────────────────────────────────
  // UI chính
  // ────────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final currency = NumberFormat.currency(locale: 'vi_VN', symbol: '₫');

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        backgroundColor: cs.surface,
        elevation: 0,
        iconTheme: IconThemeData(color: cs.onSurface),
        title: Text(
          'Báo cáo & Thống kê',
          style: TextStyle(
              color: cs.onSurface, fontWeight: FontWeight.w700, fontSize: 18),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Chọn thời gian tùy chỉnh',
            icon: Icon(CupertinoIcons.calendar, color: cs.onSurface),
            onPressed: () => _chooseFilter('custom'),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, thickness: 1, color: cs.outlineVariant),
        ),
      ),
      body: loading
          ? const Center(child: CupertinoActivityIndicator())
          : RefreshIndicator(
        color: cs.primary,
        onRefresh: _loadData,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            _FilterSegment(
                value: selectedFilter, onChanged: _chooseFilter),
            const SizedBox(height: 10),
            Text(
              'Bộ lọc hiện tại: ${_filterName()}',
              style: TextStyle(
                  color: cs.onSurfaceVariant,
                  fontStyle: FontStyle.italic),
            ),

            // Hàng xuất Excel / PDF
            const SizedBox(height: 8),
            Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Xuất báo cáo',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: cs.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Theo khoảng thời gian hiện tại',
                      style: TextStyle(
                        fontSize: 11,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Row(
                  children: [
                    TextButton.icon(
                      onPressed: _exportReportToExcel,
                      icon: const Icon(
                        CupertinoIcons.square_arrow_down,
                        size: 16,
                      ),
                      label: const Text(
                        'Excel',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: TextButton.styleFrom(
                        minimumSize: Size.zero,
                        tapTargetSize:
                        MaterialTapTargetSize.shrinkWrap,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        backgroundColor: cs.primary.withOpacity(0.08),
                        foregroundColor: cs.primary,
                        shape: const StadiumBorder(),
                        elevation: 0,
                      ),
                    ),
                    const SizedBox(width: 6),
                    TextButton.icon(
                      onPressed: _exportReportToPdf,
                      icon: const Icon(
                        Icons.picture_as_pdf_rounded,
                        size: 16,
                      ),
                      label: const Text(
                        'PDF',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: TextButton.styleFrom(
                        minimumSize: Size.zero,
                        tapTargetSize:
                        MaterialTapTargetSize.shrinkWrap,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        backgroundColor: cs.error.withOpacity(0.06),
                        foregroundColor: cs.error,
                        shape: const StadiumBorder(),
                        elevation: 0,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 16),
            _buildStatCard(
              icon: CupertinoIcons.person_2_fill,
              title: 'Người dùng',
              value: userCount.toString(),
              color: cs.primary,
              onTap: () =>
                  Navigator.pushNamed(context, '/admin/users'),
            ),

            // 🔥 Card SẢN PHẨM – top bán chạy
            _buildProductTopCard(context),

            // 🔥 Card ĐƠN HÀNG
            _buildOrderStatCard(context),

            // 🔥 Card DOANH THU
            _revenueCard(
              title: 'Doanh thu',
              value: currency.format(totalRevenue),
              growth: growthPercent,
              onTap: () => _openRevenueBottomSheet(context),
            ),
          ],
        ),
      ),
    );
  }

  // ── Card số liệu chung
  Widget _buildStatCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
    VoidCallback? onTap,
  }) {
    final cs = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: _cardDeco(cs),
        child: ListTile(
          contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          leading: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
                color: color.withOpacity(0.18),
                borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: color, size: 22),
          ),
          title: Text(title,
              style: TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 15,
                  color: cs.onSurface)),
          trailing: Text(
            value,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                fontWeight: FontWeight.w700, fontSize: 16, color: color),
          ),
        ),
      ),
    );
  }

  // ── Card SẢN PHẨM: Top bán chạy – UI mới với badge No.1/No.2/No.3
  Widget _buildProductTopCard(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final currency = NumberFormat.currency(
      locale: 'vi_VN',
      symbol: '₫',
      decimalDigits: 0,
    );

    // Clamp text scale nhẹ để tránh phình chữ làm vỡ layout trên màn nhỏ
    final media = MediaQuery.of(context);
    final double clampedScale = media.textScaler.scale(1.0).clamp(1.0, 1.10);

    return MediaQuery(
      data: media.copyWith(textScaler: TextScaler.linear(clampedScale)),
      child: LayoutBuilder(
        builder: (context, box) {
          final w = box.maxWidth;

          final bool tight = w < 360;
          final bool compact = w >= 360 && w < 420;
          final bool wide = w >= 520;

          final EdgeInsets pad = EdgeInsets.fromLTRB(
            tight ? 14 : 16,
            tight ? 12 : 14,
            tight ? 14 : 16,
            12,
          );

          final double iconBox = tight ? 36 : 38;
          final double headerTitleSize = tight ? 14.5 : 15.5;
          final double headerSubSize = tight ? 12.0 : 12.5;

          final double nameSize = tight ? 13.0 : 13.5;
          final double metaSize = tight ? 11.5 : 12.0;

          final double imageSize = tight ? 38 : compact ? 40 : wide ? 46 : 42;
          final double badgeFont = tight ? 10.5 : 11.0;
          final EdgeInsets badgePad = EdgeInsets.symmetric(
            horizontal: tight ? 8 : 10,
            vertical: tight ? 3 : 4,
          );

          // ── Empty state
          if (topProducts.isEmpty) {
            return GestureDetector(
              onTap: () => Navigator.pushNamed(context, '/admin/products'),
              child: Container(
                margin: const EdgeInsets.only(bottom: 14),
                padding: pad,
                decoration: _cardDeco(cs),
                child: Row(
                  children: [
                    Container(
                      width: iconBox,
                      height: iconBox,
                      decoration: BoxDecoration(
                        color: cs.secondary.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        CupertinoIcons.cube_box_fill,
                        color: cs.secondary,
                        size: tight ? 20 : 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Chưa có dữ liệu sản phẩm bán chạy trong khoảng thời gian đã chọn',
                        style: TextStyle(
                          fontSize: tight ? 12.5 : 13,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          final int count = topProductsCount;

          // Màn quá hẹp: chỉ show 4 item để thoáng; còn lại giữ 5 như cũ
          final int maxVisible = tight ? 4 : 5;
          final int visibleCount = topProducts.length > maxVisible ? maxVisible : topProducts.length;

          Color badgeColor(int rank) {
            if (rank == 1) return const Color(0xFFFFD60A); // gold
            if (rank == 2) return const Color(0xFFC0C0C0); // silver
            if (rank == 3) return const Color(0xFFCD7F32); // bronze
            return cs.outlineVariant;
          }

          String badgeLabel(int rank) {
            if (rank == 1) return tight ? 'No1' : 'No.1';
            if (rank == 2) return tight ? 'No2' : 'No.2';
            if (rank == 3) return tight ? 'No3' : 'No.3';
            return '#$rank';
          }

          // Nền card (giống phong cách bạn đang dùng nhưng responsive + alpha chuẩn mới)
          final cardDeco = BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: cs.outlineVariant.withValues(alpha: isDark ? 0.35 : 0.65),
            ),
            gradient: isDark
                ? LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                cs.surface.withValues(alpha: 0.98),
                cs.surfaceContainerHigh.withValues(alpha: 0.92),
              ],
            )
                : LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                cs.surface,
                cs.surfaceContainerHighest.withValues(alpha: 0.95),
              ],
            ),
            boxShadow: isDark
                ? null
                : [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          );

          return GestureDetector(
            onTap: () => Navigator.pushNamed(context, '/admin/products'),
            child: Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: pad,
              decoration: cardDeco,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    children: [
                      Container(
                        width: iconBox,
                        height: iconBox,
                        decoration: BoxDecoration(
                          color: cs.secondary.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          CupertinoIcons.cube_box_fill,
                          color: cs.secondary,
                          size: tight ? 20 : 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Sản phẩm',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: headerTitleSize,
                                color: cs.onSurface,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Top sản phẩm bán chạy trong khoảng thời gian đã chọn',
                              maxLines: tight ? 2 : 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: headerSubSize,
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            count.toString(),
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: tight ? 15.5 : 16,
                              color: cs.secondary,
                            ),
                          ),
                          Text(
                            'đã chọn',
                            style: TextStyle(
                              fontSize: tight ? 10.5 : 11,
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  SizedBox(height: tight ? 10 : 12),

                  // Danh sách top N
                  ...List.generate(visibleCount, (index) {
                    final rank = index + 1;
                    final p = topProducts[index];
                    final bColor = badgeColor(rank);
                    final bText = badgeLabel(rank);
                    final revenueText = currency.format(p.revenue);

                    // Badge text color: rank<=3 dùng đen; còn lại dùng onSurfaceVariant
                    final badgeTextColor = rank <= 3 ? Colors.black : cs.onSurfaceVariant;

                    final divider = Divider(
                      height: tight ? 10 : 12,
                      thickness: 0.7,
                      color: cs.outlineVariant.withValues(alpha: 0.7),
                      indent: (badgePad.horizontal + 20) + imageSize, // cảm giác canh lề ổn hơn
                    );

                    return Column(
                      children: [
                        if (index != 0) divider,
                        Padding(
                          padding: EdgeInsets.symmetric(vertical: tight ? 5 : 6),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              // Badge
                              Container(
                                padding: badgePad,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(999),
                                  gradient: rank <= 3
                                      ? LinearGradient(
                                    colors: [
                                      bColor.withValues(alpha: 0.90),
                                      bColor.withValues(alpha: 0.65),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  )
                                      : null,
                                  color: rank > 3
                                      ? cs.surfaceContainerHighest.withValues(alpha: 0.85)
                                      : null,
                                ),
                                child: Text(
                                  bText,
                                  style: TextStyle(
                                    fontSize: badgeFont,
                                    fontWeight: FontWeight.w800,
                                    color: badgeTextColor,
                                  ),
                                ),
                              ),
                              SizedBox(width: tight ? 8 : 10),

                              // Ảnh
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: (p.imageUrl != null && p.imageUrl!.isNotEmpty)
                                    ? Image.network(
                                  p.imageUrl!,
                                  width: imageSize,
                                  height: imageSize,
                                  fit: BoxFit.cover,
                                )
                                    : Container(
                                  width: imageSize,
                                  height: imageSize,
                                  alignment: Alignment.center,
                                  color: cs.surfaceContainerHighest.withValues(alpha: 0.70),
                                  child: Icon(
                                    CupertinoIcons.cube_box,
                                    size: tight ? 18 : 20,
                                    color: cs.onSurfaceVariant,
                                  ),
                                ),
                              ),
                              SizedBox(width: tight ? 8 : 10),

                              // Tên + số liệu
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      p.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: nameSize,
                                        fontWeight: FontWeight.w600,
                                        color: cs.onSurface,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      // Màn hẹp: ưu tiên “Đã bán”, doanh thu rút gọn
                                      tight
                                          ? 'Đã bán: ${p.quantity} · $revenueText'
                                          : 'Đã bán: ${p.quantity}  ·  Doanh thu: $revenueText',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: metaSize,
                                        color: cs.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  }),

                  SizedBox(height: tight ? 4 : 6),

                  Align(
                    alignment: Alignment.centerRight,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          tight ? 'Xem tất cả' : 'Chạm để xem tất cả sản phẩm',
                          style: TextStyle(
                            fontSize: tight ? 11.0 : 11.5,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          CupertinoIcons.chevron_right,
                          size: 14,
                          color: cs.onSurfaceVariant,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }


  // ── Card ĐƠN HÀNG
  // ── Card ĐƠN HÀNG
  Widget _buildOrderStatCard(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    // Map trạng thái -> count (hỗ trợ cả key dạng code và dạng tiếng Việt nếu bạn đang dùng lẫn lộn)
    int _getCount(List<String> keys) {
      for (final k in keys) {
        final v = orderStatus[k];
        if (v != null) return v;
      }
      return 0;
    }

    final int pending = _getCount(['pending', 'confirm', 'confirmed', 'Chờ xác nhận']);
    final int pickup = _getCount(['pickup', 'await_pickup', 'Chờ lấy hàng']);
    final int shipping = _getCount(['shipping', 'delivering', 'Đang giao', 'Giao']);
    final int completed = _getCount(['completed', 'done', 'Hoàn tất']);
    final int cancelled = _getCount(['cancelled', 'canceled', 'Đã huỷ', 'Đã hủy', 'Hủy', 'Huỷ']);

    // Các key đã “nhận diện”
    final knownKeys = <String>{
      'pending', 'confirm', 'confirmed', 'Chờ xác nhận',
      'pickup', 'await_pickup', 'Chờ lấy hàng',
      'shipping', 'delivering', 'Đang giao', 'Giao',
      'completed', 'done', 'Hoàn tất',
      'cancelled', 'canceled', 'Đã huỷ', 'Đã hủy', 'Hủy', 'Huỷ',
    };

    // Khác = những status còn lại
    final int other = orderStatus.entries
        .where((e) => !knownKeys.contains(e.key))
        .fold<int>(0, (sum, e) => sum + (e.value));

    final labels = <String>[
      'Chờ xác nhận',
      'Chờ lấy hàng',
      'Đang giao',
      'Hoàn tất',
      'Đã huỷ',
      'Khác',
    ];

    final shortLabelsDefault = <String>['Xác nhận', 'Lấy hàng', 'Giao', 'Hoàn tất', 'Huỷ', 'Khác'];
    final shortLabelsTight = <String>['XN', 'LH', 'Giao', 'HT', 'Huỷ', 'K'];

    final values = <int>[pending, pickup, shipping, completed, cancelled, other];

    final colors = <Color>[
      const Color(0xFF2F80ED), // pending
      const Color(0xFFF2994A), // pickup
      const Color(0xFF56CCF2), // shipping
      const Color(0xFF27AE60), // completed
      const Color(0xFFEB5757), // cancelled
      cs.onSurfaceVariant.withValues(alpha: 0.35), // other
    ];

    final totalBars = values.length;

    final int maxValue = values.isEmpty ? 0 : values.reduce((a, b) => a > b ? a : b);
    final double maxY = (maxValue <= 0 ? 1 : (maxValue * 1.15)).ceilToDouble();
    final double leftInterval = (() {
      if (maxY <= 4) return 1.0;
      final step = (maxY / 4).ceilToDouble();
      return step <= 0 ? 1.0 : step;
    })();

    // Clamp text scale nhẹ để tránh “phình chữ” làm vỡ layout trên màn hình nhỏ
    final media = MediaQuery.of(context);
    final double clampedScale = media.textScaler.scale(1.0).clamp(1.0, 1.10);

    return MediaQuery(
      data: media.copyWith(textScaler: TextScaler.linear(clampedScale)),
      child: GestureDetector(
        onTap: () => Navigator.pushNamed(context, '/admin/orders'),
        child: LayoutBuilder(
          builder: (context, box) {
            final w = box.maxWidth;

            final bool tight = w < 360;
            final bool wide = w >= 520;

            // Chart height & padding tự co giãn
            final double chartHeight = (tight ? 170.0 : (wide ? 230.0 : 200.0)).clamp(160.0, 240.0);
            final EdgeInsets pad = EdgeInsets.fromLTRB(
              tight ? 14 : 16,
              12,
              tight ? 14 : 16,
              12,
            );

            // Tự tính barWidth theo bề ngang thực tế (clamp để đẹp)
            // Trừ “ước lượng” phần reserved + padding + khoảng cách nội bộ
            final double approxUsable = (w - (tight ? 76 : 90)).clamp(180.0, 9999.0);
            final double barWidth = (approxUsable / (totalBars * 2.1)).clamp(10.0, 20.0);

            final double leftReserved = tight ? 28 : 32;
            final double bottomReserved = tight ? 22 : 26;

            final axisColor = cs.onSurfaceVariant;

            final shortLabels = tight ? shortLabelsTight : shortLabelsDefault;

            return Container(
              padding: pad,
              margin: const EdgeInsets.only(bottom: 14),
              decoration: _cardDeco(cs).copyWith(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isDark
                      ? [
                    cs.surface.withValues(alpha: 0.95),
                    cs.surfaceContainerHigh.withValues(alpha: 0.85),
                  ]
                      : [
                    cs.surface,
                    cs.surfaceContainerHighest.withValues(alpha: 0.95),
                  ],
                ),
                border: Border.all(
                  color: cs.outlineVariant.withValues(alpha: isDark ? 0.35 : 0.55),
                  width: 0.9,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: cs.primary.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          CupertinoIcons.cart_fill,
                          color: cs.primary,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Đơn hàng',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: tight ? 14.5 : 15.5,
                            color: cs.onSurface,
                          ),
                        ),
                      ),
                      Text(
                        orderCount.toString(),
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: tight ? 15 : 16,
                          color: cs.primary,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  // Chart
                  SizedBox(
                    height: chartHeight,
                    child: BarChart(
                      BarChartData(
                        maxY: maxY,
                        alignment: BarChartAlignment.spaceAround,
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: false,
                          horizontalInterval: leftInterval,
                          getDrawingHorizontalLine: (v) => FlLine(
                            color: cs.outlineVariant.withValues(alpha: 0.55),
                            strokeWidth: 1,
                          ),
                        ),
                        borderData: FlBorderData(
                          show: true,
                          border: Border(
                            left: BorderSide(color: cs.outlineVariant, width: 1),
                            bottom: BorderSide(color: cs.outlineVariant, width: 1),
                            right: const BorderSide(color: Colors.transparent),
                            top: const BorderSide(color: Colors.transparent),
                          ),
                        ),
                        titlesData: FlTitlesData(
                          topTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          rightTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: bottomReserved,
                              getTitlesWidget: (v, meta) {
                                final i = v.toInt();
                                if (i < 0 || i >= shortLabels.length) return const SizedBox.shrink();
                                return Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Text(
                                    shortLabels[i],
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: tight ? 10.5 : 11,
                                      color: axisColor,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: leftReserved,
                              interval: leftInterval,
                              getTitlesWidget: (v, meta) => Padding(
                                padding: const EdgeInsets.only(right: 4),
                                child: Text(
                                  v.toInt().toString(),
                                  style: TextStyle(
                                    fontSize: tight ? 10.5 : 11,
                                    color: axisColor,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        barGroups: [
                          for (var i = 0; i < totalBars; i++)
                            BarChartGroupData(
                              x: i,
                              barRods: [
                                BarChartRodData(
                                  toY: values[i].toDouble(),
                                  color: colors[i],
                                  width: barWidth,
                                  borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(8),
                                  ),
                                  backDrawRodData: BackgroundBarChartRodData(
                                    show: true,
                                    toY: maxY,
                                    color: cs.onSurfaceVariant.withValues(alpha: 0.06),
                                  ),
                                ),
                              ],
                            ),
                        ],
                        barTouchData: BarTouchData(
                          enabled: true,
                          touchTooltipData: BarTouchTooltipData(
                            tooltipRoundedRadius: 10,
                            tooltipPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                            getTooltipItem: (g, gi, r, ri) {
                              final label = labels[gi];
                              final count = values[gi];
                              final percent = orderCount == 0 ? 0 : (count / orderCount) * 100;
                              return BarTooltipItem(
                                '$label\n$count đơn (${percent.toStringAsFixed(1)}%)',
                                TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: cs.onSurface,
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Legend (auto wrap)
                  Wrap(
                    spacing: tight ? 6 : 8,
                    runSpacing: tight ? 6 : 6,
                    children: [
                      for (var i = 0; i < totalBars; i++)
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: tight ? 8 : 9,
                            vertical: tight ? 4 : 5,
                          ),
                          decoration: BoxDecoration(
                            color: colors[i].withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 9,
                                height: 9,
                                decoration: BoxDecoration(
                                  color: colors[i],
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                '${labels[i]} (${values[i]})',
                                style: TextStyle(
                                  fontSize: tight ? 11.5 : 12,
                                  color: cs.onSurface,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  Align(
                    alignment: Alignment.centerRight,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Chạm để xem chi tiết',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          CupertinoIcons.chevron_right,
                          size: 14,
                          color: cs.onSurfaceVariant,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }


  // ── Card doanh thu (sparkline)
  Widget _revenueCard({
    required String title,
    required String value,
    required double growth,
    VoidCallback? onTap,
  }) {
    final cs = Theme.of(context).colorScheme;
    final up = growth >= 0;
    final growthColor = up ? const Color(0xFF34C759) : cs.error;

    final entries = dailyRevenue.entries.toList()
      ..sort((a, b) =>
          DateFormat('dd/MM').parse(a.key).compareTo(
            DateFormat('dd/MM').parse(b.key),
          ));
    final tail =
    entries.length > 20 ? entries.sublist(entries.length - 20) : entries;

    final spots = <FlSpot>[];
    double minY = double.infinity, maxY = 0;
    for (var i = 0; i < tail.length; i++) {
      final y = tail[i].value;
      spots.add(FlSpot(i.toDouble(), y));
      if (y < minY) minY = y;
      if (y > maxY) maxY = y;
    }
    final pad = (maxY - minY).abs() * .2;

    final isDark = cs.brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        margin: const EdgeInsets.only(bottom: 14),
        decoration: _cardDeco(cs).copyWith(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [cs.surface, cs.surface.withOpacity(0.95)]
                : [Colors.white, const Color(0xFFF5F5F7)],
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF7C3AED).withOpacity(isDark ? .7 : .9),
                    const Color(0xFF6366F1).withOpacity(isDark ? .7 : .9),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                CupertinoIcons.money_dollar_circle_fill,
                color: Colors.white,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: cs.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          value,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 18,
                            color: cs.onSurface,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: growthColor.withOpacity(.12),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              up
                                  ? CupertinoIcons.arrow_up_right
                                  : CupertinoIcons.arrow_down_right,
                              size: 14,
                              color: growthColor,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              '${growth.abs().toStringAsFixed(1)}%',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: growthColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'So với kỳ trước',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 6),
                  SizedBox(
                    height: 32,
                    child: spots.isEmpty
                        ? const SizedBox.shrink()
                        : LineChart(
                      LineChartData(
                        minX: 0,
                        maxX: (spots.length - 1).toDouble(),
                        minY:
                        (minY - pad).clamp(0, double.infinity),
                        maxY: maxY + pad,
                        gridData: const FlGridData(show: false),
                        titlesData: const FlTitlesData(show: false),
                        borderData: FlBorderData(show: false),
                        lineTouchData:
                        const LineTouchData(enabled: false),
                        lineBarsData: [
                          LineChartBarData(
                            spots: spots,
                            isCurved: true,
                            barWidth: 2.1,
                            color: cs.tertiary,
                            dotData: FlDotData(show: false),
                            belowBarData: BarAreaData(
                              show: true,
                              gradient: LinearGradient(
                                colors: [
                                  cs.tertiary.withOpacity(.18),
                                  cs.tertiary.withOpacity(.00),
                                ],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Icon(
              CupertinoIcons.chevron_right,
              size: 18,
              color: cs.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }

  // Kiểu card chung
  static BoxDecoration _cardDeco(ColorScheme cs) {
    final isDark = cs.brightness == Brightness.dark;
    return BoxDecoration(
      color: cs.surface,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: cs.outlineVariant),
      boxShadow: isDark
          ? null
          : [
        BoxShadow(
          color: Colors.black.withOpacity(0.06),
          blurRadius: 10,
          offset: const Offset(0, 3),
        ),
      ],
    );
  }

  // BottomSheet: 3 biểu đồ
  void _openRevenueBottomSheet(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final currency =
    NumberFormat.currency(locale: 'vi_VN', symbol: '₫');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: cs.surface,
      shape: const RoundedRectangleBorder(
          borderRadius:
          BorderRadius.vertical(top: Radius.circular(18))),
      builder: (_) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.82,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (context, scrollCtl) {
            return SingleChildScrollView(
              controller: scrollCtl,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 5,
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: cs.onSurfaceVariant.withOpacity(.35),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  Center(
                    child: Text(
                      'Chi tiết doanh thu',
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge!
                          .copyWith(
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Tổng: ${currency.format(totalRevenue)}',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: cs.onSurface,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: (growthPercent >= 0
                              ? const Color(0xFF34C759)
                              : cs.error)
                              .withOpacity(0.12),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              growthPercent >= 0
                                  ? CupertinoIcons.arrow_up_right
                                  : CupertinoIcons.arrow_down_right,
                              size: 14,
                              color: growthPercent >= 0
                                  ? const Color(0xFF34C759)
                                  : cs.error,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${growthPercent.toStringAsFixed(1)}%',
                              style: TextStyle(
                                color: growthPercent >= 0
                                    ? const Color(0xFF34C759)
                                    : cs.error,
                                fontWeight: FontWeight.w700,
                                fontSize: 12.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  _ChartSection(
                    title: '📅 Doanh thu theo ngày',
                    subtitle:
                    'Biến động doanh thu từng ngày trong khoảng lọc hiện tại',
                    child:
                    _RevenueLineChart(dailyRevenue: dailyRevenue),
                  ),
                  const SizedBox(height: 12),

                  _ChartSection(
                    title: '📊 Doanh thu theo tháng',
                    subtitle: 'Tổng hợp doanh thu theo từng tháng',
                    child: _RevenueBarChart(
                        monthlyRevenue: monthlyRevenue),
                  ),
                  const SizedBox(height: 12),

                  _ChartSection(
                    title: '🥧 Tỉ trọng đơn theo trạng thái',
                    subtitle:
                    'Tỷ lệ số đơn theo từng trạng thái trong toàn bộ dữ liệu',
                    child:
                    _OrderStatusPie(statusCounts: orderStatus),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Model top sản phẩm
// ─────────────────────────────────────────────────────────────────────────────
class _TopProduct {
  final String id;
  final String name;
  final int quantity;
  final double revenue;
  final String? imageUrl;

  const _TopProduct({
    required this.id,
    required this.name,
    required this.quantity,
    required this.revenue,
    this.imageUrl,
  });

  _TopProduct copyWith({
    String? id,
    String? name,
    int? quantity,
    double? revenue,
    String? imageUrl,
  }) {
    return _TopProduct(
      id: id ?? this.id,
      name: name ?? this.name,
      quantity: quantity ?? this.quantity,
      revenue: revenue ?? this.revenue,
      imageUrl: imageUrl ?? this.imageUrl,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Model thống kê người dùng
// ─────────────────────────────────────────────────────────────────────────────
class _UserSummary {
  final String id;
  final String name;
  final String? email;
  final int orderCount;
  final double revenue;

  const _UserSummary({
    required this.id,
    required this.name,
    this.email,
    required this.orderCount,
    required this.revenue,
  });

  _UserSummary copyWith({
    String? id,
    String? name,
    String? email,
    int? orderCount,
    double? revenue,
  }) {
    return _UserSummary(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      orderCount: orderCount ?? this.orderCount,
      revenue: revenue ?? this.revenue,
    );
  }
}

/// ─────────────────────────────────────────────────────────────────────────────
/// Segmented filter
/// ─────────────────────────────────────────────────────────────────────────────
class _FilterSegment extends StatelessWidget {
  const _FilterSegment({required this.value, required this.onChanged});
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final children = <String, Widget>{
      'week': const Padding(
          padding: EdgeInsets.symmetric(vertical: 6), child: Text('Tuần')),
      'month': const Padding(
          padding: EdgeInsets.symmetric(vertical: 6), child: Text('Tháng')),
      'year': const Padding(
          padding: EdgeInsets.symmetric(vertical: 6), child: Text('Năm')),
      'all': const Padding(
          padding: EdgeInsets.symmetric(vertical: 6), child: Text('Tất cả')),
    };

    final selected = (value == 'custom') ? 'all' : value;
    return CupertinoSegmentedControl<String>(
      padding: const EdgeInsets.all(4),
      children: children,
      groupValue: selected,
      onValueChanged: onChanged,
    );
  }
}

/// ============================================================================
/// BIỂU ĐỒ 1: LINE – doanh thu theo ngày (Dark/Light aware)
/// ============================================================================
class _RevenueLineChart extends StatelessWidget {
  const _RevenueLineChart({required this.dailyRevenue});
  final Map<String, double> dailyRevenue;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;

    final entries = dailyRevenue.entries.toList()
      ..sort((a, b) =>
          DateFormat('dd/MM').parse(a.key).compareTo(
            DateFormat('dd/MM').parse(b.key),
          ));

    if (entries.isEmpty) {
      return Container(
        margin: const EdgeInsets.only(top: 4),
        padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: cs.outlineVariant),
        ),
        child: Center(
          child: Text(
            'Chưa có dữ liệu doanh thu',
            style: TextStyle(color: cs.onSurfaceVariant),
          ),
        ),
      );
    }

    final spots = <FlSpot>[];
    final labels = <String>[];

    double minY = double.infinity;
    double maxY = 0;

    for (var i = 0; i < entries.length; i++) {
      final v = entries[i].value;
      spots.add(FlSpot(i.toDouble(), v));
      labels.add(entries[i].key);
      if (v < minY) minY = v;
      if (v > maxY) maxY = v;
    }

    final dy = (maxY - minY).abs();
    final padTop = dy == 0 ? maxY * .25 + 800 : dy * .20;
    final padBottom = dy == 0 ? 0 : dy * .07;

    final axisColor = cs.onSurfaceVariant.withOpacity(.9);
    final lineColor = cs.tertiary;

    double safeMinY = 0;
    if (minY.isFinite && padBottom.isFinite) {
      safeMinY = minY - padBottom;
      if (safeMinY < 0) safeMinY = 0;
    }

    double safeMaxY = maxY;
    if (maxY.isFinite && padTop.isFinite) {
      safeMaxY = maxY + padTop;
    }
    if (!safeMaxY.isFinite || safeMaxY <= safeMinY) {
      safeMaxY = safeMinY + 1;
    }

    final yInterval = dy == 0 ? 1.0 : (safeMaxY / 4).ceilToDouble();
    final xInterval = (spots.length / 6).clamp(1, 6).toDouble();

    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
      decoration: BoxDecoration(
        color: isDark ? cs.surface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant),
        boxShadow: isDark
            ? null
            : [
          BoxShadow(
            color: Colors.black.withOpacity(.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: SizedBox(
        height: 220,
        child: LineChart(
          LineChartData(
            minX: 0,
            maxX: (spots.length - 1).toDouble(),
            minY: safeMinY,
            maxY: safeMaxY,
            gridData: FlGridData(
              show: true,
              drawVerticalLine: true,
              horizontalInterval: yInterval,
              verticalInterval: xInterval,
              getDrawingHorizontalLine: (_) => FlLine(
                color: axisColor.withOpacity(.18),
                strokeWidth: 1,
              ),
              getDrawingVerticalLine: (_) => FlLine(
                color: axisColor.withOpacity(.08),
                strokeWidth: 1,
              ),
            ),
            titlesData: FlTitlesData(
              topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 26,
                  interval: xInterval,
                  getTitlesWidget: (v, meta) {
                    final i = v.round();
                    if (i < 0 || i >= labels.length) {
                      return const SizedBox.shrink();
                    }
                    return Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        labels[i],
                        style: TextStyle(
                          fontSize: 11,
                          color: axisColor,
                        ),
                      ),
                    );
                  },
                ),
              ),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 44,
                  interval: yInterval,
                  getTitlesWidget: (v, meta) => Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Text(
                      _shortMoney(v),
                      style: TextStyle(
                        fontSize: 11,
                        color: axisColor,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            lineTouchData: LineTouchData(
              handleBuiltInTouches: true,
              touchTooltipData: LineTouchTooltipData(
                tooltipRoundedRadius: 10,
                tooltipPadding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                getTooltipItems: (touched) => touched.map((t) {
                  final idx = t.x.round();
                  final label =
                  (idx >= 0 && idx < labels.length) ? labels[idx] : '';
                  return LineTooltipItem(
                    '$label\n${_money(t.y)}',
                    TextStyle(
                      fontWeight: FontWeight.w700,
                      color: cs.onSurface,
                    ),
                  );
                }).toList(),
              ),
            ),
            lineBarsData: [
              LineChartBarData(
                spots: spots,
                isCurved: true,
                barWidth: 3,
                color: lineColor,
                isStrokeCapRound: true,
                dotData: FlDotData(
                  show: true,
                  getDotPainter: (s, p, bar, i) => FlDotCirclePainter(
                    radius: 3,
                    color: Colors.white,
                    strokeWidth: 2,
                    strokeColor: lineColor,
                  ),
                ),
                belowBarData: BarAreaData(
                  show: true,
                  gradient: LinearGradient(
                    colors: [
                      lineColor.withOpacity(.22),
                      lineColor.withOpacity(.0),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ],
            borderData: FlBorderData(
              show: true,
              border: Border(
                left: BorderSide(
                    color: Theme.of(context).colorScheme.outlineVariant),
                bottom: BorderSide(
                    color: Theme.of(context).colorScheme.outlineVariant),
                right: const BorderSide(color: Colors.transparent),
                top: const BorderSide(color: Colors.transparent),
              ),
            ),
          ),
        ),
      ),
    );
  }

  static String _shortMoney(num v) {
    if (v >= 1000000000) {
      return '${(v / 1000000000).toStringAsFixed(1)}B';
    }
    if (v >= 1000000) {
      return '${(v / 1000000).toStringAsFixed(1)}M';
    }
    if (v >= 1000) {
      return '${(v / 1000).toStringAsFixed(1)}K';
    }
    return v.toStringAsFixed(0);
  }

  static String _money(num v) {
    final f = NumberFormat.currency(
      locale: 'vi_VN',
      symbol: '₫',
      decimalDigits: 0,
    );
    return f.format(v);
  }
}

/// ============================================================================
/// BIỂU ĐỒ 2: BAR – doanh thu theo tháng (Dark/Light aware)
/// ============================================================================
class _RevenueBarChart extends StatelessWidget {
  const _RevenueBarChart({required this.monthlyRevenue});
  final Map<String, double> monthlyRevenue;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final items = monthlyRevenue.entries.toList()
      ..sort((a, b) =>
          int.parse(a.key.replaceAll('T', ''))
              .compareTo(int.parse(b.key.replaceAll('T', ''))));

    if (items.isEmpty) {
      return SizedBox(
        height: 220,
        child: Center(
          child: Text(
            'Chưa có dữ liệu theo tháng',
            style: TextStyle(color: cs.onSurfaceVariant),
          ),
        ),
      );
    }

    final axisColor = cs.onSurfaceVariant;
    final barColor = cs.secondary;

    final maxY =
    items.fold<double>(0, (m, e) => e.value > m ? e.value : m);
    final safeMaxY = (maxY <= 0 ? 1 : maxY) * 1.15;

    final groups = <BarChartGroupData>[
      for (var i = 0; i < items.length; i++)
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: items[i].value,
              color: barColor,
              width: 18,
              borderRadius:
              const BorderRadius.vertical(top: Radius.circular(8)),
              backDrawRodData: BackgroundBarChartRodData(
                show: true,
                toY: safeMaxY,
                color: axisColor.withOpacity(.06),
              ),
            ),
          ],
        ),
    ];

    return SizedBox(
      height: 240,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: safeMaxY,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) => FlLine(
              color: axisColor.withOpacity(.18),
              strokeWidth: 1,
            ),
          ),
          borderData: FlBorderData(
            show: true,
            border: Border(
              left: BorderSide(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
              bottom: BorderSide(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
              right: const BorderSide(color: Colors.transparent),
              top: const BorderSide(color: Colors.transparent),
            ),
          ),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 26,
                getTitlesWidget: (v, meta) {
                  final i = v.toInt();
                  if (i < 0 || i >= items.length) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      items[i].key,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: axisColor,
                      ),
                    ),
                  );
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 44,
                interval: safeMaxY / 4,
                getTitlesWidget: (v, meta) => Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Text(
                    _RevenueLineChart._shortMoney(v),
                    style: TextStyle(
                      fontSize: 11,
                      color: axisColor,
                    ),
                  ),
                ),
              ),
            ),
          ),
          barGroups: groups,
          barTouchData: BarTouchData(
            enabled: true,
            touchTooltipData: BarTouchTooltipData(
              tooltipRoundedRadius: 10,
              tooltipPadding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              getTooltipItem: (g, gi, r, ri) {
                final month = items[gi].key;
                final money = _RevenueLineChart._money(r.toY);
                return BarTooltipItem(
                  '$month\n$money',
                  TextStyle(
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface,
                  ),
                );
              },
            ),
          ),
        ),
        swapAnimationDuration: const Duration(milliseconds: 550),
        swapAnimationCurve: Curves.easeOutCubic,
      ),
    );
  }
}

/// ============================================================================
/// BIỂU ĐỒ 3: PIE – tỉ trọng đơn theo trạng thái
/// ============================================================================
class _OrderStatusPie extends StatelessWidget {
  const _OrderStatusPie({required this.statusCounts});
  final Map<String, int> statusCounts;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (statusCounts.isEmpty) {
      return SizedBox(
        height: 240,
        child: Center(
          child: Text(
            'Chưa có dữ liệu trạng thái đơn',
            style: TextStyle(color: cs.onSurfaceVariant),
          ),
        ),
      );
    }

    final total = statusCounts.values.fold<int>(0, (s, v) => s + v);

    final entries = statusCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final palette = <Color>[
      const Color(0xFF34C759),
      Theme.of(context).colorScheme.primary,
      const Color(0xFFFF9500),
      Theme.of(context).colorScheme.error,
      Theme.of(context).colorScheme.tertiary,
      const Color(0xFF5AC8FA),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 230,
          child: Stack(
            alignment: Alignment.center,
            children: [
              PieChart(
                PieChartData(
                  sectionsSpace: 3,
                  startDegreeOffset: -90,
                  centerSpaceRadius: 44,
                  borderData: FlBorderData(show: false),
                  sections: [
                    for (var i = 0; i < entries.length; i++)
                      _buildSection(
                        entry: entries[i],
                        index: i,
                        total: total,
                        palette: palette,
                      ),
                  ],
                  pieTouchData:
                  PieTouchData(touchCallback: (e, resp) {}),
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    total.toString(),
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                      color: cs.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'tổng đơn',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            for (var i = 0; i < entries.length; i++)
              Builder(
                builder: (_) {
                  final entry = entries[i];
                  final percent =
                  total == 0 ? 0 : (entry.value / total) * 100.0;
                  final label =
                      '${entry.key} (${entry.value} đơn – ${percent.toStringAsFixed(0)}%)';
                  return _LegendChip(
                    color: palette[i % palette.length],
                    label: label,
                  );
                },
              ),
          ],
        ),
      ],
    );
  }

  PieChartSectionData _buildSection({
    required MapEntry<String, int> entry,
    required int index,
    required int total,
    required List<Color> palette,
  }) {
    final baseColor = palette[index % palette.length];
    final value = entry.value;
    final fraction = total == 0 ? 0.0 : value / total;

    final radius = 54.0 + 14.0 * fraction;

    return PieChartSectionData(
      value: value.toDouble(),
      color: baseColor,
      radius: radius,
      title: '${(fraction * 100).toStringAsFixed(0)}%',
      titleStyle: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w700,
        fontSize: 12,
      ),
      titlePositionPercentageOffset: .67,
      borderSide: const BorderSide(
        color: Colors.white,
        width: 1.2,
      ),
    );
  }
}

class _LegendChip extends StatelessWidget {
  const _LegendChip({
    required this.color,
    required this.label,
  });

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: cs.outlineVariant.withOpacity(.7),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              color: cs.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

/// Card bọc từng biểu đồ trong bottom sheet – Apple-style
class _ChartSection extends StatelessWidget {
  const _ChartSection({
    required this.title,
    required this.child,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;

    final bg = isDark ? const Color(0xFF1C1C1E) : const Color(0xFFF5F5F7);

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: cs.outlineVariant.withOpacity(isDark ? 0.7 : 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14.5,
              color: cs.onSurface,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitle!,
              style: TextStyle(
                fontSize: 12,
                color: cs.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}
