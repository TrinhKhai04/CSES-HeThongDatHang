// 📦 ORDER CONTROLLER
// ------------------------------------------------------------
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';

import '../data/repositories/order_repository.dart';
import '../models/app_order.dart';
import '../models/order_item.dart';
import '../controllers/cart_controller.dart';
import '../data/repositories/voucher_repository.dart';
import '../config/warehouse_config.dart'; // WarehouseConfig.pickWarehouseFor / buildDefaultLegsForOrder
import '../services/route_service.dart'; // RouteService.fromTo / fromToVia

// ===================== CẤU HÌNH PHÍ SHIP (ADMIN QUẢN LÝ) =====================

class ShippingConfig {
  final double innerMaxKm; // <= km: nội thành
  final double nearOuterMaxKm; // <= km: ngoại thành gần
  final double farOuterMaxKm; // <= km: ngoại thành xa / cùng tỉnh
  final double interNearMaxKm; // <= km: liên tỉnh gần

  final double feeInner; // phí nội thành
  final double feeNearOuter; // phí ngoại thành gần
  final double feeFarOuter; // phí ngoại thành xa / cùng tỉnh
  final double feeInterNear; // phí liên tỉnh gần
  final double feeInterFar; // phí liên tỉnh rất xa (trên interNearMaxKm)

  final double freeShipThreshold; // ngưỡng free ship theo giá trị đơn (0 = tắt)

  ShippingConfig({
    required this.innerMaxKm,
    required this.nearOuterMaxKm,
    required this.farOuterMaxKm,
    required this.interNearMaxKm,
    required this.feeInner,
    required this.feeNearOuter,
    required this.feeFarOuter,
    required this.feeInterNear,
    required this.feeInterFar,
    required this.freeShipThreshold,
  });

  /// Giá trị mặc định (nếu chưa cấu hình trên Firestore)
  factory ShippingConfig.defaults() => ShippingConfig(
    innerMaxKm: 5, // d <= 5 km
    nearOuterMaxKm: 20, // d <= 20 km
    farOuterMaxKm: 60, // d <= 60 km
    interNearMaxKm: 300, // d <= 300 km
    feeInner: 20000, // 20k nội thành
    feeNearOuter: 30000, // 30k ngoại thành gần
    feeFarOuter: 40000, // 40k ngoại thành xa / cùng tỉnh
    feeInterNear: 50000, // 50k liên tỉnh gần
    feeInterFar: 70000, // 70k liên tỉnh rất xa
    freeShipThreshold:
    0, // 0 = tắt free ship, muốn bật thì đổi 1500000 chẳng hạn
  );

  factory ShippingConfig.fromMap(Map<String, dynamic>? m) {
    final d = ShippingConfig.defaults();
    if (m == null) return d;

    double _num(String key, double def) {
      final v = m[key];
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v) ?? def;
      return def;
    }

    return ShippingConfig(
      innerMaxKm: _num('innerMaxKm', d.innerMaxKm),
      nearOuterMaxKm: _num('nearOuterMaxKm', d.nearOuterMaxKm),
      farOuterMaxKm: _num('farOuterMaxKm', d.farOuterMaxKm),
      interNearMaxKm: _num('interNearMaxKm', d.interNearMaxKm),
      feeInner: _num('feeInner', d.feeInner),
      feeNearOuter: _num('feeNearOuter', d.feeNearOuter),
      feeFarOuter: _num('feeFarOuter', d.feeFarOuter),
      feeInterNear: _num('feeInterNear', d.feeInterNear),
      feeInterFar: _num('feeInterFar', d.feeInterFar),
      freeShipThreshold: _num('freeShipThreshold', d.freeShipThreshold),
    );
  }

  Map<String, dynamic> toMap() => {
    'innerMaxKm': innerMaxKm,
    'nearOuterMaxKm': nearOuterMaxKm,
    'farOuterMaxKm': farOuterMaxKm,
    'interNearMaxKm': interNearMaxKm,
    'feeInner': feeInner,
    'feeNearOuter': feeNearOuter,
    'feeFarOuter': feeFarOuter,
    'feeInterNear': feeInterNear,
    'feeInterFar': feeInterFar,
    'freeShipThreshold': freeShipThreshold,
  };
}

class OrderController extends ChangeNotifier {
  final OrderRepository _repo = OrderRepository();
  final Uuid _uuid = const Uuid();

  double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  int _toInt(dynamic v, [int def = 0]) {
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? def;
    return def;
  }

  /// 🆕 Sinh mã đơn thân thiện: CSES-ddMM-XXXXABCD
  String _generateOrderCode() {
    final now = DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    final rand = _uuid.v4().substring(0, 8).toUpperCase();
    return 'CSES-${two(now.day)}${two(now.month)}-$rand';
  }

  /// Đọc cấu hình phí ship từ Firestore: settings/shippingConfig
  Future<ShippingConfig> _getShippingConfig() async {
    final db = FirebaseFirestore.instance;
    final doc = await db.collection('settings').doc('shippingConfig').get();
    return ShippingConfig.fromMap(doc.data() as Map<String, dynamic>?);
  }

  // ======================= XU HELPER =======================

  /// Trừ Xu của user khi checkout (nếu usedXu > 0)
  Future<void> _spendXuOnCheckout({
    required String customerId,
    required int usedXu,
  }) async {
    if (usedXu <= 0) return;
    final fs = FirebaseFirestore.instance;
    final userRef = fs.collection('users').doc(customerId);

    await fs.runTransaction((tx) async {
      final snap = await tx.get(userRef);
      final data = snap.data() as Map<String, dynamic>? ?? {};

      // Đọc số xu hiện tại: ưu tiên xuBalance, fallback sang coins cũ
      final current = _toInt(data['xuBalance'] ?? data['coins'], 0);

      if (current < usedXu) {
        throw StateError('Số Xu của bạn không đủ, vui lòng thử lại.');
      }

      final newBalance = current - usedXu;

      // Ghi đồng bộ cả 2 field để các màn cũ (dùng "coins") vẫn đúng
      tx.update(userRef, {
        'xuBalance': newBalance,
        'coins': newBalance,
      });
    });
  }

