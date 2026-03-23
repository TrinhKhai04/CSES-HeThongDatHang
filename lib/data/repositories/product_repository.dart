import 'package:cloud_firestore/cloud_firestore.dart';

/// Repository quản lý `products` trên Firestore.
/// Hỗ trợ CRUD, search, variants và stream realtime.
class ProductRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final String _collection = 'products';

  /// 🔹 Tìm kiếm sản phẩm theo tên, sku, brand, hoặc category
  Future<List<Map<String, dynamic>>> search({
    String query = '',
    String? brandId,
    String? categoryId,
  }) async {
    CollectionReference products = _db.collection(_collection);
    Query q = products;

    if (brandId != null && brandId.isNotEmpty) {
      q = q.where('brandId', isEqualTo: brandId);
    }
    if (categoryId != null && categoryId.isNotEmpty) {
      q = q.where('categoryId', isEqualTo: categoryId);
    }

    // ⬇️ Ưu tiên sản phẩm bán chạy
    final snapshot = await q
        .orderBy('soldCount', descending: true)
        .orderBy('createdAt', descending: true)
        .get();

    final results = snapshot.docs
        .map((doc) => {'id': doc.id, ...doc.data() as Map<String, dynamic>})
        .where((p) {
      // ✅ CHỈ LẤY SẢN PHẨM ĐANG BÁN nhưng LỌC TRONG BỘ NHỚ
      final status = (p['status'] ?? 'active').toString();
      if (status != 'active') return false;

      if (query.isEmpty) return true;
      final name = (p['name'] ?? '').toString().toLowerCase();
      final sku = (p['sku'] ?? '').toString().toLowerCase();
      return name.contains(query.toLowerCase()) ||
          sku.contains(query.toLowerCase());
    })
        .toList();

    return results;
  }

  /// 🔹 Lấy sản phẩm theo id
  Future<Map<String, dynamic>?> getById(String id) async {
    final doc = await _db.collection(_collection).doc(id).get();
    return doc.exists ? {'id': doc.id, ...doc.data()!} : null;
  }

  /// 🔹 Thêm hoặc cập nhật sản phẩm
  Future<String> upsert({
    String? id,
    required String name,
    required double price,
    String? sku,
    String? brandId,
    String? categoryId,
    String? description,
    String? imageUrl,
    String status = 'active',
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final data = {
      'name': name,
      'price': price,
      'sku': sku,
      'brandId': brandId,
      'categoryId': categoryId,
      'description': description,
      'imageUrl': imageUrl,
      'status': status,
      'updatedAt': now,
      'createdAt': now,
    };

    if (id == null || id.isEmpty) {
      id = 'p_${now}_${(name.hashCode & 0x7fffffff)}';
      data['id'] = id;
    }

    final docRef = _db.collection(_collection).doc(id);
    await docRef.set(data, SetOptions(merge: true));
    return id!;
  }

  /// 🔹 Xóa sản phẩm (và các variants liên quan)
  Future<void> delete(String id) async {
    final productRef = _db.collection(_collection).doc(id);

    // Xóa subcollection "variants" (nếu có)
    final variantsSnapshot = await productRef.collection('variants').get();
    for (var v in variantsSnapshot.docs) {
      await v.reference.delete();
    }

    await productRef.delete();
  }

  /// 🔹 Lấy toàn bộ sản phẩm (tùy filter)
  Future<List<Map<String, dynamic>>> getAll({
    String? keyword,
    String? category,
  }) async {
    Query q = _db.collection(_collection);

    if (category != null && category.trim().isNotEmpty) {
      q = q.where('categoryId', isEqualTo: category);
    }

    // ⬇️ Bán chạy trước, rồi đến mới tạo
    final snapshot = await q
        .orderBy('soldCount', descending: true)
        .orderBy('createdAt', descending: true)
        .get();

    return snapshot.docs
        .map((doc) => {'id': doc.id, ...doc.data() as Map<String, dynamic>})
        .where((p) {
      // ✅ CHỈ LẤY SẢN PHẨM ĐANG BÁN nhưng lọc ở client
      final status = (p['status'] ?? 'active').toString();
      if (status != 'active') return false;

      if (keyword == null || keyword.isEmpty) return true;
      final name = (p['name'] ?? '').toString().toLowerCase();
      final sku = (p['sku'] ?? '').toString().toLowerCase();
      return name.contains(keyword.toLowerCase()) ||
          sku.contains(keyword.toLowerCase());
    })
        .toList();
  }

  /// 🔹 Stream realtime danh sách sản phẩm
  Stream<List<Map<String, dynamic>>> getStream() {
    return _db
        .collection(_collection)
    // ⬇️ Sắp xếp mặc định: bán chạy → mới tạo
        .orderBy('soldCount', descending: true)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
          .map(
            (doc) => {'id': doc.id, ...doc.data() as Map<String, dynamic>},
      )
          .where((p) {
        // ✅ Chỉ stream sản phẩm đang bán – lọc trong bộ nhớ
        final status = (p['status'] ?? 'active').toString();
        return status == 'active';
      })
          .toList(),
    );
  }

  // ----------------------------------------------------------
  // ✅ 🔹 Lấy danh sách biến thể (variants) của 1 sản phẩm
  // ----------------------------------------------------------
  Future<List<Map<String, dynamic>>> getVariants(String productId) async {
    try {
      final snap = await _db
          .collection(_collection)
          .doc(productId)
          .collection('variants')
          .get();

      return snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
    } catch (e) {
      print('❌ [ProductRepository] getVariants error: $e');
      return [];
    }
  }
}
