import 'package:cloud_firestore/cloud_firestore.dart';

/// Repository quản lý biến thể sản phẩm (product_variants)
/// Trên Firestore, mỗi product sẽ có subcollection `variants`.
class VariantRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// 🔹 Lấy danh sách variant theo productId
  Future<List<Map<String, dynamic>>> getByProductId(String productId) async {
    final snapshot = await _db
        .collection('products')
        .doc(productId)
        .collection('variants')
        .orderBy('size')
        .get();

    return snapshot.docs
        .map((doc) => {'id': doc.id, ...doc.data() as Map<String, dynamic>})
        .toList();
  }

  /// 🔹 Thêm hoặc cập nhật biến thể
  Future<void> upsert({
    String? id,
    required String productId,
    String? size,
    String? color,
    required double price,
    required int stock,
    String? imageUrl,
  }) async {
    final variantData = {
      'productId': productId,
      'size': size,
      'color': color,
      'price': price,
      'stock': stock,
      'imageUrl': imageUrl,
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
    };

    final productRef = _db.collection('products').doc(productId);
    final variantRef = productRef.collection('variants');

    if (id == null || id.isEmpty) {
      // Tạo id tự động nếu chưa có
      final newId = 'v_${productId}_${DateTime.now().millisecondsSinceEpoch}';
      await variantRef.doc(newId).set({
        'id': newId,
        ...variantData,
        'createdAt': DateTime.now().millisecondsSinceEpoch,
      });
    } else {
      await variantRef.doc(id).set(variantData, SetOptions(merge: true));
    }
  }

  /// 🔹 Xóa biến thể theo id
  Future<void> delete(String productId, String id) async {
    final variantRef =
    _db.collection('products').doc(productId).collection('variants').doc(id);
    await variantRef.delete();
  }

  /// 🔹 Stream realtime các biến thể của một sản phẩm
  Stream<List<Map<String, dynamic>>> getStream(String productId) {
    return _db
        .collection('products')
        .doc(productId)
        .collection('variants')
        .orderBy('size')
        .snapshots()
        .map((snapshot) => snapshot.docs
        .map((doc) => {'id': doc.id, ...doc.data() as Map<String, dynamic>})
        .toList());
  }
}