  /// Hoàn lại Xu trong transaction khi hủy đơn
  void _refundXuInTx({
    required Transaction tx,
    required FirebaseFirestore fs,
    required String customerId,
    required int usedXu,
  }) {
    if (usedXu <= 0) return;
    final userRef = fs.collection('users').doc(customerId);
    tx.update(userRef, {
      'xuBalance': FieldValue.increment(usedXu),
      'coins': FieldValue.increment(usedXu),
    });
  }

  /// 👉 Cộng Xu thưởng cho đơn, chỉ gọi **sau khi user đánh giá xong**.
  /// Hàm này an toàn, gọi nhiều lần cũng chỉ cộng 1 lần nhờ field coinsRewarded.
  Future<void> rewardCoinsForOrder({
    required String orderId,
    required String customerId,
  }) async {
    final fs = FirebaseFirestore.instance;
    final rootRef = fs.collection('orders').doc(orderId);
    final userOrderRef =
    fs.collection('users').doc(customerId).collection('orders').doc(orderId);
    final userRef = fs.collection('users').doc(customerId);

    const successStatuses = ['delivered', 'done', 'completed'];

    await fs.runTransaction((tx) async {
      final snap = await tx.get(rootRef);
      if (!snap.exists) return;

      final data = snap.data() as Map<String, dynamic>;
      final int reward = (data['rewardCoins'] as num?)?.toInt() ?? 0;
      final bool already = data['coinsRewarded'] == true;
      final String status = (data['status'] ?? 'pending').toString();

      if (reward <= 0 || already || !successStatuses.contains(status)) {
        return;
      }

      // + Xu vào ví user (đồng bộ cả xuBalance + coins)
      tx.update(userRef, {
        'xuBalance': FieldValue.increment(reward),
        'coins': FieldValue.increment(reward),
      });

      // Đánh dấu đã cộng Xu (root + user subcollection)
      final now = FieldValue.serverTimestamp();
      tx.update(rootRef, {
        'coinsRewarded': true,
        'updatedAt': now,
      });
      tx.set(
        userOrderRef,
        {
          'coinsRewarded': true,
          'updatedAt': now,
        },
        SetOptions(merge: true),
      );
    });
  }

  // ============================== CHECKOUT ==============================
  Future<String> checkout(
      String customerId,
      CartController cart, {
        bool alsoWriteToRoot = true,
        BuildContext? context,
        Map<String, dynamic>? shippingAddress,
        String? note,

        // 👇 thông tin phương thức vận chuyển + phí override
        String? shippingMethodId,
        String? shippingMethodName,
        String? shippingMethodSubtitle,
        double? shippingFeeOverride,

        // 🆕 thông tin phương thức thanh toán
        String? paymentMethodKey, // vd: 'cod' | 'bank_transfer' | 'momo'
        String? paymentMethodName, // vd: 'Thanh toán khi nhận hàng (COD)'

        // 👇 Xu dùng cho đơn (nhận từ UI, tương đương coinsUsed / coinDiscount)
        int usedXu = 0,
        double xuDiscount = 0,

        // 👇 Xu thưởng (có thể truyền từ UI, nếu null thì controller tự tính lại)
        int? rewardCoins,
      }) async {
    final messenger = (context == null) ? null : ScaffoldMessenger.of(context);

    // Chỉ lấy các item đang được chọn (giống UI Checkout)
    final selectedItems =
    cart.items.where((it) => cart.selectedKeys.contains(it.key)).toList();

    if (selectedItems.isEmpty) {
      throw StateError('Không có sản phẩm nào được chọn');
    }

    // id đơn hàng
    final orderId = _uuid.v4();

    // 🆕 Mã đơn thân thiện
    final orderCode = _generateOrderCode();

    final items =
    selectedItems.map((it) => _mapCartItemToOrderItem(it, orderId)).toList();

    // sanitize Xu
    if (usedXu < 0) usedXu = 0;
    if (xuDiscount < 0) xuDiscount = 0;

    // 👉 Công thức:
    // subtotal: tổng tiền hàng (CHỈ sản phẩm được chọn)
    // discount: giảm giá voucher
    // xuDiscount: giảm giá do Xu đổi
    // shippingFee: phí vận chuyển
    // total = subtotal - discount - xuDiscount + shippingFee
    final subtotal = cart.selectedSubtotal;

    // phí gốc lấy từ cart (đã ước tính bằng OSRM + ShippingConfig)
    final rawShippingFromCart =
    cart.shippingFee < 0 ? 0.0 : cart.shippingFee;

    // nếu có override từ phương thức (Nhanh/Tiết kiệm/Hỏa tốc...) thì dùng
    final shippingFee = shippingFeeOverride != null
        ? (shippingFeeOverride < 0 ? 0.0 : shippingFeeOverride)
        : rawShippingFromCart;

    final discount = cart.discountAmount; // chỉ voucher
    final total = subtotal - discount - xuDiscount + shippingFee;

    // 🟠 TÍNH XU THƯỞNG (nếu chưa truyền từ UI)
    final double coinBaseForReward =
    (subtotal - discount - xuDiscount).clamp(0, double.infinity);
    final int rewardCoinsFinal =
        rewardCoins ?? (coinBaseForReward <= 0 ? 0 : (coinBaseForReward ~/ 1000));

    final voucher = cart.voucherSnapshot == null
        ? null
        : {
      ...Map<String, dynamic>.from(cart.voucherSnapshot!),
      'appliedAmount': discount,
      'subtotalAtApply': subtotal,
    };

    // trừ quota voucher
    await _consumeVoucherQuotaIfAny(
      voucherSnap: voucher,
      customerId: customerId,
    );

    // trừ Xu (nếu có dùng)
    await _spendXuOnCheckout(customerId: customerId, usedXu: usedXu);

    final double? toLat = _toDouble(shippingAddress?['lat']) ??
        _toDouble(shippingAddress?['toLat']);
    final double? toLng = _toDouble(shippingAddress?['lng']) ??
        _toDouble(shippingAddress?['toLng']);

    // 🆕 Lấy text tỉnh/thành (tuỳ bạn lưu field nào)
    final String? provinceText = (shippingAddress?['province'] ??
        shippingAddress?['toProvince'] ??
        shippingAddress?['city'])
        ?.toString();

    // 🆕 Chọn kho phù hợp (gần toạ độ hoặc theo tỉnh) – kho xuất phát
    final selectedWh = WarehouseConfig.pickWarehouseFor(
      provinceText: provinceText,
      destLat: toLat,
      destLng: toLng,
    ); // đa kho

    final double whLat = selectedWh.location.latitude;
    final double whLng = selectedWh.location.longitude;

    final now = Timestamp.now();
    final order = AppOrder(
      id: orderId,
      orderCode: orderCode,          // 👈 THÊM DÒNG NÀY
      customerId: customerId,
      subtotal: subtotal,
      discount: discount,
      shipping: shippingFee,
      total: total,
      status: 'pending',
      voucher: voucher,
      createdAt: now,
      updatedAt: now,

      // 🟡 Xu đã dùng
      usedXu: usedXu,
      xuDiscount: xuDiscount,

      // 🟠 Xu thưởng (chỉ được cộng sau khi đánh giá)
      rewardCoins: rewardCoinsFinal,
      coinsRewarded: false,

      // 🆕 payment
      paymentMethodKey: paymentMethodKey,
      paymentMethodName: paymentMethodName,

      // tọa độ
      whLat: whLat,
      whLng: whLng,
      toLat: toLat,
      toLng: toLng,

      // hiển thị
      whName: selectedWh.name, // tên kho thực tế
      toName: (shippingAddress?['name'] ?? shippingAddress?['toName'])
          ?.toString(),
      toPhone: (shippingAddress?['phone'] ?? shippingAddress?['toPhone'])
          ?.toString(),
      shippingNote: note,

      // phương thức vận chuyển
      shippingMethodId: shippingMethodId,
      shippingMethodName: shippingMethodName,
      shippingMethodSubtitle: shippingMethodSubtitle,
    );

    await _repo.createOrder(order, items, alsoWriteToRoot: alsoWriteToRoot);

    // ghi statusTs.pending ngay khi tạo
    await _writeStatusTs(orderId: orderId, key: 'pending');

    // Lưu route + legs nếu có toLat/toLng
    if (toLat != null && toLng != null) {
      await _calcAndSaveRoute(
        orderId: orderId,
        customerId: customerId,
        whLat: whLat,
        whLng: whLng,
        whCode: selectedWh.code,
        whName: selectedWh.name,
        toLat: toLat,
        toLng: toLng,
        toProvince: provinceText,
        alsoWriteToRoot: alsoWriteToRoot,
      );
    }

    // extra ghi thêm vào document (merge)
    final extra = <String, dynamic>{
      // 🆕 lưu orderCode vào cả user doc & root doc
      'orderCode': orderCode,

      if (shippingAddress != null)
        'shippingAddress': Map<String, dynamic>.from(shippingAddress),
      if (note != null && note.isNotEmpty) 'note': note,

      // shipping method
      if (shippingMethodId != null) 'shippingMethodId': shippingMethodId,
      if (shippingMethodName != null) 'shippingMethodName': shippingMethodName,
      if (shippingMethodSubtitle != null)
        'shippingMethodSubtitle': shippingMethodSubtitle,

      // 🆕 payment
      if (paymentMethodKey != null) 'paymentMethodKey': paymentMethodKey,
      if (paymentMethodName != null) 'paymentMethodName': paymentMethodName,

      // Xu đã dùng
      if (usedXu > 0) 'usedXu': usedXu,
      if (xuDiscount > 0) 'xuDiscount': xuDiscount,

      // Xu thưởng
      if (rewardCoinsFinal > 0) 'rewardCoins': rewardCoinsFinal,
      if (rewardCoinsFinal > 0) 'coinsRewarded': false,
    };
    if (extra.isNotEmpty) {
      final db = FirebaseFirestore.instance;
      final userRef =
      db.collection('users').doc(customerId).collection('orders').doc(orderId);
      final rootRef = db.collection('orders').doc(orderId);
      final batch = db.batch();
      batch.set(userRef, extra, SetOptions(merge: true));
      if (alsoWriteToRoot) {
        batch.set(rootRef, extra, SetOptions(merge: true));
      }
      await batch.commit();
    }

    await _addNotification(customerId, orderId, total);
    await _trySendEmail(customerId, orderId, total);

    cart.clear();
    notifyListeners();

    messenger?.showSnackBar(const SnackBar(
      content: Text('🎉 Mua hàng thành công! Email xác nhận đã được gửi.'),
      backgroundColor: Colors.green,
    ));

    // 🔙 trả về orderId cho CheckoutScreen điều hướng theo payment method
    return orderId;
  }

