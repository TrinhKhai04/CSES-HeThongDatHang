import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:latlong2/latlong.dart'; // dùng kiểu LatLng

import '../../models/app_order.dart';
import '../../models/order_item.dart';

// service tính tuyến đường + vị trí kho
import '../../services/route_service.dart'; // RouteService.fromTo(...)
import '../../config/warehouse_config.dart'; // WarehouseConfig.pos

/// ===============================================================
/// 🧠 ORDER REPOSITORY
/// ---------------------------------------------------------------
/// - Ghi / đọc / cập nhật / huỷ đơn hàng.
/// - Transaction an toàn khi trừ tồn kho.
/// - Sau khi tạo đơn, nếu có toạ độ → tính & cache tuyến đường.
/// - Cung cấp stream theo nhóm trạng thái để làm UI tab kiểu Shopee.
/// ===============================================================
class OrderRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ===============================================================
  // 🛒 TẠO ĐƠN HÀNG MỚI
  // ===============================================================
  Future<void> createOrder(
      AppOrder order,
      List<OrderItem> items, {
        bool alsoWriteToRoot = true,
        String? voucherCode,
        double? subtotal,
        double? shipping,
        double? discount,
      }) async {
    final userOrderRef = _db
        .collection('users')
        .doc(order.customerId)
        .collection('orders')
        .doc(order.id);

    // luôn gắn toạ độ kho mặc định nếu caller chưa set
    final wh = WarehouseConfig.pos;
    final double whLat = order.whLat ?? wh.latitude;
    final double whLng = order.whLng ?? wh.longitude;

    await _db.runTransaction((txn) async {
      // 0) Gom danh sách doc tồn kho cần trừ
      final needQty =
      <DocumentReference<Map<String, dynamic>>, int>{};

      for (final it in items) {
        final variantId =
            it.variantId ?? (it.options?['variantId'] as String?);
        final productRef = _db.collection('products').doc(it.productId);

        final stockRef = (variantId != null && variantId.isNotEmpty)
            ? productRef.collection('variants').doc(variantId)
            : productRef;

        needQty.update(stockRef, (v) => v + it.qty, ifAbsent: () => it.qty);
      }

      // 1) Kiểm tra đủ hàng
      final stockSnaps =
      <DocumentReference<Map<String, dynamic>>,
          DocumentSnapshot<Map<String, dynamic>>>{};

      for (final entry in needQty.entries) {
        final snap = await txn.get(entry.key);
        stockSnaps[entry.key] = snap;

        final current = ((snap.data()?['stock'] ?? 0) as num).toInt();
        if (current < entry.value) {
          throw StateError(
            '❌ Sản phẩm ${entry.key.id} không đủ hàng (cần ${entry.value}, còn $current)',
          );
        }
      }

      // 2) GHI ORDER + ITEMS
      Map<String, dynamic> _moneyBlock() => {
        if (subtotal != null) 'subtotal': subtotal.toDouble(),
        if (shipping != null) 'shipping': shipping.toDouble(),
        if (discount != null) 'discount': discount.toDouble(),
        if (voucherCode != null && voucherCode.trim().isNotEmpty)
          'voucher': {'code': voucherCode.trim().toUpperCase()},
      };

      final orderData = {
        ...order.toMap(),
        'whLat': whLat,
        'whLng': whLng,
        if (order.toLat != null) 'toLat': order.toLat,
        if (order.toLng != null) 'toLng': order.toLng,
        ..._moneyBlock(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // user branch
      txn.set(userOrderRef, orderData);
      final itemsCol = userOrderRef.collection('items');
      for (final it in items) {
        txn.set(itemsCol.doc(it.id), {
          ...it.toMap(),
          'total': (it.price as num).toDouble() * it.qty,
        });
      }

      // root mirror
      if (alsoWriteToRoot) {
        final rootOrderRef = _db.collection('orders').doc(order.id);
        txn.set(rootOrderRef, orderData);

        final rootItemsCol = rootOrderRef.collection('items');
        for (final it in items) {
          txn.set(rootItemsCol.doc(it.id), {
            ...it.toMap(),
            'total': (it.price as num).toDouble() * it.qty,
          });
        }
      }

      // 3) Trừ tồn
      for (final entry in needQty.entries) {
        final ref = entry.key;
        final current =
        ((stockSnaps[ref]!.data()?['stock'] ?? 0) as num).toInt();
        final newStock = current - entry.value;
        txn.update(ref, {'stock': newStock});
      }
    });

    // 4) SAU TRANSACTION: tính route nếu đủ toạ độ
    if (order.toLat != null && order.toLng != null) {
      try {
        await _attachAndCacheRoute(
          orderId: order.id,
          customerId: order.customerId,
          from: LatLng(whLat, whLng),
          to: LatLng(order.toLat!, order.toLng!),
        );
      } catch (_) {
        // không phá quy trình nếu lỗi route
      }
    }
  }

  // ===============================================================
  // 🧩 GẮN & CACHE TUYẾN ĐƯỜNG (USER + ROOT)
  // ===============================================================
  Future<void> _attachAndCacheRoute({
    required String orderId,
    required String customerId,
    required LatLng from,
    required LatLng to,
  }) async {
    final r = await RouteService.fromTo(
      fromLat: from.latitude,
      fromLng: from.longitude,
      toLat: to.latitude,
      toLng: to.longitude,
    );

    final payload = {
      'routePolyline': r.polyline,
      'routeDistanceKm': double.parse(r.distanceKm.toStringAsFixed(2)),
      'routeDurationMin': double.parse(r.durationMin.toStringAsFixed(0)),
      'whLat': from.latitude,
      'whLng': from.longitude,
      'toLat': to.latitude,
      'toLng': to.longitude,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    final userRef = _db
        .collection('users')
        .doc(customerId)
        .collection('orders')
        .doc(orderId);
    final rootRef = _db.collection('orders').doc(orderId);

    await Future.wait([
      userRef.update(payload),
      rootRef.update(payload).catchError((e) {
        if (e is! FirebaseException || e.code != 'permission-denied') {
          throw e;
        }
      }),
    ]);
  }

  // ===============================================================
  // ❌ HUỶ ĐƠN (USER)
  // ===============================================================
  Future<void> cancelByUser({
    required String orderId,
    required String customerId,
  }) async {
    final rootRef = _db.collection('orders').doc(orderId);
    final userOrderRef = _db
        .collection('users')
        .doc(customerId)
        .collection('orders')
        .doc(orderId);

    final itemsSnap = await userOrderRef.collection('items').get();
    final items = itemsSnap.docs
        .map((d) => OrderItem.fromMap({'id': d.id, ...d.data()}))
        .toList();

    await _db.runTransaction((txn) async {
      final userSnap = await txn.get(userOrderRef);
      if (!userSnap.exists) {
        throw StateError('❌ Không tìm thấy đơn hàng hoặc không có quyền.');
      }

      final curStatus = (userSnap.data()?['status'] ?? 'pending') as String;
      if (curStatus != 'pending') {
        throw StateError('⚠️ Chỉ có thể huỷ khi đơn đang "chờ xác nhận".');
      }

      // hoàn kho
      for (final it in items) {
        final variantId =
            it.variantId ?? (it.options?['variantId'] as String?);
        final productRef = _db.collection('products').doc(it.productId);
        final stockRef = (variantId != null && variantId.isNotEmpty)
            ? productRef.collection('variants').doc(variantId)
            : productRef;

        txn.update(stockRef, {'stock': FieldValue.increment(it.qty)});
      }

      // update user doc
      final payload = {
        'status': 'cancelled',
        'cancelledAt': FieldValue.serverTimestamp(),
        'cancelledBy': 'user',
        'updatedAt': FieldValue.serverTimestamp(),
      };
      txn.update(userOrderRef, payload);
    });

    // mirror root (nếu có quyền)
    try {
      await rootRef.update({
        'status': 'cancelled',
        'cancelledAt': FieldValue.serverTimestamp(),
        'cancelledBy': 'user',
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (e) {
      if (e.code != 'permission-denied') rethrow;
    }
  }

  // ===============================================================
  // 🧑‍💼 ADMIN UPDATE STATUS (có kiểm soát)
  // ===============================================================
  Future<void> adminUpdateStatusGuarded({
    required String orderId,
    required String customerId,
    required String newStatus,
  }) async {
    final rootRef = _db.collection('orders').doc(orderId);
    final userRef = _db
        .collection('users')
        .doc(customerId)
        .collection('orders')
        .doc(orderId);

    await _db.runTransaction((tx) async {
      final rootSnap = await tx.get(rootRef);
      if (!rootSnap.exists) {
        throw Exception('Không tìm thấy đơn tại /orders');
      }

      final data = rootSnap.data()!;
      final currentStatus = (data['status'] ?? 'pending') as String;

      final from = _parse(currentStatus);
      final to = _parse(newStatus);
      if (!_canTransition(from, to)) {
        throw Exception(
          '⚠️ Không thể chuyển trạng thái từ $currentStatus → $newStatus',
        );
      }

      tx.update(rootRef, {
        'status': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      tx.update(userRef, {
        'status': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  // ===============================================================
  // 📋 LIST & ITEMS
  // ===============================================================
  Future<List<AppOrder>> listOrders({required String customerId}) async {
    final qs = await _db
        .collection('users')
        .doc(customerId)
        .collection('orders')
        .orderBy('createdAt', descending: true)
        .get();

    return qs.docs
        .map((d) => AppOrder.fromMap({'id': d.id, ...d.data()}))
        .toList();
  }

  Future<List<OrderItem>> getItems(
      String orderId, {
        required String customerId,
      }) async {
    final qs = await _db
        .collection('users')
        .doc(customerId)
        .collection('orders')
        .doc(orderId)
        .collection('items')
        .get();

    return qs.docs
        .map((d) => OrderItem.fromMap({'id': d.id, ...d.data()}))
        .toList();
  }

  // ===============================================================
  // 🔄 STREAM: tất cả đơn (user)
  // ===============================================================
  Stream<List<AppOrder>> getStream({required String customerId}) {
    return _db
        .collection('users')
        .doc(customerId)
        .collection('orders')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (qs) => qs.docs
          .map(
            (d) => AppOrder.fromMap({'id': d.id, ...d.data()}),
      )
          .toList(),
    );
  }

  // ===============================================================
  // 🆕 STREAM: theo nhóm trạng thái (phục vụ tab kiểu Shopee)
  // ===============================================================
  Stream<List<AppOrder>> watchByStatuses({
    required String customerId,
    required List<String> statuses,
    int limit = 50,
  }) {
    final q = _db
        .collection('users')
        .doc(customerId)
        .collection('orders')
        .where('status', whereIn: statuses)
        .orderBy('createdAt', descending: true)
        .limit(limit);

    return q.snapshots().map(
          (s) => s.docs
          .map((d) => AppOrder.fromMap({'id': d.id, ...d.data()}))
          .toList(),
    );
  }

  /// Tất cả đơn (nếu cần “Tất cả” tab)
  Stream<List<AppOrder>> watchAll({
    required String customerId,
    int limit = 50,
  }) {
    final q = _db
        .collection('users')
        .doc(customerId)
        .collection('orders')
        .orderBy('createdAt', descending: true)
        .limit(limit);

    return q.snapshots().map(
          (s) => s.docs
          .map((d) => AppOrder.fromMap({'id': d.id, ...d.data()}))
          .toList(),
    );
  }

  /// Đếm số đơn theo nhóm trạng thái (hiển thị badge số)
  Future<int> countByStatuses({
    required String customerId,
    required List<String> statuses,
  }) async {
    int sum = 0;
    for (final st in statuses) {
      final agg = await _db
          .collection('users')
          .doc(customerId)
          .collection('orders')
          .where('status', isEqualTo: st)
          .count()
          .get();
      sum += agg.count ?? 0;
    }
    return sum;
  }

  // ===============================================================
  // 🔁 UPDATE STATUS (user)
  // ===============================================================
  Future<void> updateStatus(
      String orderId,
      String status, {
        required String customerId,
      }) async {
    await _db
        .collection('users')
        .doc(customerId)
        .collection('orders')
        .doc(orderId)
        .update({
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ===============================================================
  // 🔍 TÌM ĐƠN THEO MÃ CSES-XXXXXX
  // ===============================================================

  /// ADMIN / CSKH: tìm ở collection `orders` (không cần biết customerId)
  Future<AppOrder?> getOrderByCodeForAdmin(String code) async {
    final trimmed = code.trim();
    if (trimmed.isEmpty) return null;

    final qs = await _db
        .collection('orders')
        .where('orderCode', isEqualTo: trimmed)
        .limit(1)
        .get();

    if (qs.docs.isEmpty) return null;

    final d = qs.docs.first;
    return AppOrder.fromMap({'id': d.id, ...d.data()});
  }

  /// USER: tìm trong đơn của chính mình
  Future<AppOrder?> getMyOrderByCode({
    required String customerId,
    required String orderCode,
  }) async {
    final trimmed = orderCode.trim();
    if (trimmed.isEmpty) return null;

    final qs = await _db
        .collection('users')
        .doc(customerId)
        .collection('orders')
        .where('orderCode', isEqualTo: trimmed)
        .limit(1)
        .get();

    if (qs.docs.isEmpty) return null;

    final d = qs.docs.first;
    return AppOrder.fromMap({'id': d.id, ...d.data()});
  }

  // ===============================================================
  // 🧩 Helper parse & transition
  // ===============================================================
  _OrderStatus _parse(String s) {
    switch (s) {
      case 'pending':
        return _OrderStatus.pending;
      case 'processing':
        return _OrderStatus.processing;
      case 'shipping':
        return _OrderStatus.shipping;
      case 'delivered':
      case 'done':
      case 'completed':
        return _OrderStatus.done;
      case 'cancelled':
        return _OrderStatus.cancelled;
      default:
        return _OrderStatus.pending;
    }
  }

  bool _canTransition(_OrderStatus from, _OrderStatus to) {
    switch (from) {
      case _OrderStatus.pending:
        return to == _OrderStatus.processing ||
            to == _OrderStatus.cancelled;
      case _OrderStatus.processing:
        return to == _OrderStatus.shipping ||
            to == _OrderStatus.cancelled;
      case _OrderStatus.shipping:
        return to == _OrderStatus.done; // hoàn tất
      case _OrderStatus.done:
      case _OrderStatus.cancelled:
        return false;
    }
  }
}

// Enum trạng thái nội bộ
enum _OrderStatus { pending, processing, shipping, done, cancelled }
