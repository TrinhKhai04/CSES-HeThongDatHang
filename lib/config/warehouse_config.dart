// lib/config/warehouse_config.dart
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

@immutable
class Geo {
  final double latitude;
  final double longitude;

  const Geo(this.latitude, this.longitude);
}

/// Trạng thái kho
enum WarehouseStatus { active, paused, closed }

extension WarehouseStatusX on WarehouseStatus {
  /// Parse từ string Firestore
  static WarehouseStatus fromString(String? v) {
    switch (v) {
      case 'paused':
        return WarehouseStatus.paused;
      case 'closed':
        return WarehouseStatus.closed;
      case 'active':
      default:
        return WarehouseStatus.active;
    }
  }

  /// String lưu trong Firestore
  String get asString {
    switch (this) {
      case WarehouseStatus.active:
        return 'active';
      case WarehouseStatus.paused:
        return 'paused';
      case WarehouseStatus.closed:
        return 'closed';
    }
  }

  /// Label hiển thị
  String get label {
    switch (this) {
      case WarehouseStatus.active:
        return 'Đang hoạt động';
      case WarehouseStatus.paused:
        return 'Tạm ngừng';
      case WarehouseStatus.closed:
        return 'Đã đóng';
    }
  }

  bool get isActive => this == WarehouseStatus.active;
}

class Warehouse {
  final String code; // Mã: HCM_MAIN / HN_MAIN / DN_MAIN / GL / KH...
  final String name; // Tên kho
  final String address; // Địa chỉ mô tả
  final Geo location; // Toạ độ kho
  final List<String> keywords; // Từ khoá tỉnh/thành (có dấu + không dấu)
  final bool isMainHub; // true = kho chính (HCM / HN / DN)
  final WarehouseStatus status; // Trạng thái kho

  const Warehouse({
    required this.code,
    required this.name,
    required this.address,
    required this.location,
    this.keywords = const [],
    this.isMainHub = false,
    this.status = WarehouseStatus.active, // mặc định active
  });

  /// Nạp từ map (Firestore)
  factory Warehouse.fromMap(Map<String, dynamic> map) {
    double _toDouble(dynamic v) {
      if (v == null) return 0;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString()) ?? 0;
    }

    final lat = _toDouble(map['lat'] ?? map['latitude']);
    final lng = _toDouble(map['lng'] ?? map['longitude']);

    // keywords
    final kwsRaw = map['keywords'];
    final List<String> kws = [];
    if (kwsRaw is List) {
      for (final x in kwsRaw) {
        if (x == null) continue;
        final s = x.toString().trim();
        if (s.isNotEmpty) kws.add(s);
      }
    }

    // 🔑 Ưu tiên status; nếu không có thì fallback theo isActive
    final statusStr = map['status'] as String?;
    final dynamic isActiveRaw = map['isActive']; // bool hoặc null

    WarehouseStatus status;

    if (statusStr != null) {
      // Nếu bạn đã migrate sang string status
      status = WarehouseStatusX.fromString(statusStr);
    } else if (isActiveRaw is bool && isActiveRaw == false) {
      // Chỉ có isActive=false -> coi là tạm ngừng
      status = WarehouseStatus.paused;
    } else {
      // Mặc định: đang hoạt động
      status = WarehouseStatus.active;
    }

    return Warehouse(
      code: (map['code'] ?? '').toString(),
      name: (map['name'] ?? '').toString(),
      address: (map['address'] ?? '').toString(),
      location: Geo(lat, lng),
      keywords: kws,
      isMainHub: map['isMainHub'] == true,
      status: status,
    );
  }

  /// Map để lưu Firestore
  Map<String, dynamic> toMap() {
    return {
      'code': code,
      'name': name,
      'address': address,
      'lat': location.latitude,
      'lng': location.longitude,
      'keywords': keywords,
      'isMainHub': isMainHub,
      // cho code cũ vẫn dùng isActive được
      'isActive': status.isActive,
      // field mới
      'status': status.asString,
    };
  }

  Warehouse copyWith({
    String? code,
    String? name,
    String? address,
    Geo? location,
    List<String>? keywords,
    bool? isMainHub,
    WarehouseStatus? status,
  }) {
    return Warehouse(
      code: code ?? this.code,
      name: name ?? this.name,
      address: address ?? this.address,
      location: location ?? this.location,
      keywords: keywords ?? this.keywords,
      isMainHub: isMainHub ?? this.isMainHub,
      status: status ?? this.status,
    );
  }
}

class WarehouseConfig {
  /// Đơn gần: nếu từ kho chính tới khách <= 50km thì giao thẳng WH → CUS
  static const double kDirectShipMaxKm = 50.0;

