import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/category.dart';

/// Repository quản lý collection `categories` trong Firestore.
/// Tương đương bản SQLite cũ nhưng dùng Firebase Cloud Firestore.
/// Có hỗ trợ CRUD + Stream realtime.
class CategoryRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final String _collection = 'categories';

  /// 🔹 Lấy toàn bộ danh mục (chạy 1 lần)
  Future<List<Category>> getAll() async {
    final snapshot =
    await _db.collection(_collection).orderBy('name').get();
    return snapshot.docs.map((doc) => Category.fromMap({
      'id': doc.id,
      ...doc.data(),
    })).toList();
  }

  /// 🔹 Thêm mới hoặc cập nhật (upsert)
  Future<void> upsert({String? id, required String name}) async {
    // Tạo id tự động nếu chưa có (slugify từ name)
    id ??= name
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .substring(0, name.length.clamp(1, 24));

    final docRef = _db.collection(_collection).doc(id);
    final category = Category(id: id, name: name);

    await docRef.set(
      category.toMap(),
      SetOptions(merge: true), // tương đương ConflictAlgorithm.replace
    );
  }

  /// 🔹 Xóa category theo id
  Future<void> delete(String id) async {
    await _db.collection(_collection).doc(id).delete();
  }

  /// 🔹 Stream realtime (tự động cập nhật khi có thay đổi)
  Stream<List<Category>> getStream() {
    return _db
        .collection(_collection)
        .orderBy('name')
        .snapshots()
        .map((snapshot) => snapshot.docs
        .map((doc) => Category.fromMap({'id': doc.id, ...doc.data()}))
        .toList());
  }
}
