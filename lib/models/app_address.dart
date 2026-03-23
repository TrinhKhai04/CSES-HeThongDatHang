/// 🏠 Model đại diện cho một địa chỉ giao hàng của người dùng.
/// Firestore: users/{uid}/addresses/{addressId}
class AppAddress {
  final String id;
  final String name;
  final String phone;
  final String line1;
  final String ward;
  final String district;
  final String province;
  final bool isDefault;

  /// 🆕 Toạ độ (có thể null nếu chưa chọn trên bản đồ)
  final double? lat;
  final double? lng;

  const AppAddress({
    required this.id,
    required this.name,
    required this.phone,
    required this.line1,
    required this.ward,
    required this.district,
    required this.province,
    required this.isDefault,
    this.lat,
    this.lng,
  });

  // ===== Convenience getters =====
  String get fullName => name;
  String get fullAddress => '$line1, $ward, $district, $province';
  bool get hasGeo => lat != null && lng != null;

  // ===== Copy / Map helpers =====
  AppAddress copyWith({
    String? id,
    String? name,
    String? phone,
    String? line1,
    String? ward,
    String? district,
    String? province,
    bool? isDefault,
    double? lat,
    double? lng,
  }) {
    return AppAddress(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      line1: line1 ?? this.line1,
      ward: ward ?? this.ward,
      district: district ?? this.district,
      province: province ?? this.province,
      isDefault: isDefault ?? this.isDefault,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
    );
  }

  /// Parse double an toàn từ num/String/null
  static double? _toD(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  factory AppAddress.fromMap(String id, Map<String, dynamic> map) {
    return AppAddress(
      id: id,
      name: (map['name'] ?? '') as String,
      phone: (map['phone'] ?? '') as String,
      line1: (map['line1'] ?? '') as String,
      ward: (map['ward'] ?? '') as String,
      district: (map['district'] ?? '') as String,
      province: (map['province'] ?? '') as String,
      isDefault: (map['isDefault'] ?? false) as bool,
      lat: _toD(map['lat']),   // 🆕
      lng: _toD(map['lng']),   // 🆕
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'phone': phone,
      'line1': line1,
      'ward': ward,
      'district': district,
      'province': province,
      'isDefault': isDefault,
      if (lat != null) 'lat': lat,   // 🆕 chỉ ghi khi có
      if (lng != null) 'lng': lng,   // 🆕 chỉ ghi khi có
    };
  }
}