  /// Bảng map bỏ dấu tiếng Việt để so khớp tỉnh/thành chắc hơn
  static const Map<String, String> _accentMap = {
    'à': 'a',
    'á': 'a',
    'ạ': 'a',
    'ả': 'a',
    'ã': 'a',
    'â': 'a',
    'ầ': 'a',
    'ấ': 'a',
    'ậ': 'a',
    'ẩ': 'a',
    'ẫ': 'a',
    'ă': 'a',
    'ằ': 'a',
    'ắ': 'a',
    'ặ': 'a',
    'ẳ': 'a',
    'ẵ': 'a',
    'è': 'e',
    'é': 'e',
    'ẹ': 'e',
    'ẻ': 'e',
    'ẽ': 'e',
    'ê': 'e',
    'ề': 'e',
    'ế': 'e',
    'ệ': 'e',
    'ể': 'e',
    'ễ': 'e',
    'ì': 'i',
    'í': 'i',
    'ị': 'i',
    'ỉ': 'i',
    'ĩ': 'i',
    'ò': 'o',
    'ó': 'o',
    'ọ': 'o',
    'ỏ': 'o',
    'õ': 'o',
    'ô': 'o',
    'ồ': 'o',
    'ố': 'o',
    'ộ': 'o',
    'ổ': 'o',
    'ỗ': 'o',
    'ơ': 'o',
    'ờ': 'o',
    'ớ': 'o',
    'ợ': 'o',
    'ở': 'o',
    'ỡ': 'o',
    'ù': 'u',
    'ú': 'u',
    'ụ': 'u',
    'ủ': 'u',
    'ũ': 'u',
    'ư': 'u',
    'ừ': 'u',
    'ứ': 'u',
    'ự': 'u',
    'ử': 'u',
    'ữ': 'u',
    'ỳ': 'y',
    'ý': 'y',
    'ỵ': 'y',
    'ỷ': 'y',
    'ỹ': 'y',
    'đ': 'd',
  };

  /// Bỏ dấu + về lowercase để so khớp từ khoá dễ hơn
  static String _normalize(String s) {
    final lower = s.toLowerCase();
    final buf = StringBuffer();
    for (final codeUnit in lower.codeUnits) {
      final ch = String.fromCharCode(codeUnit);
      buf.write(_accentMap[ch] ?? ch);
    }
    return buf.toString();
  }

  /// Code hub lưu vào legs để:
  /// - OrderRoutePage hiện tại vẫn nhận diện "HUB" bằng contains('HUB')
  /// - Có thể biết chính xác HUB nào (HUB_GL, HUB_KH, ...)
  static String _hubLegCode(String rawWarehouseCode) =>
      'HUB_${rawWarehouseCode.toUpperCase()}';

  // ===================================================================
  // 1. KHO CHÍNH TOÀN QUỐC (MAIN HUBS) – HCM / ĐÀ NẴNG / HÀ NỘI
  // ===================================================================

  /// Danh sách mặc định (hard-code)
  static const List<Warehouse> kMainHubs = [
    Warehouse(
      code: 'HCM_MAIN',
      name: 'Kho chính Hồ Chí Minh',
      address: 'Quận Tân Bình, TP. Hồ Chí Minh',
      location: Geo(10.801465, 106.652597),
      isMainHub: true,
      status: WarehouseStatus.active,
      keywords: [
        'hồ chí minh',
        'ho chi minh',
        'tp.hcm',
        'hcm',
        'sai gon',
        'sài gòn',
      ],
    ),
    Warehouse(
      code: 'DN_MAIN',
      name: 'Kho chính Đà Nẵng',
      address: 'Quận Cẩm Lệ, TP. Đà Nẵng',
      location: Geo(16.047199, 108.206320),
      isMainHub: true,
      status: WarehouseStatus.active,
      keywords: [
        'đà nẵng',
        'da nang',
      ],
    ),
    Warehouse(
      code: 'HN_MAIN',
      name: 'Kho chính Hà Nội',
      address: 'Nam Từ Liêm, Hà Nội',
      location: Geo(21.028511, 105.804817),
      isMainHub: true,
      status: WarehouseStatus.active,
      keywords: [
        'hà nội',
        'ha noi',
        'hn',
      ],
    ),
  ];

  // ===================================================================
  // 2. KHO TRUNG CHUYỂN THEO TỈNH/THÀNH (TRANSIT WAREHOUSES)
  // ===================================================================

