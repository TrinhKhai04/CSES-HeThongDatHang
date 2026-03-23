// lib/views/wishlist/wishlist_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/wishlist_controller.dart';
import '../../models/product.dart';
import '../product/widgets/product_grid_item.dart';

class WishlistScreen extends StatelessWidget {
  const WishlistScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final wish = context.watch<WishlistController>();
    final ids = wish.ids.toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Favorites')),
      body: ids.isEmpty
          ? const Center(child: Text('Chưa có sản phẩm yêu thích'))
          : FutureBuilder<List<Product>>(
        future: _fetchProducts(ids),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('Lỗi: ${snap.error}'));
          }
          final products = snap.data ?? const <Product>[];
          if (products.isEmpty) {
            return const Center(child: Text('Không tìm thấy sản phẩm'));
          }

          return GridView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: products.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: .7,
            ),
            itemBuilder: (_, i) => ProductGridItem(model: products[i]),
          );
        },
      ),
    );
  }

  /// Firestore whereIn tối đa 10 phần tử → chia mảng theo lô
  Future<List<Product>> _fetchProducts(List<String> ids) async {
    final col = FirebaseFirestore.instance.collection('products');

    final chunks = <List<String>>[];
    for (var i = 0; i < ids.length; i += 10) {
      chunks.add(ids.sublist(i, i + 10 > ids.length ? ids.length : i + 10));
    }

    final snapshots = await Future.wait(
      chunks.map((c) => col.where(FieldPath.documentId, whereIn: c).get()),
    );

    final docs = snapshots.expand((qs) => qs.docs).toList();
    final products = docs.map(_docToProduct).toList();

    // Giữ nguyên thứ tự theo wishlist (ids)
    final order = {for (var i = 0; i < ids.length; i++) ids[i]: i};
    products.sort((a, b) => (order[a.id] ?? 1 << 30).compareTo(order[b.id] ?? 1 << 30));

    return products;
  }

  /// Map DocumentSnapshot -> Product (best-effort, tương thích schema cũ/mới)
  Product _docToProduct(DocumentSnapshot d) {
    final m = (d.data() as Map<String, dynamic>?) ?? {};

    // Ảnh: ưu tiên imageUrl, fallback images[0]
    String? imageUrl;
    if (m['imageUrl'] is String && (m['imageUrl'] as String).isNotEmpty) {
      imageUrl = m['imageUrl'] as String;
    } else if (m['images'] is List && (m['images'] as List).isNotEmpty) {
      final first = (m['images'] as List).first;
      if (first is String) imageUrl = first;
    }

    // 👇 Ép về double an toàn (int/double/String)
    final double price = _toDouble(m['price'] ?? m['salePrice'] ?? 0);

    return Product(
      id: d.id,
      name: (m['name'] ?? m['title'] ?? 'Không tên').toString(),
      price: price,        // <- double
      imageUrl: imageUrl,  // có thể null
      // Nếu Product có field bắt buộc khác, truyền thêm cho khớp constructor.
    );
  }

  double _toDouble(dynamic v) {
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is String) {
      final s = v.replaceAll(',', '').trim();
      return double.tryParse(s) ?? 0.0;
    }
    return 0.0;
  }
}
