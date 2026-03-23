import 'package:cloud_firestore/cloud_firestore.dart';

/// Lớp này thay thế hoàn toàn cho AppDatabase (SQLite cũ)
/// Quản lý kết nối Firebase Firestore và cung cấp các thao tác CRUD cơ bản.
class FirestoreService {
  static final FirestoreService _instance = FirestoreService._internal();
  factory FirestoreService() => _instance;
  FirestoreService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Thêm document mới vào collection
  Future<void> addData(String collection, Map<String, dynamic> data) async {
    await _db.collection(collection).add(data);
  }

  /// Cập nhật document theo id
  Future<void> updateData(
      String collection, String id, Map<String, dynamic> data) async {
    await _db.collection(collection).doc(id).update(data);
  }

  /// Xoá document
  Future<void> deleteData(String collection, String id) async {
    await _db.collection(collection).doc(id).delete();
  }

  /// Lấy tất cả documents trong collection
  Future<List<Map<String, dynamic>>> getAll(String collection) async {
    final snapshot = await _db.collection(collection).get();
    return snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
  }

  /// Lấy document theo id
  Future<Map<String, dynamic>?> getById(String collection, String id) async {
    final doc = await _db.collection(collection).doc(id).get();
    return doc.exists ? {'id': doc.id, ...doc.data()!} : null;
  }

  /// Lắng nghe realtime thay đổi trong collection
  Stream<List<Map<String, dynamic>>> listen(String collection) {
    return _db.collection(collection).snapshots().map((snapshot) =>
        snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList());
  }
}