  static const List<Warehouse> kTransitWarehouses = [
    // ===== Miền Nam / Tây Nam Bộ =====
    Warehouse(
      code: 'AG',
      name: 'Kho trung chuyển An Giang',
      address: 'Long Xuyên, An Giang',
      location: Geo(10.3865, 105.4352),
      status: WarehouseStatus.active,
      keywords: ['an giang'],
    ),
    Warehouse(
      code: 'CM',
      name: 'Kho trung chuyển Cà Mau',
      address: 'TP. Cà Mau, Cà Mau',
      location: Geo(9.1768, 105.1524),
      status: WarehouseStatus.active,
      keywords: ['cà mau', 'ca mau'],
    ),
    Warehouse(
      code: 'KG',
      name: 'Kho trung chuyển Kiên Giang',
      address: 'Rạch Giá, Kiên Giang',
      location: Geo(10.0125, 105.0809),
      status: WarehouseStatus.active,
      keywords: ['kiên giang', 'kien giang'],
    ),
    Warehouse(
      code: 'DT',
      name: 'Kho trung chuyển Đồng Tháp',
      address: 'Cao Lãnh, Đồng Tháp',
      location: Geo(10.4550, 105.6329),
      status: WarehouseStatus.active,
      keywords: ['đồng tháp', 'dong thap'],
    ),
    Warehouse(
      code: 'LA',
      name: 'Kho trung chuyển Long An',
      address: 'Tân An, Long An',
      location: Geo(10.5390, 106.4058),
      status: WarehouseStatus.active,
      keywords: ['long an'],
    ),
    Warehouse(
      code: 'TG',
      name: 'Kho trung chuyển Tiền Giang',
      address: 'Mỹ Tho, Tiền Giang',
      location: Geo(10.3541, 106.3635),
      status: WarehouseStatus.active,
      keywords: ['tiền giang', 'tien giang'],
    ),
    Warehouse(
      code: 'VL',
      name: 'Kho trung chuyển Vĩnh Long',
      address: 'TP. Vĩnh Long, Vĩnh Long',
      location: Geo(10.2560, 105.9719),
      status: WarehouseStatus.active,
      keywords: ['vĩnh long', 'vinh long'],
    ),
    Warehouse(
      code: 'TV',
      name: 'Kho trung chuyển Trà Vinh',
      address: 'TP. Trà Vinh, Trà Vinh',
      location: Geo(9.9347, 106.3440),
      status: WarehouseStatus.active,
      keywords: ['trà vinh', 'tra vinh'],
    ),
    Warehouse(
      code: 'ST',
      name: 'Kho trung chuyển Sóc Trăng',
      address: 'TP. Sóc Trăng, Sóc Trăng',
      location: Geo(9.6000, 105.9719),
      status: WarehouseStatus.active,
      keywords: ['sóc trăng', 'soc trang'],
    ),
    Warehouse(
      code: 'BL',
      name: 'Kho trung chuyển Bạc Liêu',
      address: 'TP. Bạc Liêu, Bạc Liêu',
      location: Geo(9.2850, 105.7240),
      status: WarehouseStatus.active,
      keywords: ['bạc liêu', 'bac lieu'],
    ),
    Warehouse(
      code: 'HG_SU',
      name: 'Kho trung chuyển Hậu Giang',
      address: 'Vị Thanh, Hậu Giang',
      location: Geo(9.7845, 105.4700),
      status: WarehouseStatus.active,
      keywords: ['hậu giang', 'hau giang'],
    ),

    // ===== Đông Nam Bộ =====
    Warehouse(
      code: 'BD',
      name: 'Kho trung chuyển Bình Dương',
      address: 'Thủ Dầu Một, Bình Dương',
      location: Geo(10.9804, 106.6519),
      status: WarehouseStatus.active,
      keywords: ['bình dương', 'binh duong'],
    ),
    Warehouse(
      code: 'DNA',
      name: 'Kho trung chuyển Đồng Nai',
      address: 'Biên Hòa, Đồng Nai',
      location: Geo(10.9573, 106.8451),
      status: WarehouseStatus.active,
      keywords: ['đồng nai', 'dong nai'],
    ),
    Warehouse(
      code: 'BRVT',
      name: 'Kho trung chuyển Bà Rịa - Vũng Tàu',
      address: 'Bà Rịa, Bà Rịa - Vũng Tàu',
      location: Geo(10.4960, 107.1684),
      status: WarehouseStatus.active,
      keywords: [
        'bà rịa',
        'ba ria',
        'vũng tàu',
        'vung tau',
        'bà rịa - vũng tàu',
        'ba ria vung tau',
      ],
    ),
    Warehouse(
      code: 'BP',
      name: 'Kho trung chuyển Bình Phước',
      address: 'Đồng Xoài, Bình Phước',
      location: Geo(11.5350, 106.8830),
      status: WarehouseStatus.active,
      keywords: ['bình phước', 'binh phuoc'],
    ),
    Warehouse(
      code: 'TN',
      name: 'Kho trung chuyển Tây Ninh',
      address: 'TP. Tây Ninh, Tây Ninh',
      location: Geo(11.3100, 106.0980),
      status: WarehouseStatus.active,
      keywords: ['tây ninh', 'tay ninh'],
    ),

    // ===== Tây Nguyên =====
    Warehouse(
      code: 'LD',
      name: 'Kho trung chuyển Lâm Đồng',
      address: 'Đà Lạt, Lâm Đồng',
      location: Geo(11.9404, 108.4583),
      status: WarehouseStatus.active,
      keywords: ['lâm đồng', 'lam dong', 'da lat', 'đà lạt'],
    ),
    Warehouse(
      code: 'DLK',
      name: 'Kho trung chuyển Đắk Lắk',
      address: 'Buôn Ma Thuột, Đắk Lắk',
      location: Geo(12.6675, 108.0377),
      status: WarehouseStatus.active,
      keywords: ['dak lak', 'đắk lắk', 'buon ma thuot', 'buôn ma thuột'],
    ),
    Warehouse(
      code: 'DNO',
      name: 'Kho trung chuyển Đắk Nông',
      address: 'Gia Nghĩa, Đắk Nông',
      location: Geo(12.0043, 107.6907),
      status: WarehouseStatus.active,
      keywords: ['đắk nông', 'dak nong'],
    ),
    Warehouse(
      code: 'GL',
      name: 'Kho trung chuyển Gia Lai',
      address: 'Pleiku, Gia Lai',
      location: Geo(13.9716, 108.0151),
      status: WarehouseStatus.active,
      keywords: ['gia lai', 'pleiku'],
    ),
    Warehouse(
      code: 'KT',
      name: 'Kho trung chuyển Kon Tum',
      address: 'TP. Kon Tum, Kon Tum',
      location: Geo(14.3545, 108.0076),
      status: WarehouseStatus.active,
      keywords: ['kon tum'],
    ),

    // ===== Duyên hải Nam Trung Bộ =====
    Warehouse(
      code: 'KH',
      name: 'Kho trung chuyển Khánh Hòa',
      address: 'Nha Trang, Khánh Hòa',
      location: Geo(12.2388, 109.1967),
      status: WarehouseStatus.active,
      keywords: ['khánh hòa', 'khanh hoa', 'nha trang'],
    ),
    Warehouse(
      code: 'PY',
      name: 'Kho trung chuyển Phú Yên',
      address: 'Tuy Hòa, Phú Yên',
      location: Geo(13.0955, 109.3209),
      status: WarehouseStatus.active,
      keywords: ['phú yên', 'phu yen'],
    ),
    Warehouse(
      code: 'NT',
      name: 'Kho trung chuyển Ninh Thuận',
      address: 'Phan Rang - Tháp Chàm, Ninh Thuận',
      location: Geo(11.5670, 108.9886),
      status: WarehouseStatus.active,
      keywords: ['ninh thuận', 'ninh thuan'],
    ),
    Warehouse(
      code: 'BTH',
      name: 'Kho trung chuyển Bình Thuận',
      address: 'Phan Thiết, Bình Thuận',
      location: Geo(10.9333, 108.1000),
      status: WarehouseStatus.active,
      keywords: ['bình thuận', 'binh thuan', 'phan thiet', 'phan thiết'],
    ),
    Warehouse(
      code: 'BDH',
      name: 'Kho trung chuyển Bình Định',
      address: 'Quy Nhơn, Bình Định',
      location: Geo(13.7765, 109.2237),
      status: WarehouseStatus.active,
      keywords: ['bình định', 'binh dinh', 'quy nhon', 'quy nhơn'],
    ),
    Warehouse(
      code: 'QNG',
      name: 'Kho trung chuyển Quảng Ngãi',
      address: 'TP. Quảng Ngãi, Quảng Ngãi',
      location: Geo(15.1200, 108.7923),
      status: WarehouseStatus.active,
      keywords: ['quảng ngãi', 'quang ngai'],
    ),
    Warehouse(
      code: 'QNA',
      name: 'Kho trung chuyển Quảng Nam',
      address: 'Tam Kỳ, Quảng Nam',
      location: Geo(15.5736, 108.4740),
      status: WarehouseStatus.active,
      keywords: ['quảng nam', 'quang nam'],
    ),

    // ===== Bắc Trung Bộ & Bắc duyên hải =====
    Warehouse(
      code: 'TTH',
      name: 'Kho trung chuyển Thừa Thiên Huế',
      address: 'Huế, Thừa Thiên Huế',
      location: Geo(16.4637, 107.5909),
      status: WarehouseStatus.active,
      keywords: ['thừa thiên huế', 'thua thien hue', 'hue', 'huế'],
    ),
    Warehouse(
      code: 'QB',
      name: 'Kho trung chuyển Quảng Bình',
      address: 'Đồng Hới, Quảng Bình',
      location: Geo(17.4688, 106.6223),
      status: WarehouseStatus.active,
      keywords: ['quảng bình', 'quang binh'],
    ),
    Warehouse(
      code: 'QT',
      name: 'Kho trung chuyển Quảng Trị',
      address: 'Đông Hà, Quảng Trị',
      location: Geo(16.8159, 107.1003),
      status: WarehouseStatus.active,
      keywords: ['quảng trị', 'quang tri'],
    ),
    Warehouse(
      code: 'HT',
      name: 'Kho trung chuyển Hà Tĩnh',
      address: 'TP. Hà Tĩnh, Hà Tĩnh',
      location: Geo(18.3428, 105.9057),
      status: WarehouseStatus.active,
      keywords: ['hà tĩnh', 'ha tinh'],
    ),
    Warehouse(
      code: 'NA',
      name: 'Kho trung chuyển Nghệ An',
      address: 'Vinh, Nghệ An',
      location: Geo(18.6733, 105.6923),
      status: WarehouseStatus.active,
      keywords: ['nghệ an', 'nghe an', 'vinh'],
    ),
    Warehouse(
      code: 'TH',
      name: 'Kho trung chuyển Thanh Hóa',
      address: 'TP. Thanh Hóa, Thanh Hóa',
      location: Geo(19.8067, 105.7764),
      status: WarehouseStatus.active,
      keywords: ['thanh hóa', 'thanh hoa'],
    ),

    // ===== Đồng bằng sông Hồng & Đông Bắc Bộ =====
    Warehouse(
      code: 'HP',
      name: 'Kho trung chuyển Hải Phòng',
      address: 'Lê Chân, Hải Phòng',
      location: Geo(20.8449, 106.6881),
      status: WarehouseStatus.active,
      keywords: ['hải phòng', 'hai phong'],
    ),
    Warehouse(
      code: 'QNI',
      name: 'Kho trung chuyển Quảng Ninh',
      address: 'Hạ Long, Quảng Ninh',
      location: Geo(20.9710, 107.0448),
      status: WarehouseStatus.active,
      keywords: ['quảng ninh', 'quang ninh', 'ha long', 'hạ long'],
    ),
    Warehouse(
      code: 'HD',
      name: 'Kho trung chuyển Hải Dương',
      address: 'TP. Hải Dương, Hải Dương',
      location: Geo(20.9390, 106.3306),
      status: WarehouseStatus.active,
      keywords: ['hải dương', 'hai duong'],
    ),
    Warehouse(
      code: 'BN',
      name: 'Kho trung chuyển Bắc Ninh',
      address: 'TP. Bắc Ninh, Bắc Ninh',
      location: Geo(21.1861, 106.0763),
      status: WarehouseStatus.active,
      keywords: ['bắc ninh', 'bac ninh'],
    ),
    Warehouse(
      code: 'HY',
      name: 'Kho trung chuyển Hưng Yên',
      address: 'TP. Hưng Yên, Hưng Yên',
      location: Geo(20.6463, 106.0510),
      status: WarehouseStatus.active,
      keywords: ['hưng yên', 'hung yen'],
    ),
    Warehouse(
      code: 'TB',
      name: 'Kho trung chuyển Thái Bình',
      address: 'TP. Thái Bình, Thái Bình',
      location: Geo(20.4489, 106.3423),
      status: WarehouseStatus.active,
      keywords: ['thái bình', 'thai binh'],
    ),
    Warehouse(
      code: 'ND',
      name: 'Kho trung chuyển Nam Định',
      address: 'TP. Nam Định, Nam Định',
      location: Geo(20.4203, 106.1683),
      status: WarehouseStatus.active,
      keywords: ['nam định', 'nam dinh'],
    ),
    Warehouse(
      code: 'NB',
      name: 'Kho trung chuyển Ninh Bình',
      address: 'TP. Ninh Bình, Ninh Bình',
      location: Geo(20.2539, 105.9755),
      status: WarehouseStatus.active,
      keywords: ['ninh bình', 'ninh binh'],
    ),
    Warehouse(
      code: 'VP',
      name: 'Kho trung chuyển Vĩnh Phúc',
      address: 'Vĩnh Yên, Vĩnh Phúc',
      location: Geo(21.3086, 105.6049),
      status: WarehouseStatus.active,
      keywords: ['vĩnh phúc', 'vinh phuc'],
    ),
    Warehouse(
      code: 'PT',
      name: 'Kho trung chuyển Phú Thọ',
      address: 'Việt Trì, Phú Thọ',
      location: Geo(21.3220, 105.4020),
      status: WarehouseStatus.active,
      keywords: ['phú thọ', 'phu tho'],
    ),
    Warehouse(
      code: 'HB',
      name: 'Kho trung chuyển Hòa Bình',
      address: 'TP. Hòa Bình, Hòa Bình',
      location: Geo(20.8172, 105.3376),
      status: WarehouseStatus.active,
      keywords: ['hòa bình', 'hoa binh'],
    ),

    // ===== Trung du & miền núi phía Bắc =====
    Warehouse(
      code: 'BG',
      name: 'Kho trung chuyển Bắc Giang',
      address: 'TP. Bắc Giang, Bắc Giang',
      location: Geo(21.2731, 106.1945),
      status: WarehouseStatus.active,
      keywords: ['bắc giang', 'bac giang'],
    ),
    Warehouse(
      code: 'QNINH',
      name: 'Kho trung chuyển Quảng Ninh (miền núi)',
      address: 'Cẩm Phả, Quảng Ninh',
      location: Geo(21.0167, 107.3000),
      status: WarehouseStatus.active,
      keywords: ['cam pha', 'cẩm phả'],
    ),
    Warehouse(
      code: 'LC',
      name: 'Kho trung chuyển Lào Cai',
      address: 'Lào Cai, Lào Cai',
      location: Geo(22.4850, 103.9700),
      status: WarehouseStatus.active,
      keywords: ['lào cai', 'lao cai'],
    ),
    Warehouse(
      code: 'LS',
      name: 'Kho trung chuyển Lạng Sơn',
      address: 'TP. Lạng Sơn, Lạng Sơn',
      location: Geo(21.8537, 106.7610),
      status: WarehouseStatus.active,
      keywords: ['lạng sơn', 'lang son'],
    ),
    Warehouse(
      code: 'YB',
      name: 'Kho trung chuyển Yên Bái',
      address: 'TP. Yên Bái, Yên Bái',
      location: Geo(21.7050, 104.8710),
      status: WarehouseStatus.active,
      keywords: ['yên bái', 'yen bai'],
    ),
    Warehouse(
      code: 'SL',
      name: 'Kho trung chuyển Sơn La',
      address: 'TP. Sơn La, Sơn La',
      location: Geo(21.3280, 103.9140),
      status: WarehouseStatus.active,
      keywords: ['sơn la', 'son la'],
    ),
    Warehouse(
      code: 'HG',
      name: 'Kho trung chuyển Hà Giang',
      address: 'TP. Hà Giang, Hà Giang',
      location: Geo(22.8233, 104.9836),
      status: WarehouseStatus.active,
      keywords: ['hà giang', 'ha giang'],
    ),
    Warehouse(
      code: 'CB',
      name: 'Kho trung chuyển Cao Bằng',
      address: 'TP. Cao Bằng, Cao Bằng',
      location: Geo(22.6657, 106.2570),
      status: WarehouseStatus.active,
      keywords: ['cao bằng', 'cao bang'],
    ),
    Warehouse(
      code: 'BK',
      name: 'Kho trung chuyển Bắc Kạn',
      address: 'TP. Bắc Kạn, Bắc Kạn',
      location: Geo(22.1450, 105.8345),
      status: WarehouseStatus.active,
      keywords: ['bắc kạn', 'bac kan'],
    ),
    Warehouse(
      code: 'TQ',
      name: 'Kho trung chuyển Tuyên Quang',
      address: 'TP. Tuyên Quang, Tuyên Quang',
      location: Geo(21.8183, 105.2211),
      status: WarehouseStatus.active,
      keywords: ['tuyên quang', 'tuyen quang'],
    ),
    Warehouse(
      code: 'LCU',
      name: 'Kho trung chuyển Lai Châu',
      address: 'TP. Lai Châu, Lai Châu',
      location: Geo(22.3964, 103.4580),
      status: WarehouseStatus.active,
      keywords: ['lai châu', 'lai chau'],
    ),
    Warehouse(
      code: 'DB',
      name: 'Kho trung chuyển Điện Biên',
      address: 'Điện Biên Phủ, Điện Biên',
      location: Geo(21.3860, 103.0167),
      status: WarehouseStatus.active,
      keywords: ['điện biên', 'dien bien'],
    ),
  ];

