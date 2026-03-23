import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Controller quản lý thông báo người dùng (Firestore)
class NotificationController extends ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Danh sách thông báo (mỗi item luôn có trường 'id')
  List<Map<String, dynamic>> notifications = [];

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _sub;

  /// Lắng nghe realtime các thông báo của user hiện tại
  void listenToUserNotifications() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    // Hủy stream cũ (nếu có) rồi đăng ký lại để tránh duplicate listener
    _sub?.cancel();
    _sub = _db
        .collection('notifications')
        .where('userId', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .listen((snapshot) {
      notifications = snapshot.docs.map((doc) {
        final data = doc.data();
        // Đảm bảo luôn có 'id' để UI gọi markAsRead/delete theo id
        return {
          'id': doc.id,
          ...data,
        };
      }).toList();
      notifyListeners();
    });
  }

  /// Kéo-để-tải-lại (phục vụ RefreshIndicator)
  Future<void> refresh() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    final snap = await _db
        .collection('notifications')
        .where('userId', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .get();

    notifications = snap.docs.map((doc) {
      final data = doc.data();
      return {
        'id': doc.id,
        ...data,
      };
    }).toList();
    notifyListeners();
  }

  /// Số lượng thông báo chưa đọc
  int get unreadCount =>
      notifications.where((n) => n['isRead'] == false).length;

  /// Đánh dấu 1 thông báo đã đọc
  Future<void> markAsRead(String id) async {
    if (id.isEmpty) return;
    await _db.collection('notifications').doc(id).update({'isRead': true});

    // Cập nhật local ngay để UI mượt
    final idx = notifications.indexWhere((e) => e['id'] == id);
    if (idx != -1) {
      notifications[idx] = {
        ...notifications[idx],
        'isRead': true,
      };
      notifyListeners();
    }
  }

  /// Xóa 1 thông báo
  Future<void> delete(String id) async {
    if (id.isEmpty) return;
    await _db.collection('notifications').doc(id).delete();

    notifications.removeWhere((e) => e['id'] == id);
    notifyListeners();
  }

  /// Đánh dấu tất cả là đã đọc (dùng batch để nhanh và ít round-trip)
  Future<void> markAllAsRead() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    final query = await _db
        .collection('notifications')
        .where('userId', isEqualTo: uid)
        .where('isRead', isEqualTo: false)
        .get();

    if (query.docs.isEmpty) return;

    final batch = _db.batch();
    for (final d in query.docs) {
      batch.update(d.reference, {'isRead': true});
    }
    await batch.commit();

    // Cập nhật local
    notifications =
        notifications.map((n) => {...n, 'isRead': true}).toList();
    notifyListeners();
  }

  /// Xóa tất cả thông báo của user (tuỳ chọn)
  Future<void> clearAll() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    final snap = await _db
        .collection('notifications')
        .where('userId', isEqualTo: uid)
        .get();

    if (snap.docs.isEmpty) {
      notifications.clear();
      notifyListeners();
      return;
    }

    final batch = _db.batch();
    for (final doc in snap.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();

    notifications.clear();
    notifyListeners();
  }

  /// =========================================================================
  /// 🆕 Helper: Tạo thông báo cho đơn hàng (có orderId)
  /// Gọi hàm này khi:
  ///  - Trạng thái đơn thay đổi (pending → shipping, delivered…)
  ///  - Có cập nhật quan trọng liên quan đến 1 order
  /// UI sẽ dùng field 'orderId' này để bấm vào thông báo → mở chi tiết đơn.
  /// =========================================================================
  Future<void> createOrderNotification({
    required String userId,
    required String orderId,
    required String title,
    required String message,
    String type = 'order', // bạn có thể dùng để filter sau này
    bool isRead = false,
  }) async {
    await _db.collection('notifications').add({
      'userId': userId,
      'orderId': orderId,
      'title': title,
      'message': message,
      'type': type,
      'isRead': isRead,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// (Tuỳ chọn) Helper chung nếu muốn tạo thông báo bất kỳ (có/không có orderId)
  Future<void> createNotification({
    String? userId,
    String? orderId,
    required String title,
    required String message,
    String type = 'generic',
    bool isRead = false,
  }) async {
    final uid = userId ?? _auth.currentUser?.uid;
    if (uid == null) return;

    await _db.collection('notifications').add({
      'userId': uid,
      if (orderId != null) 'orderId': orderId,
      'title': title,
      'message': message,
      'type': type,
      'isRead': isRead,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
