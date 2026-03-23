import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/customer.dart';

/// Repository quản lý collection `customers` trong Firestore.
/// Thay thế hoàn toàn SQLite cũ, hỗ trợ CRUD + Stream realtime.
class CustomerRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final String _collection = 'customers';

  /// 🔹 Thêm mới hoặc cập nhật (upsert)
  Future<void> upsert(Customer c) async {
    final docRef = _db.collection(_collection).doc(c.id);
    await docRef.set(
      c.toMap(),
      SetOptions(merge: true), // tương đương ConflictAlgorithm.replace
    );
  }

  /// 🔹 Tìm khách hàng theo số điện thoại
  Future<Customer?> findByPhone(String phone) async {
    final snapshot = await _db
        .collection(_collection)
        .where('phone', isEqualTo: phone)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) return null;
    final data = snapshot.docs.first.data();
    return Customer.fromMap({'id': snapshot.docs.first.id, ...data});
  }

  /// 🔹 Lấy toàn bộ khách hàng
  Future<List<Customer>> getAll() async {
    final snapshot =
    await _db.collection(_collection).orderBy('createdAt', descending: true).get();
    return snapshot.docs.map((doc) => Customer.fromMap({'id': doc.id, ...doc.data()})).toList();
  }

  /// 🔹 Stream realtime (lắng nghe khách hàng mới)
  Stream<List<Customer>> getStream() {
    return _db
        .collection(_collection)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
        .map((doc) => Customer.fromMap({'id': doc.id, ...doc.data()}))
        .toList());
  }

  /// 🔹 Xoá khách hàng
  Future<void> delete(String id) async {
    await _db.collection(_collection).doc(id).delete();
  }
}