  // ===================================================================
  // RUNTIME LIST (có thể bị override bởi Firestore)
  // ===================================================================

  static List<Warehouse> _runtimeMainHubs = List<Warehouse>.from(kMainHubs);
  static List<Warehouse> _runtimeTransitWarehouses =
  List<Warehouse>.from(kTransitWarehouses);

  static List<Warehouse> get mainHubs =>
      List<Warehouse>.unmodifiable(_runtimeMainHubs);

  static List<Warehouse> get transitWarehouses =>
      List<Warehouse>.unmodifiable(_runtimeTransitWarehouses);

  /// Chỉ kho đang active
  static Iterable<Warehouse> get _activeMainHubs =>
      _runtimeMainHubs.where((w) => w.status.isActive);

  static Iterable<Warehouse> get _activeTransitWarehouses =>
      _runtimeTransitWarehouses.where((w) => w.status.isActive);

  /// Kho xuất phát mặc định (ưu tiên kho main đang active)
  static Warehouse get defaultWarehouse {
    final active = _activeMainHubs.toList();
    if (active.isNotEmpty) return active.first;
    if (_runtimeMainHubs.isNotEmpty) return _runtimeMainHubs.first;
    return kMainHubs.first;
  }

  /// 🔙 Getter cũ để không bị lỗi (dùng kho mặc định)
  static Geo get pos => defaultWarehouse.location;

