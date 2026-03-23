class OrderItem {
  final String id;
  final String orderId;
  final String productId;
  final int qty;
  final double price;

  /// ID biến thể (nếu có). Ví dụ: products/{productId}/variants/{variantId}
  final String? variantId;

  /// Tuỳ chọn hiển thị nhanh: {'size':'L','color':'Đen', ...}
  final Map<String, dynamic>? options;

  OrderItem({
    required this.id,
    required this.orderId,
    required this.productId,
    required this.qty,
    required this.price,
    this.variantId,
    this.options,
  });

  factory OrderItem.fromMap(Map<String, dynamic> map) {
    return OrderItem(
      id: (map['id'] ?? '') as String,
      orderId: (map['orderId'] ?? '') as String,
      productId: (map['productId'] ?? '') as String,
      qty: (map['qty'] ?? 0) as int,
      price: ((map['price'] ?? 0) as num).toDouble(),
      variantId: map['variantId'] as String?, // có thể null
      options: (map['options'] is Map)
          ? (map['options'] as Map).cast<String, dynamic>()
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'orderId': orderId,
      'productId': productId,
      'qty': qty,
      'price': price,
      if (variantId != null) 'variantId': variantId,
      if (options != null) 'options': options,
    };
  }

  OrderItem copyWith({
    String? id,
    String? orderId,
    String? productId,
    int? qty,
    double? price,
    String? variantId,
    Map<String, dynamic>? options,
  }) {
    return OrderItem(
      id: id ?? this.id,
      orderId: orderId ?? this.orderId,
      productId: productId ?? this.productId,
      qty: qty ?? this.qty,
      price: price ?? this.price,
      variantId: variantId ?? this.variantId,
      options: options ?? this.options,
    );
  }
}
