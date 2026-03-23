import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// ViewModel gọn cho admin
class UserAccount {
  final String id;
  final String name;
  final String phone;
  final String? email;
  final String role; // "user" | "admin"
  final bool isBlocked; // true | false
  final int? createdAt;
  final int? blockUntil; // 👈 thêm để lưu thời hạn khóa tạm thời

  UserAccount({
    required this.id,
    required this.name,
    required this.phone,
    this.email,
    required this.role,
    required this.isBlocked,
    this.createdAt,
    this.blockUntil,
  });

  factory UserAccount.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return UserAccount(
      id: data['id'] ?? doc.id,
      name: data['name'] ?? '',
      phone: data['phone'] ?? '',
      email: data['email'],
      role: (data['role'] ?? 'user').toString(),
      isBlocked: (data['isBlocked'] ?? false) == true,
      createdAt: (data['createdAt'] is int) ? data['createdAt'] as int : null,
      blockUntil:
      (data['blockUntil'] is int) ? data['blockUntil'] as int : null,
    );
  }
}

class UserController extends ChangeNotifier {
  final _db = FirebaseFirestore.instance;
  final _col = 'users';

  List<UserAccount> _all = [];
  String _keyword = '';
  bool _loading = false;

  List<UserAccount> get users {
    if (_keyword.trim().isEmpty) return _all;
    final k = _keyword.toLowerCase();
    return _all
        .where((u) =>
    u.name.toLowerCase().contains(k) ||
        u.phone.toLowerCase().contains(k) ||
        (u.email ?? '').toLowerCase().contains(k))
        .toList();
  }

  bool get isLoading => _loading;
  String get keyword => _keyword;

  /// Lắng nghe realtime
  Stream<List<UserAccount>> streamUsers() {
    return _db
        .collection(_col)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => UserAccount.fromDoc(d)).toList());
  }

  /// Gọi trong initState của màn danh sách
  void attachStream() {
    // 🔄 Chỉ khởi tạo stream 1 lần duy nhất, tránh bị reset sau khi update
    if (_all.isNotEmpty) return;
    _loading = true;
    notifyListeners();
    streamUsers().listen((list) {
      _all = list;
      _loading = false;
      notifyListeners();
    });
  }

  void setKeyword(String v) {
    _keyword = v;
    notifyListeners();
  }

  Future<void> toggleBlock(String uid, {required bool block}) async {
    await _db.collection(_col).doc(uid).set(
      {'isBlocked': block, 'blockUntil': null},
      SetOptions(merge: true),
    );
  }

  Future<void> deleteUser(String uid) async {
    // Xóa profile Firestore (Auth xóa bằng Admin SDK)
    await _db.collection(_col).doc(uid).delete();
  }

  /// ✅ Khóa tạm thời user đến thời điểm [timestamp]
  Future<void> blockUntil(String id, int timestamp) async {
    await _db.collection(_col).doc(id).set({
      'blockUntil': timestamp,
      'isBlocked': false,
    }, SetOptions(merge: true));

    // ⚙️ Cập nhật danh sách tạm thời để UI phản hồi ngay
    _all = _all.map((u) {
      if (u.id == id) {
        return UserAccount(
          id: u.id,
          name: u.name,
          phone: u.phone,
          email: u.email,
          role: u.role,
          isBlocked: false,
          createdAt: u.createdAt,
          blockUntil: timestamp,
        );
      }
      return u;
    }).toList();

    notifyListeners();
  }

  /// 🔍 Lấy 1 user theo ID
  Future<UserAccount?> getById(String uid) async {
    final doc = await _db.collection(_col).doc(uid).get();
    if (!doc.exists) return null;
    return UserAccount.fromDoc(doc as DocumentSnapshot<Map<String, dynamic>>);
  }

  /// ✅ Cập nhật thông tin user (dành cho admin)
  /// ✅ Cập nhật thông tin user (dành cho admin)
  Future<void> updateUser(String uid, Map<String, dynamic> data) async {
    await _db.collection(_col).doc(uid).update(data);

    // 🔧 Cập nhật luôn danh sách local, để UI phản hồi tức thời
    _all = _all.map((u) {
      if (u.id == uid) {
        return UserAccount(
          id: u.id,
          name: data['name'] ?? u.name,
          phone: data['phone'] ?? u.phone,
          email: data['email'] ?? u.email,
          role: data['role'] ?? u.role,
          isBlocked: data['isBlocked'] ?? u.isBlocked,
          createdAt: u.createdAt,
          blockUntil: data['blockUntil'] ?? u.blockUntil,
        );
      }
      return u;
    }).toList();

    notifyListeners();
  }
}
