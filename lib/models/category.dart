/// Model đại diện cho 1 danh mục sản phẩm (Category)
class Category {
  final String id;
  final String name;

  Category({
    required this.id,
    required this.name,
  });

  /// Tạo Category từ Firestore document
  factory Category.fromMap(Map<String, dynamic> map) {
    return Category(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
    );
  }

  /// Chuyển Category -> Map để ghi lên Firestore
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
    };
  }
}
