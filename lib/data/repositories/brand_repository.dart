import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/brand.dart';

/// Repository quản lý collection `brands` trong Firestore.
/// Hỗ trợ CRUD + Stream realtime (nghe thay đổi tự động).
class BrandRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final String _collection = 'brands';

  /// 🔹 Lấy toàn bộ danh sách brand (một lần)
  Future<List<Brand>> getAll() async {
    final snapshot =
    await _db.collection(_collection).orderBy('name').get();
    return snapshot.docs.map((doc) => Brand.fromMap({
      'id': doc.id,
      ...doc.data(),
    })).toList();
  }

  /// 🔹 Thêm mới hoặc cập nhật (upsert)
  Future<void> upsert({String? id, required String name}) async {
    // Tạo id nếu chưa có
    id ??= name
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .substring(0, name.length.clamp(1, 24));

    final docRef = _db.collection(_collection).doc(id);
    final brand = Brand(id: id, name: name);

    await docRef.set(
      brand.toMap(),
      SetOptions(merge: true), // tương đương ConflictAlgorithm.replace
    );
  }

  /// 🔹 Xoá brand theo id
  Future<void> delete(String id) async {
    await _db.collection(_collection).doc(id).delete();
  }

  /// 🔹 Stream realtime (nghe thay đổi tự động)
  Stream<List<Brand>> getStream() {
    return _db
        .collection(_collection)
        .orderBy('name')
        .snapshots()
        .map((snapshot) =>
        snapshot.docs.map((doc) => Brand.fromMap({'id': doc.id, ...doc.data()})).toList());
  }
}
