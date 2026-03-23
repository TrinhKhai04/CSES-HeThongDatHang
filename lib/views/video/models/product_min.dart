class ProductMin {
  final String id;
  final String name;
  final num price;
  final String imageUrl;
  final int soldCount;
  final String status;

  ProductMin({
    required this.id,
    required this.name,
    required this.price,
    required this.imageUrl,
    required this.soldCount,
    required this.status,
  });

  factory ProductMin.fromMap(String id, Map<String, dynamic> d) {
    return ProductMin(
      id: id,
      name: (d['name'] ?? '') as String,
      price: (d['price'] ?? 0) as num,
      imageUrl: (d['imageUrl'] ?? '') as String,
      soldCount: (d['soldCount'] ?? 0) as int,
      status: (d['status'] ?? 'inactive') as String,
    );
  }
}
