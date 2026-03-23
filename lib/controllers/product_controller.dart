import 'package:flutter/foundation.dart';
import '../data/repositories/product_repository.dart';
import '../models/product.dart';

/// Controller quản lý danh sách & chi tiết sản phẩm (dành cho người dùng)
class ProductController extends ChangeNotifier {
  final _repo = ProductRepository();

  List<Product> products = [];
  bool loading = false;

  /// -------------------------------
  /// 🧩 Lấy danh sách sản phẩm
  /// -------------------------------
  Future<void> fetch({String? keyword, String? category}) async {
    loading = true;
    notifyListeners();

    try {
      final rows = await _repo.getAll(keyword: keyword, category: category);
      products = rows.map((m) => Product.fromMap(m)).toList();
    } catch (e) {
      if (kDebugMode) {
        print('❌ [ProductController] fetch() error: $e');
      }
    }

    loading = false;
    notifyListeners();
  }

  /// -------------------------------
  /// 🔍 Lấy chi tiết sản phẩm theo ID
  /// -------------------------------
  Future<Map<String, dynamic>?> getProductById(String id) async {
    try {
      return await _repo.getById(id);
    } catch (e) {
      if (kDebugMode) {
        print('❌ [ProductController] getProductById error: $e');
      }
      return null;
    }
  }

  /// -------------------------------
  /// 🧱 Lấy danh sách biến thể của sản phẩm
  /// -------------------------------
  Future<List<Map<String, dynamic>>> getVariants(String productId) async {
    try {
      return await _repo.getVariants(productId);
    } catch (e) {
      if (kDebugMode) {
        print('❌ [ProductController] getVariants error: $e');
      }
      return [];
    }
  }

  /// -------------------------------
  /// 💡 Tìm sản phẩm trong cache (đã load)
  /// -------------------------------
  Product? findInCache(String id) {
    try {
      return products.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }

  /// -------------------------------
  /// 🔁 Refresh lại sản phẩm trong cache
  /// -------------------------------
  Future<void> refreshProduct(String id) async {
    final data = await getProductById(id);
    if (data == null) return;

    final updated = Product.fromMap(data);
    final index = products.indexWhere((p) => p.id == id);
    if (index >= 0) {
      products[index] = updated;
    } else {
      products.add(updated);
    }

    notifyListeners();
  }
}
