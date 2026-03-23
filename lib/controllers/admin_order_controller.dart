import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// ===========================================================================
/// 🧑‍💼 ADMIN ORDER CONTROLLER
/// ---------------------------------------------------------------------------
/// Controller dành riêng cho quản trị viên:
///   ✅ Theo dõi tất cả đơn hàng (realtime)
///   ✅ Xem chi tiết đơn hàng + danh sách sản phẩm
///   ✅ Cập nhật trạng thái đơn hàng
///   ✅ Huỷ hoặc hoàn tất đơn hàng
///
/// ⚙️ Hoạt động trên cả hai nhánh Firestore:
///   - /orders/{orderId}
///   - /users/{uid}/orders/{orderId}
///
/// 💡 Lý do tách riêng:
///   - Phân quyền rõ ràng giữa user và admin.
///   - Dễ mở rộng logic thống kê, lọc đơn, phân tích sau này.
/// ===========================================================================
class AdminOrderController extends ChangeNotifier {
  final FirebaseFirestore _fs = FirebaseFirestore.instance;

  // ==========================================================================
  // 🔥 STREAM — Theo dõi realtime toàn bộ đơn hàng
  // ==========================================================================
  Stream<QuerySnapshot<Map<String, dynamic>>> watchAllOrders() {
    return _fs
        .collection('orders')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  // ==========================================================================
  // 📄 Lấy chi tiết một đơn hàng (theo orderId)
  // ==========================================================================
  Future<DocumentSnapshot<Map<String, dynamic>>> getOrder(String orderId) {
    return _fs.collection('orders').doc(orderId).get();
  }

  // ==========================================================================
  // 🧾 Lấy danh sách sản phẩm trong đơn hàng
  // ==========================================================================
  Future<List<Map<String, dynamic>>> getItems(String orderId) async {
    final qs =
    await _fs.collection('orders').doc(orderId).collection('items').get();
    return qs.docs.map((d) => d.data()).toList();
  }

  // ==========================================================================
  // 🔄 CẬP NHẬT TRẠNG THÁI ĐƠN HÀNG (ADMIN)
  // ==========================================================================
  Future<bool> updateStatus({
    required String orderId,
    required String newStatus,
  }) async {
    try {
      // 🔍 Lấy document chính
      final doc = await _fs.collection('orders').doc(orderId).get();
      if (!doc.exists) throw Exception('❌ Đơn hàng không tồn tại.');

      final data = doc.data();
      final customerId = data?['customerId']?.toString();
      if (customerId == null || customerId.isEmpty) {
        throw Exception('❌ Không tìm thấy customerId trong đơn hàng.');
      }

      // 🧾 Cập nhật đồng thời 2 nhánh (admin + user)
      final batch = _fs.batch();
      final now = FieldValue.serverTimestamp();

      // Nhánh admin: /orders/{orderId}
      final rootRef = _fs.collection('orders').doc(orderId);
      batch.update(rootRef, {
        'status': newStatus,
        'updatedAt': now,
      });

      // Nhánh user: /users/{uid}/orders/{orderId}
      final userRef = _fs
          .collection('users')
          .doc(customerId)
          .collection('orders')
          .doc(orderId);
      batch.set(
        userRef,
        {
          'status': newStatus,
          'updatedAt': now,
        },
        SetOptions(merge: true),
      );

      await batch.commit();
      notifyListeners();

      debugPrint('✅ Admin cập nhật trạng thái đơn #$orderId → $newStatus');
      return true;
    } catch (e) {
      debugPrint('❌ Lỗi updateStatus (admin): $e');
      return false;
    }
  }

  // ==========================================================================
  // ❌ HUỶ ĐƠN HÀNG (ADMIN)
  // ==========================================================================
  Future<bool> cancelOrder(String orderId) async {
    return updateStatus(orderId: orderId, newStatus: 'cancelled');
  }

  // ==========================================================================
  // ✅ HOÀN TẤT ĐƠN HÀNG (ADMIN)
  // ==========================================================================
  Future<bool> completeOrder(String orderId) async {
    return updateStatus(orderId: orderId, newStatus: 'done');
  }
}
