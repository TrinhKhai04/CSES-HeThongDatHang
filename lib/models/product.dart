class Product {
  final String id;
  final String name;
  final double price;
  final String? sku;
  final String? description;
  final String? imageUrl;
  final String? brandId;
  final String? categoryId;

  // Legacy (vẫn giữ để migrate dữ liệu cũ)
  final String? category;

  /// Số lượng đã bán (dùng để sort sản phẩm bán chạy, gợi ý, v.v.)
  final int soldCount;

  final String status; // 'active' | 'inactive'
  final int? createdAt;
  final int? updatedAt;

  Product({
    required this.id,
    required this.name,
    required this.price,
    this.sku,
    this.description,
    this.imageUrl,
    this.brandId,
    this.categoryId,
    this.category,
    this.soldCount = 0, // 👈 mặc định 0 nếu chưa có dữ liệu
    this.status = 'active',
    this.createdAt,
    this.updatedAt,
  });

  /// 🔹 Parse từ Firestore hoặc Map cục bộ
  factory Product.fromMap(Map<String, dynamic> m) {
    // helper nhỏ để convert mọi kiểu về int
    int _toInt(dynamic v) {
      if (v == null) return 0;
      if (v is int) return v;
      if (v is num) return v.toInt();
      return int.tryParse('$v') ?? 0;
    }

    return Product(
      id: (m['id'] ?? '').toString(),
      name: (m['name'] ?? '').toString(),
      price: (m['price'] is num)
          ? (m['price'] as num).toDouble()
          : double.tryParse('${m['price']}') ?? 0,
      sku: (m['sku'] as String?)?.trim(),
      description: (m['description'] as String?)?.trim(),
      imageUrl: (m['imageUrl'] as String?)?.trim(),
      brandId: (m['brandId'] as String?)?.trim(),
      categoryId: (m['categoryId'] as String?)?.trim(),
      category: (m['category'] as String?)?.trim(), // legacy support
      soldCount: _toInt(m['soldCount']), // 👈 đọc từ Firestore / Map
      status: (m['status'] as String?)?.trim() ?? 'active',
      createdAt: (m['createdAt'] is int)
          ? m['createdAt']
          : int.tryParse('${m['createdAt'] ?? 0}'),
      updatedAt: (m['updatedAt'] is int)
          ? m['updatedAt']
          : int.tryParse('${m['updatedAt'] ?? 0}'),
    );
  }

  /// 🔹 Dùng khi cần lưu lên Firestore
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'price': price,
      'sku': sku,
      'description': description,
      'imageUrl': imageUrl,
      'brandId': brandId,
      'categoryId': categoryId,
      'category': category,
      'soldCount': soldCount, // 👈 lưu số lượng đã bán
      'status': status,
      'createdAt': createdAt ?? DateTime.now().millisecondsSinceEpoch,
      'updatedAt': updatedAt ?? DateTime.now().millisecondsSinceEpoch,
    };
  }

  /// 🔹 Dễ dàng clone khi cần cập nhật
  Product copyWith({
    String? id,
    String? name,
    double? price,
    String? sku,
    String? description,
    String? imageUrl,
    String? brandId,
    String? categoryId,
    String? category,
    int? soldCount,
    String? status,
    int? createdAt,
    int? updatedAt,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      price: price ?? this.price,
      sku: sku ?? this.sku,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      brandId: brandId ?? this.brandId,
      categoryId: categoryId ?? this.categoryId,
      category: category ?? this.category,
      soldCount: soldCount ?? this.soldCount,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