  // 👉 SOLD COUNT helper: gộp qty theo productId rồi tăng soldCount (dùng cho script/manual)
  Future<void> _increaseSoldCountForOrderItems(List<OrderItem> items) async {
    if (items.isEmpty) return;
    final fs = FirebaseFirestore.instance;

    final Map<String, int> qtyByProduct = {};
    for (final it in items) {
      final pid = it.productId;
      final qty = it.qty;
      if (pid.isEmpty || qty <= 0) continue;
      qtyByProduct[pid] = (qtyByProduct[pid] ?? 0) + qty;
    }

    if (qtyByProduct.isEmpty) return;

    final batch = fs.batch();
    qtyByProduct.forEach((pid, qty) {
      final ref = fs.collection('products').doc(pid);
      batch.update(ref, {
        'soldCount': FieldValue.increment(qty),
      });
    });

    try {
      await batch.commit();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ _increaseSoldCountForOrderItems error: $e');
      }
    }
  }

  /// 🔁 ADMIN TOOL: rebuild soldCount từ lịch sử đơn hàng
  /// - Reset toàn bộ soldCount về 0
  /// - Duyệt các đơn đã giao (delivered/done/completed) và cộng qty theo productId
  Future<void> rebuildSoldCountFromOrders() async {
    final fs = FirebaseFirestore.instance;

    if (kDebugMode) {
      debugPrint('🔧 Bắt đầu rebuild soldCount từ orders...');
    }

    // 1) Reset soldCount về 0 cho tất cả product
    final prodsSnap = await fs.collection('products').get();
    const int batchLimit = 400;

    WriteBatch batch = fs.batch();
    int count = 0;
    for (final doc in prodsSnap.docs) {
      batch.set(doc.reference, {'soldCount': 0}, SetOptions(merge: true));
      count++;
      if (count == batchLimit) {
        await batch.commit();
        batch = fs.batch();
        count = 0;
      }
    }
    if (count > 0) {
      await batch.commit();
    }

    // 2) Duyệt toàn bộ orders, gom qty theo productId cho các đơn đã giao
    final Map<String, int> soldByProduct = {};
    final ordersSnap = await fs.collection('orders').get();
    const successStatuses = ['delivered', 'done', 'completed'];

    for (final o in ordersSnap.docs) {
      final data = o.data();
      final status = (data['status'] ?? 'pending').toString();
      if (!successStatuses.contains(status)) continue;

      final itemsSnap = await o.reference.collection('items').get();
      for (final it in itemsSnap.docs) {
        final d = it.data();

        final pid = (d['productId'] ?? '').toString();
        if (pid.isEmpty) continue;

        final rawQty = d['qty'];
        int qty;
        if (rawQty is int) {
          qty = rawQty;
        } else if (rawQty is num) {
          qty = rawQty.toInt();
        } else {
          qty = int.tryParse('$rawQty') ?? 0;
        }
        if (qty <= 0) continue;

        soldByProduct[pid] = (soldByProduct[pid] ?? 0) + qty;
      }
    }

    // 3) Ghi soldCount mới lên products
    batch = fs.batch();
    count = 0;
    for (final entry in soldByProduct.entries) {
      final pid = entry.key;
      final qty = entry.value;
      final ref = fs.collection('products').doc(pid);
      batch.set(ref, {'soldCount': qty}, SetOptions(merge: true));
      count++;
      if (count == batchLimit) {
        await batch.commit();
        batch = fs.batch();
        count = 0;
      }
    }
    if (count > 0) {
      await batch.commit();
    }

    if (kDebugMode) {
      debugPrint('✅ Rebuild soldCount xong cho ${soldByProduct.length} sản phẩm');
    }
  }

  // ===================== Voucher consume =====================
  Future<void> _consumeVoucherQuotaIfAny({
    required Map<String, dynamic>? voucherSnap,
    required String customerId,
  }) async {
    if (voucherSnap == null) return;
    final db = FirebaseFirestore.instance;
    final repo = VoucherRepository();

    String? voucherId = (voucherSnap['id'] as String?)?.trim();
    if (voucherId == null || voucherId.isEmpty) {
      final code = (voucherSnap['code'] as String?)?.toUpperCase();
      if (code == null || code.isEmpty) return;
      final qs = await db
          .collection('vouchers')
          .where('code', isEqualTo: code)
          .limit(1)
          .get();
      if (qs.docs.isEmpty) return;
      voucherId = qs.docs.first.id;
    }

    final v = await repo.getById(voucherId);
    if (v == null) throw StateError('Voucher không tồn tại');

    if ((v.perUserLimit ?? 0) > 0) {
      await repo.consumeOneForUser(voucherId: v.id, userId: customerId);
    } else {
      await repo.consumeOne(voucherId: v.id);
    }
  }

  // ===================== Notifications / Email =====================

  /// 🆕 Lấy mã hiển thị cho đơn (orderCode nếu có, fallback orderId)
  Future<String> _getDisplayOrderCode(String orderId) async {
    try {
      final snap =
      await FirebaseFirestore.instance.collection('orders').doc(orderId).get();
      final data = snap.data();
      if (data == null) return orderId;
      final raw = (data['orderCode'] ?? '').toString().trim();
      if (raw.isEmpty) return orderId;
      return raw;
    } catch (_) {
      return orderId;
    }
  }

  Future<void> _addNotification(
      String customerId, String orderId, double total) async {
    final col = FirebaseFirestore.instance.collection('notifications');

    final code = await _getDisplayOrderCode(orderId);

    await col.add({
      'userId': customerId,
      'title': 'Mua hàng thành công',
      'message':
      'Đơn hàng #$code trị giá ${total.toStringAsFixed(0)}₫ đã được đặt thành công.',
      'createdAt': FieldValue.serverTimestamp(),
      'isRead': false,
      'orderId': orderId,
    });
  }

  Future<void> _trySendEmail(
      String customerId, String orderId, double total) async {
    final auth = FirebaseAuth.instance;
    await auth.currentUser?.reload();
    final user = auth.currentUser;
    String? email = user?.email;
    String? name = user?.displayName ?? 'Khách hàng';

    if (email == null || email.isEmpty) {
      final snap =
      await FirebaseFirestore.instance.collection('users').doc(customerId).get();
      email = snap.data()?['email'];
      name = snap.data()?['name'] ?? name;
    }
    if (email == null || email.isEmpty) return;

    // 🔹 Lấy danh sách sản phẩm của đơn để đưa vào email
    final items = await _repo.getItems(orderId, customerId: customerId);

    String? firstImageUrl;
    String? firstItemName;

    for (final it in items) {
      final opts = it.options ?? const {};
      final name = (opts['name'] ?? 'Sản phẩm').toString();
      final img = (opts['imageUrl'] ?? '').toString().trim();

      // Lưu tên + hình sản phẩm đầu tiên
      firstItemName ??= name;
      if (firstImageUrl == null && img.isNotEmpty) {
        firstImageUrl = img;
      }
    }

    // 🔹 HTML bảng sản phẩm
    final itemsHtml = _buildOrderItemsHtml(items);

    // 🔹 Lấy mã hiển thị để đưa vào email
    final displayCode = await _getDisplayOrderCode(orderId);

    await _sendEmail(
      toEmail: email,
      toName: name ?? 'Khách hàng',
      orderId: displayCode, // dùng mã hiển thị
      total: total,
      firstImageUrl: firstImageUrl,
      firstItemName: firstItemName,
      orderItemsHtml: itemsHtml,
    );
  }

  Future<void> _sendEmail({
    required String toEmail,
    required String toName,
    required String orderId,
    required double total,

    // 👇 thêm tham số để hiển thị đẹp hơn trong email
    String? firstImageUrl,
    String? firstItemName,
    String? orderItemsHtml,
  }) async {
    const serviceId = 'service_cses';
    const templateId = 'template_ufi6hin';
    const publicKey = 'c0hLsmQaRd4906iTK';
    final url = Uri.parse('https://api.emailjs.com/api/v1.0/email/send');

    await http.post(
      url,
      headers: {
        'origin': 'http://localhost',
        'Content-Type': 'application/json',
      },
      body: json.encode({
        'service_id': serviceId,
        'template_id': templateId,
        'user_id': publicKey,
        'template_params': {
          'to_email': toEmail,
          'to_name': toName,
          'order_id': orderId, // đã là mã hiển thị
          'order_total': '${total.toStringAsFixed(0)}₫',
          'order_date': DateTime.now().toString().substring(0, 16),

          // 🔹 param mới cho template EmailJS
          'first_image_url': firstImageUrl ?? '',
          'first_item_name': firstItemName ?? '',
          'order_items_html': orderItemsHtml ?? '',
        },
      }),
    );
  }

  // ===================== Status / Lists =====================
  Future<void> updateStatus(
      String orderId,
      String newStatus, {
        required String customerId,
        String? note,
      }) async {
    await _repo.updateStatus(orderId, newStatus, customerId: customerId);
    await _afterStatusChanged(
      orderId: orderId,
      customerId: customerId,
      newStatus: newStatus,
      note: note,
    );
    notifyListeners();
  }

  Stream<List<AppOrder>> watchAllOrders({required String customerId}) =>
      _repo.getStream(customerId: customerId);

  Future<List<AppOrder>> listOrders({required String customerId}) =>
      _repo.listOrders(customerId: customerId);

  Future<List<OrderItem>> getItems(
      String orderId, {
        required String customerId,
      }) =>
      _repo.getItems(orderId, customerId: customerId);

  // ===================== ADMIN UPDATE + HOÀN TỒN + HOÀN XU KHI HUỶ =====================
  Future<bool> adminUpdateStatusGuarded({
    required String orderId,
    required String customerId,
    required String newStatus,
    String? note,
  }) async {
    final fs = FirebaseFirestore.instance;
    final rootRef = fs.collection('orders').doc(orderId);
    final userRef =
    fs.collection('users').doc(customerId).collection('orders').doc(orderId);

    // helper: trạng thái được coi là "hoàn tất"
    bool _isSuccessStatus(String s) {
      return s == 'done' || s == 'delivered' || s == 'completed';
    }

    // --- 1) Lấy danh sách items để hoàn kho / tính soldCount nếu cần ---
    final restockItems = <Map<String, dynamic>>[];

    // Ưu tiên lấy ở root: orders/{orderId}/items
    var itemsSnap = await rootRef.collection('items').get();

    // Nếu root không có items -> fallback sang users/{uid}/orders/{orderId}/items
    if (itemsSnap.docs.isEmpty) {
      itemsSnap = await userRef.collection('items').get();
    }

    for (final doc in itemsSnap.docs) {
      final data = doc.data();
      final pid = (data['productId'] ?? '').toString();

      // qty
      final rawQty = data['qty'];
      int qty;
      if (rawQty is int) {
        qty = rawQty;
      } else if (rawQty is num) {
        qty = rawQty.toInt();
      } else {
        qty = int.tryParse('$rawQty') ?? 0;
      }

      // variantId lấy từ field trực tiếp hoặc trong options
      String? variantId;
      if (data['variantId'] is String &&
          (data['variantId'] as String).trim().isNotEmpty) {
        variantId = (data['variantId'] as String).trim();
      } else if (data['options'] is Map) {
        final opts = data['options'] as Map;
        final v = opts['variantId'];
        if (v is String && v.trim().isNotEmpty) {
          variantId = v.trim();
        }
      }

      if (pid.isNotEmpty && qty > 0) {
        restockItems.add({'pid': pid, 'qty': qty, 'variantId': variantId});
      }
    }

    try {
      final ok = await fs.runTransaction<bool>((tx) async {
        final orderSnap = await tx.get(rootRef);
        if (!orderSnap.exists) return false;

        final data =
        orderSnap.data() as Map<String, dynamic>; // order root data
        final currentStatus = (data['status'] ?? 'pending').toString();

        // 🟡 Xu đã dùng cho đơn này
        final int usedXu = (data['usedXu'] as num?)?.toInt() ?? 0;

        // Đơn đã kết thúc (done/cancelled) thì không cho đổi nữa
        if (currentStatus == 'done' || currentStatus == 'cancelled') {
          return false;
        }

        // Không làm gì nếu trùng trạng thái
        if (currentStatus == newStatus) {
          return false;
        }

        // --- 2) Nếu chuyển sang cancelled -> hoàn lại tồn kho + hoàn Xu ---
        if (newStatus == 'cancelled') {
          for (final it in restockItems) {
            final String pid = it['pid'] as String;
            final int qty = it['qty'] as int;
            final String? variantId = it['variantId'] as String?;

            if (variantId != null && variantId.isNotEmpty) {
              // sản phẩm có variant -> cộng vào stock của variant
              final vRef = fs
                  .collection('products')
                  .doc(pid)
                  .collection('variants')
                  .doc(variantId);
              tx.update(vRef, {
                'stock': FieldValue.increment(qty),
              });
            } else {
              // fallback: cộng vào stock ngay trên product
              final productRef = fs.collection('products').doc(pid);
              tx.update(productRef, {
                'stock': FieldValue.increment(qty),
              });
            }
          }

          // ✅ Hoàn lại Xu một lần duy nhất
          _refundXuInTx(
            tx: tx,
            fs: fs,
            customerId: customerId,
            usedXu: usedXu,
          );
        }

        // --- 3) Nếu lần đầu chuyển sang trạng thái HOÀN TẤT -> cộng soldCount ---
        final bool wasSuccess = _isSuccessStatus(currentStatus);
        final bool willSuccess = _isSuccessStatus(newStatus);

        if (!wasSuccess && willSuccess) {
          for (final it in restockItems) {
            final String pid = it['pid'] as String;
            final int qty = it['qty'] as int;

            final productRef = fs.collection('products').doc(pid);
            tx.update(productRef, {
              'soldCount': FieldValue.increment(qty),
            });
          }
        }

        final now = FieldValue.serverTimestamp();
        tx.update(rootRef, {
          'status': newStatus,
          'updatedAt': now,
        });

        // user doc có thể chưa tồn tại -> dùng set(merge: true)
        tx.set(
          userRef,
          {
            'status': newStatus,
            'updatedAt': now,
          },
          SetOptions(merge: true),
        );

        return true;
      });

      if (ok) {
        await _afterStatusChanged(
          orderId: orderId,
          customerId: customerId,
          newStatus: newStatus,
          note: note,
        );
        notifyListeners();
      }

      return ok;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ adminUpdateStatusGuarded error: $e');
      }
      return false;
    }
  }

  // ===================== USER TỰ HUỶ ĐƠN =====================
  Future<void> cancelMyOrder({
    required String orderId,
    required String customerId,
  }) async {
    final ok = await adminUpdateStatusGuarded(
      orderId: orderId,
      customerId: customerId,
      newStatus: 'cancelled',
      note: 'Khách yêu cầu hủy đơn hàng',
    );

    if (!ok) {
      throw StateError(
        'Không thể hủy đơn. Đơn có thể đã hoàn tất hoặc đã bị hủy trước đó.',
      );
    }
  }

  // ---- Sau khi đổi trạng thái: cập nhật statusTs + event + track khởi tạo
  Future<void> _afterStatusChanged({
    required String orderId,
    required String customerId,
    required String newStatus,
    String? note,
  }) async {
    await _writeStatusTs(orderId: orderId, key: newStatus);

    // Tạo event ở root
    await _addEvent(
      orderId,
      title: _titleForStatus(newStatus),
      note: note ?? '',
    );

    // Nếu chuyển sang processing → ghi điểm track đầu tiên ở kho
    if (newStatus == 'processing') {
      await _addInitialTrackPoint(orderId);
    }
  }

  String _titleForStatus(String s) {
    switch (s) {
      case 'pending':
        return 'Đơn đã tạo';
      case 'processing':
        return 'Đã rời kho';
      case 'shipping':
        return 'Đang giao hàng';
      case 'delivered':
      case 'done':
      case 'completed':
        return 'Giao thành công';
      case 'cancelled':
        return 'Đơn đã hủy';
      default:
        return 'Cập nhật trạng thái';
    }
  }

  Future<void> _addEvent(
      String orderId, {
        required String title,
        String note = '',
      }) async {
    final events = FirebaseFirestore.instance
        .collection('orders')
        .doc(orderId)
        .collection('events');
    await events.add({
      'title': title,
      'note': note,
      'ts': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _writeStatusTs({
    required String orderId,
    required String key,
  }) async {
    final fs = FirebaseFirestore.instance;
    final tsPath = 'statusTs.$key';

    final rootRef = fs.collection('orders').doc(orderId);
    await rootRef.set(
      {
        tsPath: FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  /// 🆕 Ghi điểm track đầu tiên theo **kho của đơn** (whLat/whLng) – fallback kho mặc định
  Future<void> _addInitialTrackPoint(String orderId) async {
    final fs = FirebaseFirestore.instance;
    final tracks = fs.collection('orders').doc(orderId).collection('tracks');

    // chỉ ghi nếu chưa có điểm nào
    final exist = await tracks.limit(1).get();
    if (exist.docs.isNotEmpty) return;

    double lat;
    double lng;

    final orderSnap = await fs.collection('orders').doc(orderId).get();
    if (orderSnap.exists) {
      final data = orderSnap.data() as Map<String, dynamic>?;
      final whLat = (data?['whLat'] as num?)?.toDouble();
      final whLng = (data?['whLng'] as num?)?.toDouble();
      if (whLat != null && whLng != null) {
        lat = whLat;
        lng = whLng;
      } else {
        final fallback = WarehouseConfig.pos;
        lat = fallback.latitude;
        lng = fallback.longitude;
      }
    } else {
      final fallback = WarehouseConfig.pos;
      lat = fallback.latitude;
      lng = fallback.longitude;
    }

    await tracks.add({
      'lat': lat,
      'lng': lng,
      'ts': FieldValue.serverTimestamp(),
      'note': 'Xuất phát từ kho',
    });
  }

  OrderItem _mapCartItemToOrderItem(CartItemVM it, String orderId) {
    final price = it.unitPrice < 0 ? 0.0 : it.unitPrice;
    final qty = it.qty < 1 ? 1 : it.qty;
    final opts = (it.options is Map)
        ? Map<String, dynamic>.from(it.options!)
        : <String, dynamic>{};

    opts.addAll({
      'name': it.product.name,
      'imageUrl': opts['imageUrl'] ??
          (it.product as dynamic).imageUrl ??
          (it.toJson()['imageUrl']),
      'variantId': opts['variantId'],
      'variantName': opts['variantName'] ??
          ((opts['size'] != null || opts['color'] != null)
              ? '${opts['size'] ?? ''} ${opts['color'] ?? ''}'.trim()
              : null),
    });

    return OrderItem(
      id: _uuid.v4(),
      orderId: orderId,
      productId: it.product.id,
      qty: qty,
      price: price,
      variantId: (opts['variantId'] is String &&
          (opts['variantId'] as String).isNotEmpty)
          ? opts['variantId'] as String
          : null,
      options: Map<String, dynamic>.from(opts),
    );
  }

  // ---------- HTML helper cho email ----------
  String _buildOrderItemsHtml(List<OrderItem> items) {
    final buf = StringBuffer();

    buf.writeln(
      '<table style="width:100%;border-collapse:collapse;'
          'font-family:-apple-system,BlinkMacSystemFont,\'Segoe UI\',sans-serif;'
          'font-size:14px;">',
    );
    buf.writeln('<thead>');
    buf.writeln(
      '<tr>'
          '<th align="left" style="padding:8px 4px;border-bottom:1px solid #e5e7eb;">Sản phẩm</th>'
          '<th align="center" style="padding:8px 4px;border-bottom:1px solid #e5e7eb;">SL</th>'
          '<th align="right" style="padding:8px 4px;border-bottom:1px solid #e5e7eb;">Giá</th>'
          '</tr>',
    );
    buf.writeln('</thead>');
    buf.writeln('<tbody>');

    for (final it in items) {
      final opts = it.options ?? const {};
      final name = (opts['name'] ?? 'Sản phẩm').toString();
      final variant =
      (opts['variantName'] ?? '${opts['size'] ?? ''} ${opts['color'] ?? ''}')
          .toString()
          .trim();
      final img = (opts['imageUrl'] ?? '').toString().trim();
      final qty = it.qty;
      final unit = it.price < 0 ? 0.0 : it.price;
      final lineTotal = unit * qty;

      final unitStr = '${unit.toStringAsFixed(0)}₫';
      final lineStr = '${lineTotal.toStringAsFixed(0)}₫';

      final imgCell = img.isNotEmpty
          ? '<img src="$img" alt="$name" '
          'style="width:48px;height:48px;object-fit:cover;'
          'border-radius:8px;border:1px solid #e5e7eb;margin-right:8px;" />'
          : '<div style="width:48px;height:48px;border-radius:8px;'
          'border:1px solid #e5e7eb;margin-right:8px;'
          'display:inline-flex;align-items:center;justify-content:center;'
          'color:#9ca3af;font-size:11px;">No image</div>';

      final nameCell = variant.isNotEmpty
          ? '$name<br/><span style="color:#6b7280;font-size:12px;">$variant</span>'
          : name;

      buf.writeln('<tr>');

      // cột hình + tên
      buf.writeln(
        '<td style="padding:8px 4px;vertical-align:middle;">'
            '<div style="display:flex;align-items:center;">'
            '$imgCell'
            '<div>$nameCell</div>'
            '</div>'
            '</td>',
      );

      // cột SL
      buf.writeln(
        '<td style="padding:8px 4px;vertical-align:middle;text-align:center;">'
            'x$qty'
            '</td>',
      );

      // cột giá
      buf.writeln(
        '<td style="padding:8px 4px;vertical-align:middle;text-align:right;white-space:nowrap;">'
            '$unitStr<br/><span style="color:#6b7280;font-size:12px;">$lineStr</span>'
            '</td>',
      );

      buf.writeln('</tr>');
    }

    buf.writeln('</tbody>');
    buf.writeln('</table>');

    return buf.toString();
  }

  // ===================== ƯỚC TÍNH PHÍ VẬN CHUYỂN =====================

  /// Ước tính phí ship cho GIỎ HÀNG dựa trên khoảng cách kho -> địa chỉ khách.
  /// Gọi hàm này ở màn Checkout sau khi đã có toLat/toLng từ AppAddress.
  Future<double> estimateShippingFeeForCart({
    required CartController cart,
    required double toLat,
    required double toLng,
  }) async {
    // chọn kho gần vị trí giao nhất
    final selectedWh = WarehouseConfig.pickWarehouseFor(
      destLat: toLat,
      destLng: toLng,
    );
    final wh = selectedWh.location;

    // Đọc config phí ship do admin cấu hình
    final cfg = await _getShippingConfig();

    // Gọi OSRM (polyline) để lấy khoảng cách
    RouteResult? route;
    try {
      route = await RouteService.fromTo(
        fromLat: wh.latitude,
        fromLng: wh.longitude,
        toLat: toLat,
        toLng: toLng,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ estimateShippingFeeForCart route error: $e');
      }
      route = null;
    }

    // Nếu không tính được route -> dùng phí "ngoại thành gần" làm mặc định
    if (route == null) {
      final fallback = cfg.feeNearOuter;
      cart.setShippingFee(fallback);
      notifyListeners();
      return fallback;
    }

    final distanceKm = route.distanceKm;

    // (Tùy chọn) Free ship nếu đơn >= ngưỡng
    final subtotal = cart.subtotal;
    if (cfg.freeShipThreshold > 0 && subtotal >= cfg.freeShipThreshold) {
      cart.setShippingFee(0);
      notifyListeners();
      if (kDebugMode) {
        debugPrint(
          '🚚 Free ship: subtotal=$subtotal >= ${cfg.freeShipThreshold}',
        );
      }
      return 0;
    }

    // ===== BẢNG GIÁ THEO KHOẢNG CÁCH (từ config) =====
    final d = distanceKm;

    double fee;
    if (d <= cfg.innerMaxKm) {
      fee = cfg.feeInner;
    } else if (d <= cfg.nearOuterMaxKm) {
      fee = cfg.feeNearOuter;
    } else if (d <= cfg.farOuterMaxKm) {
      fee = cfg.feeFarOuter;
    } else if (d <= cfg.interNearMaxKm) {
      fee = cfg.feeInterNear;
    } else {
      fee = cfg.feeInterFar;
    }

    // Gán vào Cart và sync cloud
    cart.setShippingFee(fee);
    notifyListeners();

    if (kDebugMode) {
      debugPrint(
        '🚚 distanceKm=$distanceKm -> fee=$fee, subtotal=$subtotal',
      );
    }

    return fee;
  }

  // ===================== HÀM ƯỚC TÍNH THỜI GIAN GIAO HÀNG (ETA) =====================

  /// Ước tính thời gian giao hàng (phút) “mềm” hơn OSRM để hiển thị cho user.
  double _estimateEtaMinutes({
    required double distanceKm,
    required double rawDurationMin,
    int stopsCount = 0, // số điểm dừng: kho chính, hub, khách...
  }) {
    // 1) Thời gian lý thuyết theo khoảng cách & tốc độ trung bình
    double avgSpeedKmH;
    if (distanceKm <= 5) {
      avgSpeedKmH = 18; // nội thành rất gần
    } else if (distanceKm <= 30) {
      avgSpeedKmH = 28; // nội/ngoại thành gần
    } else if (distanceKm <= 120) {
      avgSpeedKmH = 45; // đi tỉnh gần
    } else if (distanceKm <= 350) {
      avgSpeedKmH = 55; // liên tỉnh trung bình
    } else {
      avgSpeedKmH = 60; // đường dài
    }

    final modelMin = distanceKm / avgSpeedKmH * 60.0;

    // 2) Base từ OSRM nhưng kẹp lại trong khoảng hợp lý
    double base = rawDurationMin <= 0 ? modelMin : rawDurationMin;

    if (base < modelMin * 0.8) {
      // OSRM quá nhanh
      base = modelMin * 0.9;
    }
    if (base > modelMin * 1.7) {
      // OSRM quá chậm
      base = modelMin * 1.5;
    }

    // 3) Thêm thời gian dừng (lấy hàng, hub, giao hàng)
    final baseStopMinutes = 10.0; // lấy + giao
    final hubsCount = (stopsCount - 1).clamp(0, 10);
    final stopMinutes = baseStopMinutes + hubsCount * 5.0;

    double eta = base + stopMinutes;

    // 4) Buffer kẹt xe theo khoảng cách
    double trafficRate;
    if (distanceKm <= 10) {
      trafficRate = 0.30;
    } else if (distanceKm <= 80) {
      trafficRate = 0.22;
    } else if (distanceKm <= 300) {
      trafficRate = 0.18;
    } else {
      trafficRate = 0.12;
    }

    eta += eta * trafficRate;

    // 5) Tối thiểu 15 phút cho đơn rất gần
    if (eta < 15) eta = 15;

    // 6) Làm tròn lên bậc 5 phút cho đẹp (vd: 42 -> 45)
    final rounded = (eta / 5).ceil() * 5;
    return rounded.toDouble();
  }

  // ===================== TÍNH ROUTE & LEGS (WH → HUB → CUS) =====================

  /// Tính route & lưu:
  /// - Nếu legs chỉ WH → CUS (kho gần khách) → không dùng HUB, route 2 điểm.
  /// - Nếu có HUB (WH → HUB → CUS) → dùng HUB làm waypoint thực trong OSRM,
  ///   nên polyline chắc chắn đi qua kho trung chuyển.
  Future<void> _calcAndSaveRoute({
    required String orderId,
    required String customerId,
    required double whLat,
    required double whLng,
    required String whCode,
    required String whName,
    required double toLat,
    required double toLng,
    required String? toProvince,
    required bool alsoWriteToRoot,
  }) async {
    try {
      // 1️⃣ Lộ trình mặc định theo kho vùng (WH -> HUB -> CUS)
      final rawLegs = WarehouseConfig.buildDefaultLegsForOrder(
        whLat: whLat,
        whLng: whLng,
        whCode: whCode,
        whName: whName,
        toLat: toLat,
        toLng: toLng,
        toProvince: toProvince,
      );

      if (rawLegs.isEmpty) return;

      RouteResult route;
      final legsToSave = <OrderRouteLeg>[];

      if (rawLegs.length == 1) {
        // -------- Chỉ 1 chặng WH → CUS (kho đã là hub vùng) --------
        route = await RouteService.fromTo(
          fromLat: whLat,
          fromLng: whLng,
          toLat: toLat,
          toLng: toLng,
        );

        final m = rawLegs.first;
        legsToSave.add(
          OrderRouteLeg(
            fromCode: m['fromCode']?.toString(),
            toCode: m['toCode']?.toString(),
            fromLabel: (m['fromLabel'] ?? '') as String,
            toLabel: (m['toLabel'] ?? '') as String,
            fromLat: (m['fromLat'] as num).toDouble(),
            fromLng: (m['fromLng'] as num).toDouble(),
            toLat: (m['toLat'] as num).toDouble(),
            toLng: (m['toLng'] as num).toDouble(),
            distanceKm: route.distanceKm,
            durationMin: route.durationMin,
          ),
        );
      } else {
        // -------- Có HUB: WH → HUB → CUS --------
        final hubMap = rawLegs.firstWhere(
              (e) =>
          (e['toCode'] ?? e['fromCode'])?.toString().toUpperCase() == 'HUB',
          orElse: () => rawLegs[0],
        );

        final hubLat = (hubMap['toLat'] as num).toDouble();
        final hubLng = (hubMap['toLng'] as num).toDouble();

        route = await RouteService.fromToVia(
          fromLat: whLat,
          fromLng: whLng,
          toLat: toLat,
          toLng: toLng,
          waypoints: [
            {'lat': hubLat, 'lng': hubLng},
          ],
        );

        final legResults = route.legs;

        if (legResults.length >= 2) {
          final m1 = rawLegs[0];
          final m2 = rawLegs[1];

          legsToSave.add(
            OrderRouteLeg(
              fromCode: m1['fromCode']?.toString(),
              toCode: m1['toCode']?.toString(),
              fromLabel: (m1['fromLabel'] ?? '') as String,
              toLabel: (m1['toLabel'] ?? '') as String,
              fromLat: (m1['fromLat'] as num).toDouble(),
              fromLng: (m1['fromLng'] as num).toDouble(),
              toLat: (m1['toLat'] as num).toDouble(),
              toLng: (m1['toLng'] as num).toDouble(),
              distanceKm: legResults[0].distanceKm,
              durationMin: legResults[0].durationMin,
            ),
          );

          legsToSave.add(
            OrderRouteLeg(
              fromCode: m2['fromCode']?.toString(),
              toCode: m2['toCode']?.toString(),
              fromLabel: (m2['fromLabel'] ?? '') as String,
              toLabel: (m2['toLabel'] ?? '') as String,
              fromLat: (m2['fromLat'] as num).toDouble(),
              fromLng: (m2['fromLng'] as num).toDouble(),
              toLat: (m2['toLat'] as num).toDouble(),
              toLng: (m2['toLng'] as num).toDouble(),
              distanceKm: legResults[1].distanceKm,
              durationMin: legResults[1].durationMin,
            ),
          );
        } else {
          // fallback: một chặng tổng WH → CUS
          final m = rawLegs.first;
          legsToSave.add(
            OrderRouteLeg(
              fromCode: m['fromCode']?.toString(),
              toCode: m['toCode']?.toString(),
              fromLabel: (m['fromLabel'] ?? '') as String,
              toLabel: (m['toLabel'] ?? '') as String,
              fromLat: (m['fromLat'] as num).toDouble(),
              fromLng: (m['fromLng'] as num).toDouble(),
              toLat: (m['toLat'] as num).toDouble(),
              toLng: (m['toLng'] as num).toDouble(),
              distanceKm: route.distanceKm,
              durationMin: route.durationMin,
            ),
          );
        }
      }

      // 🧮 ETA đã điều chỉnh để hiển thị cho user
      final adjustedDurationMin = _estimateEtaMinutes(
        distanceKm: route.distanceKm,
        rawDurationMin: route.durationMin,
        stopsCount: legsToSave.length,
      );

      // 3️⃣ Lưu Firestore
      final data = <String, dynamic>{
        'routePolyline': route.polyline,
        'routeDistanceKm': route.distanceKm,
        'routeDurationMin': adjustedDurationMin, // dùng ETA đã chỉnh
        'legs': legsToSave.map((e) => e.toMap()).toList(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      final db = FirebaseFirestore.instance;
      final userRef =
      db.collection('users').doc(customerId).collection('orders').doc(orderId);
      final batch = db.batch();

      batch.set(userRef, data, SetOptions(merge: true));
      if (alsoWriteToRoot) {
        final rootRef = db.collection('orders').doc(orderId);
        batch.set(rootRef, data, SetOptions(merge: true));
      }

      await batch.commit();
    } catch (e) {
      debugPrint('❌ Route calc failed: $e');
    }
  }
}
