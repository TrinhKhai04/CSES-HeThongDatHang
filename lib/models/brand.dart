/// Model đại diện cho 1 thương hiệu (Brand)
class Brand {
  final String id;
  final String name;

  Brand({
    required this.id,
    required this.name,
  });

  /// Chuyển từ Firestore document -> Brand object
  factory Brand.fromMap(Map<String, dynamic> map) {
    return Brand(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
    );
  }

  /// Chuyển Brand -> Map để ghi lên Firestore
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
    };
  }
}