  static double _deg2rad(double deg) => deg * math.pi / 180.0;

  /// Tính khoảng cách Haversine (km)
  static double _distanceKm(Geo a, Geo b) {
    const earthRadiusKm = 6371.0;
    final dLat = _deg2rad(b.latitude - a.latitude);
    final dLng = _deg2rad(b.longitude - a.longitude);

    final lat1 = _deg2rad(a.latitude);
    final lat2 = _deg2rad(b.latitude);

    final sinDLat = math.sin(dLat / 2);
    final sinDLng = math.sin(dLng / 2);

    final h = sinDLat * sinDLat +
        sinDLng * sinDLng * math.cos(lat1) * math.cos(lat2);
    final c = 2 * math.atan2(math.sqrt(h), math.sqrt(1 - h));
    return earthRadiusKm * c;
  }

  /// Public helper nếu cần xài ngoài class
  static double distanceKm(Geo a, Geo b) => _distanceKm(a, b);

  // ===================================================================
  // PICK KHO CHÍNH (MAIN HUB)
  // ===================================================================

  static Warehouse pickWarehouseFor({
    String? provinceText,
    double? destLat,
    double? destLng,
  }) {
    final hubs = _activeMainHubs.isNotEmpty
        ? _activeMainHubs.toList()
        : _runtimeMainHubs; // nếu tất cả paused thì vẫn dùng

    final raw = provinceText?.toLowerCase().trim();
    final text = (raw == null || raw.isEmpty) ? null : _normalize(raw);

    // 1️⃣ match text với main hubs (chỉ kho active)
    if (text != null && text.isNotEmpty) {
      for (final w in hubs) {
        for (final kw in w.keywords) {
          final kwNorm = _normalize(kw);
          if (text.contains(kwNorm)) {
            return w;
          }
        }
      }
    }

    // 2️⃣ nếu có toạ độ -> chọn main hub gần nhất (chỉ kho active)
    if (destLat != null && destLng != null) {
      final dest = Geo(destLat, destLng);
      Warehouse? best;
      double bestDist = double.infinity;

      for (final w in hubs) {
        final d = _distanceKm(dest, w.location);
        if (d < bestDist) {
          bestDist = d;
          best = w;
        }
      }
      if (best != null) return best;
    }

    // 3️⃣ fallback
    return defaultWarehouse;
  }

