/// Model đại diện cho một khách hàng (Customer)
class Customer {
  final String id;
  final String name;
  final String phone;
  final String? email;
  final int? createdAt;

  Customer({
    required this.id,
    required this.name,
    required this.phone,
    this.email,
    this.createdAt,
  });

  /// Chuyển Firestore document -> Customer object
  factory Customer.fromMap(Map<String, dynamic> map) {
    return Customer(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      phone: map['phone'] ?? '',
      email: map['email'],
      createdAt: map['createdAt'],
    );
  }

  /// Chuyển Customer object -> Map để lưu lên Firestore
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'email': email,
      'createdAt': createdAt ?? DateTime.now().millisecondsSinceEpoch,
    };
  }
}
