// lib/controllers/wishlist_controller.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Wishlist theo user: users/{uid}/wishlist/{productId? or autoId}
class WishlistController extends ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  final Set<String> _ids = <String>{}; // chứa productId chuẩn
  Set<String> get ids => _ids;
  bool isFav(String productId) => _ids.contains(productId);

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _sub;
  StreamSubscription<User?>? _authSub;

  WishlistController() {
    // Tự động bind/clear khi trạng thái đăng nhập thay đổi
    _authSub = _auth.authStateChanges().listen((user) {
      _rebindForUid(user?.uid); // user == null => clear
    });
  }

  /// Thêm / gỡ yêu thích (hỗ trợ cả dữ liệu legacy)
  Future<void> toggle(String productId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw StateError('Chưa đăng nhập');

    final col = _db.collection('users').doc(uid).collection('wishlist');
    final directRef = col.doc(productId);

    final fav = _ids.contains(productId);

    if (fav) {
      // Optimistic update
      _ids.remove(productId);
      notifyListeners();

      // Xóa doc theo 2 trường hợp: docId = productId hoặc autoId có field productId
      final directSnap = await directRef.get();
      if (directSnap.exists) {
        await directRef.delete();
        return;
      }
      final legacy = await col.where('productId', isEqualTo: productId).limit(1).get();
      if (legacy.docs.isNotEmpty) {
        await legacy.docs.first.reference.delete();
      }
    } else {
      // Optimistic update
      _ids.add(productId);
      notifyListeners();

      // Tránh trùng: nếu đã có doc legacy thì chỉ cập nhật merge
      final legacy = await col.where('productId', isEqualTo: productId).limit(1).get();
      if (legacy.docs.isNotEmpty) {
        await legacy.docs.first.reference.set({
          'productId': productId,
          'createdAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } else {
        await directRef.set({
          'productId': productId, // lưu cả field để đồng bộ
          'createdAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    }
  }

  /// Hủy listener hiện tại + xóa cache; nếu có uid thì lắng nghe uid mới
  Future<void> _rebindForUid(String? uid) async {
    await _sub?.cancel();
    _sub = null;

    _ids.clear();
    notifyListeners(); // clear UI ngay khi chuyển account

    if (uid == null) return;

    // KHÔNG orderBy để không bỏ sót doc cũ chưa có createdAt
    _sub = _db
        .collection('users')
        .doc(uid)
        .collection('wishlist')
        .snapshots()
        .listen((qs) {
      final next = <String>{};
      for (final d in qs.docs) {
        final data = d.data();
        // Ưu tiên field productId (legacy), fallback doc.id
        final pid = (data['productId'] as String?)?.trim();
        next.add((pid != null && pid.isNotEmpty) ? pid : d.id);
      }
      _ids
        ..clear()
        ..addAll(next);
      notifyListeners();
    });
  }

  /// Cho phép gọi thủ công khi cần (vd. lúc logout)
  Future<void> detach() => _rebindForUid(null);

  @override
  void dispose() {
    _sub?.cancel();
    _authSub?.cancel();
    super.dispose();
  }
}