  /// Lấy toạ độ kho CHÍNH được chọn
  static Geo pickWarehousePos({
    String? provinceText,
    double? destLat,
    double? destLng,
  }) {
    final w = pickWarehouseFor(
      provinceText: provinceText,
      destLat: destLat,
      destLng: destLng,
    );
    return w.location;
  }

  // ===================================================================
  // PICK KHO TRUNG CHUYỂN THEO TỈNH
  // ===================================================================

  static Warehouse? pickTransitWarehouseFor({
    String? provinceText,
    double? destLat,
    double? destLng,
  }) {
    final hubs = _activeTransitWarehouses.isNotEmpty
        ? _activeTransitWarehouses.toList()
        : _runtimeTransitWarehouses;

    final raw = provinceText?.toLowerCase().trim();
    final text = (raw == null || raw.isEmpty) ? null : _normalize(raw);

    // 1️⃣ theo text
    if (text != null && text.isNotEmpty) {
      for (final w in hubs) {
        for (final kw in w.keywords) {
          final kwNorm = _normalize(kw);
          if (text.contains(kwNorm)) {
            return w;
          }
        }
      }
    }

    // 2️⃣ nếu có toạ độ -> chọn transit gần nhất
    if (destLat != null && destLng != null) {
      final dest = Geo(destLat, destLng);
      Warehouse? best;
      double bestDist = double.infinity;

      for (final w in hubs) {
        final d = _distanceKm(dest, w.location);
        if (d < bestDist) {
          bestDist = d;
          best = w;
        }
      }
      return best;
    }

    // 3️⃣ không tìm được -> không dùng kho trung chuyển
    return null;
  }

