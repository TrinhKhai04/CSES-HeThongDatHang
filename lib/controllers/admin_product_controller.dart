import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// ============================================================================
/// 🧭 AdminProductController
/// ----------------------------------------------------------------------------
/// Cách A – Lọc & tìm kiếm ngay trong bộ nhớ (không query lại Firestore)
///  - Dữ liệu tải 1 lần, lọc cực nhanh, mượt.
///  - Phù hợp cho ứng dụng admin có < vài nghìn sản phẩm.
/// ============================================================================
class AdminProductController extends ChangeNotifier {
  final _db = FirebaseFirestore.instance;

  bool loading = false;

  /// Dữ liệu gốc (đã load từ Firestore)
  List<Map<String, dynamic>> _allProducts = [];

  /// Dữ liệu hiển thị (sau khi lọc)
  List<Map<String, dynamic>> products = [];

  List<Map<String, dynamic>> brands = [];
  List<Map<String, dynamic>> categories = [];

  String? filterBrandId;
  String? filterCategoryId;
  String search = '';

  // ---------------------------------------------------------------------------
  // 🚀 Khởi tạo dữ liệu ban đầu
  // ---------------------------------------------------------------------------
  Future<void> init() async {
    loading = true;
    notifyListeners();

    try {
      await Future.wait([
        _loadBrands(),
        _loadCategories(),
        _loadProducts(),
      ]);
      _applyFilters(); // lọc & hiển thị ban đầu
    } catch (e, st) {
      if (kDebugMode) print('❌ [AdminProductController.init] $e\n$st');
    }

    loading = false;
    notifyListeners();
  }

  Future<void> _loadBrands() async {
    final snap = await _db.collection('brands').orderBy('name').get();
    brands = snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
  }

  Future<void> _loadCategories() async {
    final snap = await _db.collection('categories').orderBy('name').get();
    categories = snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
  }

  Future<void> _loadProducts() async {
    final snap =
    await _db.collection('products').orderBy('updatedAt', descending: true).get();
    _allProducts = snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
  }

  // ---------------------------------------------------------------------------
  // 🔍 Tìm kiếm & Lọc (OFFLINE)
  // ---------------------------------------------------------------------------
  void setSearch(String v) {
    search = v.trim().toLowerCase();
    _applyFilters();
  }

  void setBrandFilter(String? id) {
    filterBrandId = id;
    _applyFilters();
  }

  void setCategoryFilter(String? id) {
    filterCategoryId = id;
    _applyFilters();
  }

  /// Áp dụng bộ lọc và tìm kiếm cục bộ
  void _applyFilters() {
    List<Map<String, dynamic>> result = List.from(_allProducts);

    // 1️⃣ Lọc theo thương hiệu
    if (filterBrandId != null && filterBrandId!.isNotEmpty) {
      result = result.where((p) => p['brandId'] == filterBrandId).toList();
    }

    // 2️⃣ Lọc theo danh mục
    if (filterCategoryId != null && filterCategoryId!.isNotEmpty) {
      result = result.where((p) => p['categoryId'] == filterCategoryId).toList();
    }

    // 3️⃣ Tìm kiếm theo tên hoặc SKU (không phân biệt hoa thường)
    if (search.isNotEmpty) {
      result = result.where((p) {
        final name = (p['name'] ?? '').toString().toLowerCase();
        final sku = (p['sku'] ?? '').toString().toLowerCase();
        return name.contains(search) || sku.contains(search);
      }).toList();
    }

    products = result;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // 🔁 Làm mới dữ liệu
  // ---------------------------------------------------------------------------
  Future<void> refresh() async {
    loading = true;
    notifyListeners();

    await Future.wait([
      _loadBrands(),
      _loadCategories(),
      _loadProducts(),
    ]);

    loading = false;
    _applyFilters(); // áp dụng lại search/filter hiện tại
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // 🧱 CRUD sản phẩm
  // ---------------------------------------------------------------------------
  Future<String> upsertProduct({
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
    final now = FieldValue.serverTimestamp();
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
    };

    if (id == null || id.isEmpty) {
      final doc = await _db.collection('products').add({...data, 'createdAt': now});
      id = doc.id;
    } else {
      await _db.collection('products').doc(id).update(data);
    }

    await _loadProducts();
    _applyFilters();
    return id;
  }

  Future<void> deleteProduct(String id) async {
    final ref = _db.collection('products').doc(id);
    final variants = await ref.collection('variants').get();
    for (final v in variants.docs) {
      await v.reference.delete();
    }
    await ref.delete();

    await _loadProducts();
    _applyFilters();
  }

  // ---------------------------------------------------------------------------
  // 🧩 CRUD biến thể
  // ---------------------------------------------------------------------------
  Future<void> upsertVariant({
    String? id,
    required String productId,
    String? size,
    String? color,
    required double price,
    required int stock,
    String? imageUrl,
  }) async {
    final ref = _db.collection('products').doc(productId);
    final now = FieldValue.serverTimestamp();
    final data = {
      'size': size,
      'color': color,
      'price': price,
      'stock': stock,
      'imageUrl': imageUrl,
      'updatedAt': now,
    };

    if (id == null || id.isEmpty) {
      await ref.collection('variants').add({...data, 'createdAt': now});
    } else {
      await ref.collection('variants').doc(id).update(data);
    }
  }

  Future<void> deleteVariant(String productId, String variantId) async {
    await _db
        .collection('products')
        .doc(productId)
        .collection('variants')
        .doc(variantId)
        .delete();
  }

  Future<List<Map<String, dynamic>>> getVariants(String productId) async {
    final snap = await _db
        .collection('products')
        .doc(productId)
        .collection('variants')
        .orderBy('price')
        .get();
    return snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
  }

  // ---------------------------------------------------------------------------
  // ⚙️ Hỗ trợ
  // ---------------------------------------------------------------------------
  Future<Map<String, dynamic>?> getProductById(String id) async {
    final doc = await _db.collection('products').doc(id).get();
    return doc.exists ? {'id': doc.id, ...doc.data()!} : null;
  }

  Future<void> refreshRefs() async {
    await _loadBrands();
    await _loadCategories();
    notifyListeners();
  }
}