  /// ✅ Hàm cũ – tổng tất cả kho (main + transit)
  /// (bao gồm cả kho paused/closed – tuỳ màn hình bạn tự filter tiếp)
  static List<Warehouse> get kWarehouses =>
      List<Warehouse>.unmodifiable([...mainHubs, ...transitWarehouses]);

  // ===================================================================
  // 3. DÙNG CHO LỘ TRÌNH – WH → HUB TỈNH → CUS
  // ===================================================================

  static List<Map<String, dynamic>> buildDefaultLegsForOrder({
    // Kho xuất phát
    required double whLat,
    required double whLng,
    required String whCode,
    required String whName,

    // Điểm nhận
    required double toLat,
    required double toLng,
    required String? toProvince,
  }) {
    final whGeo = Geo(whLat, whLng);
    final cusGeo = Geo(toLat, toLng);

    // 🔹 Khoảng cách trực tiếp từ KHO → KHÁCH
    final distWhCus = _distanceKm(whGeo, cusGeo);
    final durWhCus = distWhCus; // demo: 1km ~ 1 phút

    // 🔹 Xem kho hiện tại có phải KHO CHÍNH không
    final bool isMainHub =
    mainHubs.any((w) => w.code == whCode && w.isMainHub);

    // ⭐ RULE:
    // Nếu là KHO CHÍNH và khoảng cách tới khách <= 50km
    // → GIAO THẲNG WH → KHÁCH, KHÔNG QUA HUB
    if (isMainHub && distWhCus <= kDirectShipMaxKm) {
      return [
        {
          'fromCode': 'WH',
          'fromLabel': whName,
          'fromLat': whLat,
          'fromLng': whLng,
          'toCode': 'CUS',
          'toLabel': 'Khách hàng',
          'toLat': cusGeo.latitude,
          'toLng': cusGeo.longitude,
          'distanceKm': distWhCus,
          'durationMin': durWhCus,
        },
      ];
    }

    // 🔹 Còn lại: chọn kho trung chuyển (ưu tiên kho active)
    final hub = pickTransitWarehouseFor(
      provinceText: toProvince,
      destLat: toLat,
      destLng: toLng,
    );

    // Nếu không có HUB -> 1 chặng WH → CUS
    if (hub == null) {
      return [
        {
          'fromCode': 'WH',
          'fromLabel': whName,
          'fromLat': whLat,
          'fromLng': whLng,
          'toCode': 'CUS',
          'toLabel': 'Khách hàng',
          'toLat': cusGeo.latitude,
          'toLng': cusGeo.longitude,
          'distanceKm': distWhCus,
          'durationMin': durWhCus,
        },
      ];
    }

    final hubGeo = hub.location;

    // 🔑 Code HUB lưu vào legs phải unique nhưng vẫn match logic contains('HUB')
    final hubLegCode = _hubLegCode(hub.code); // VD: HUB_GL, HUB_KH...

    final distWhHub = _distanceKm(whGeo, hubGeo);
    const sameWarehouseThresholdKm = 5.0;

    // Nếu kho xuất phát đã rất gần kho trung chuyển -> bỏ HUB
    if (distWhHub <= sameWarehouseThresholdKm) {
      return [
        {
          'fromCode': 'WH',
          'fromLabel': whName,
          'fromLat': whLat,
          'fromLng': whLng,
          'toCode': 'CUS',
          'toLabel': 'Khách hàng',
          'toLat': cusGeo.latitude,
          'toLng': cusGeo.longitude,
          'distanceKm': distWhCus,
          'durationMin': durWhCus,
        },
      ];
    }

    // Ngược lại: 2 chặng WH → HUB tỉnh → CUS
    final leg1Dist = distWhHub;
    final leg2Dist = _distanceKm(hubGeo, cusGeo);
    final leg1Min = leg1Dist;
    final leg2Min = leg2Dist;

    return [
      {
        'fromCode': 'WH',
        'fromLabel': whName,
        'fromLat': whLat,
        'fromLng': whLng,
        'toCode': hubLegCode, // ✅ HUB_GL / HUB_KH ...
        'toLabel': hub.name,
        'toLat': hubGeo.latitude,
        'toLng': hubGeo.longitude,
        'distanceKm': leg1Dist,
        'durationMin': leg1Min,
      },
      {
        'fromCode': hubLegCode, // ✅ HUB_GL / HUB_KH ...
        'fromLabel': hub.name,
        'fromLat': hubGeo.latitude,
        'fromLng': hubGeo.longitude,
        'toCode': 'CUS',
        'toLabel': 'Khách hàng',
        'toLat': cusGeo.latitude,
        'toLng': cusGeo.longitude,
        'distanceKm': leg2Dist,
        'durationMin': leg2Min,
      },
    ];
  }

  // ===================================================================
  // 4. FIRESTORE INTEGRATION
  // ===================================================================

  /// Load danh sách kho từ Firestore (collection "warehouses") nếu có.
  /// Nếu collection trống hoặc lỗi -> dùng list mặc định.
  static Future<void> loadFromFirestoreIfAny() async {
    try {
      final col = FirebaseFirestore.instance.collection('warehouses');
      final snap = await col.get();

      if (snap.docs.isEmpty) {
        _runtimeMainHubs = List<Warehouse>.from(kMainHubs);
        _runtimeTransitWarehouses = List<Warehouse>.from(kTransitWarehouses);
        if (kDebugMode) {
          debugPrint(
            '[WarehouseConfig] Firestore trống, dùng list mặc định.',
          );
        }
        return;
      }

      final mains = <Warehouse>[];
      final transits = <Warehouse>[];

      for (final d in snap.docs) {
        final data = d.data();
        final wh = Warehouse.fromMap(data);
        if (wh.isMainHub) {
          mains.add(wh);
        } else {
          transits.add(wh);
        }
      }

      _runtimeMainHubs = mains.isNotEmpty ? mains : List<Warehouse>.from(kMainHubs);
      _runtimeTransitWarehouses =
      transits.isNotEmpty ? transits : List<Warehouse>.from(kTransitWarehouses);

      if (kDebugMode) {
        debugPrint(
          '[WarehouseConfig] Loaded from Firestore: mainHubs=${_runtimeMainHubs.length}, transit=${_runtimeTransitWarehouses.length}',
        );
      }
    } catch (e) {
      _runtimeMainHubs = List<Warehouse>.from(kMainHubs);
      _runtimeTransitWarehouses = List<Warehouse>.from(kTransitWarehouses);
      if (kDebugMode) {
        debugPrint(
          '[WarehouseConfig] Lỗi load Firestore, dùng mặc định. $e',
        );
      }
    }
  }

  /// Seed kho mặc định vào Firestore nếu collection "warehouses" đang trống.
  static Future<void> seedToFirestoreIfEmpty() async {
    final col = FirebaseFirestore.instance.collection('warehouses');
    final snap = col.limit(1).get();
    final result = await snap;
    if (result.docs.isNotEmpty) {
      if (kDebugMode) {
        debugPrint('[WarehouseConfig] warehouses đã có data, không seed.');
      }
      return;
    }

    final batch = FirebaseFirestore.instance.batch();
    for (final wh in [...kMainHubs, ...kTransitWarehouses]) {
      final doc = col.doc(wh.code);
      batch.set(doc, wh.toMap());
    }
    await batch.commit();

    if (kDebugMode) {
      debugPrint(
        '[WarehouseConfig] Đã seed ${kMainHubs.length + kTransitWarehouses.length} kho vào Firestore.',
      );
    }
  }

  /// Helper: cập nhật trạng thái kho theo code (dùng cho nút "Tạm ngừng/Mở lại")
  static Future<void> updateWarehouseStatus(
      String code,
      WarehouseStatus status,
      ) async {
    final col = FirebaseFirestore.instance.collection('warehouses');
    await col.doc(code).update({
      'status': status.asString,
      'isActive': status.isActive, // giữ đồng bộ với code cũ
    });
  }
}
