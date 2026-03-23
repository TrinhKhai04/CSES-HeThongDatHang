import 'package:cloud_firestore/cloud_firestore.dart';

/// 🆕 Một chặng vận chuyển giữa 2 điểm (kho / hub / khách)
///
/// Ví dụ:
///   WH (Kho HCM)  ➜  HUB (kho trung chuyển Đà Nẵng)
///   HUB (Đà Nẵng) ➜  CUS (Khách hàng ở Hà Nội)
class OrderRouteLeg {
  /// Code nguồn/đích (có thể là mã kho, hub, hoặc loại điểm: WH_MAIN, DN_MAIN,...)
  final String? fromCode; // trước đây: fromWhCode
  final String? toCode;   // trước đây: toWhCode

  final String fromLabel; // Text hiển thị: "Kho Hồ Chí Minh"
  final String toLabel;   // Text hiển thị: "Kho trung chuyển Đà Nẵng"

  final double fromLat;   // Toạ độ nguồn
  final double fromLng;
  final double toLat;     // Toạ độ đích
  final double toLng;

  final double distanceKm;  // Quãng đường chặng (km)
  final double durationMin; // Thời gian dự kiến (phút)

  const OrderRouteLeg({
    this.fromCode,
    this.toCode,
    required this.fromLabel,
    required this.toLabel,
    required this.fromLat,
    required this.fromLng,
    required this.toLat,
    required this.toLng,
    required this.distanceKm,
    required this.durationMin,
  });

  /// 🔁 Alias để tương thích code cũ:
  /// trong warehouse_admin_page.dart đang dùng `fromWhCode` / `toWhCode`
  String? get fromWhCode => fromCode;
  String? get toWhCode => toCode;

  /// Ghi ra Map để lưu Firestore
  Map<String, dynamic> toMap() => {
    // field mới
    if (fromCode != null) 'fromCode': fromCode,
    if (toCode != null) 'toCode': toCode,

    // alias cũ (giữ cho an toàn, nếu anh muốn có thể bỏ)
    if (fromCode != null) 'fromWhCode': fromCode,
    if (toCode != null) 'toWhCode': toCode,

    'fromLabel': fromLabel,
    'toLabel': toLabel,
    'fromLat': fromLat,
    'fromLng': fromLng,
    'toLat': toLat,
    'toLng': toLng,
    'distanceKm': distanceKm,
    'durationMin': durationMin,
  };

  /// Đọc 1 leg từ Map Firestore
  factory OrderRouteLeg.fromMap(Map<String, dynamic> m) {
    double _d(dynamic v) {
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v) ?? 0.0;
      return 0.0;
    }

    // đọc cả key mới và key cũ
    final rawFromCode = m['fromCode'] ?? m['fromWhCode'];
    final rawToCode = m['toCode'] ?? m['toWhCode'];

    return OrderRouteLeg(
      fromCode: rawFromCode?.toString(),
      toCode: rawToCode?.toString(),
      fromLabel: (m['fromLabel'] ?? '').toString(),
      toLabel: (m['toLabel'] ?? '').toString(),
      fromLat: _d(m['fromLat']),
      fromLng: _d(m['fromLng']),
      toLat: _d(m['toLat']),
      toLng: _d(m['toLng']),
      distanceKm: _d(m['distanceKm']),
      durationMin: _d(m['durationMin']),
    );
  }
}

/// Model đơn hàng chính
class AppOrder {
  // ====== BẮT BUỘC ======
  final String id;

  // 🆕 Mã đơn để user/admin copy & tra cứu
  ///
  /// Ví dụ: "CSES-3F9K2A"
  /// - Lưu trong field 'orderCode' trên Firestore
  /// - Luôn có (required)
  final String orderCode; // 🆕

  final String customerId;
  final double subtotal;
  final double discount;
  final double shipping;
  final double total;
  final String status;
  final Map<String, dynamic>? voucher;
  final Timestamp createdAt;
  final Timestamp updatedAt;

  // 🟡 Xu dùng như một loại voucher khác (Xu đã sử dụng)
  final int usedXu; // Số Xu đã dùng cho đơn
  final double xuDiscount; // Số tiền giảm tương ứng (VND)

  // 🟠 Xu thưởng (có thể nhận sau khi đánh giá)
  final int rewardCoins; // Số xu có thể nhận cho đơn này
  final bool coinsRewarded; // Đã cộng xu thưởng vào ví hay chưa

  // 🆕 Phương thức thanh toán
  // - paymentMethodKey: 'cod' | 'bank_transfer' | 'momo' ...
  // - paymentMethodName: Text hiển thị tại thời điểm đặt đơn
  final String? paymentMethodKey; // vd: 'cod'
  final String? paymentMethodName; // vd: 'Thanh toán khi nhận hàng (COD)'

  // ====== Thông tin hiển thị (dùng cho UI/timeline) ======
  final String? whName; // Tên kho xuất phát
  final String? toName; // Tên người nhận
  final String? toPhone; // Số ĐT người nhận
  final String? toEmail; // Email
  final String? shippingNote; // Ghi chú giao hàng

  // Địa chỉ tách chi tiết
  final String? toAddress; // Số nhà, tên đường (line1)
  final String? toWard; // Phường/xã
  final String? toDistrict; // Quận/huyện
  final String? toProvince; // Tỉnh/thành

  /// Mốc thời gian theo trạng thái (statusTs.pending / .shipping / .done ...)
  final Map<String, Timestamp>? statusTs;

  // 👇 thông tin phương thức vận chuyển
  final String? shippingMethodId;
  final String? shippingMethodName;
  final String? shippingMethodSubtitle;

  // ====== GIAO HÀNG / TUYẾN ĐƯỜNG ======
  final double? whLat;
  final double? whLng;
  final double? toLat;
  final double? toLng;

  /// Polyline dạng chuỗi (nếu dùng encode)
  final String? routePolyline;

  /// Danh sách toạ độ tuyến đường chi tiết [{lat,lng},...]
  final List<Map<String, double>>? routeCoords;

  /// Tổng quãng đường & thời gian của cả hành trình
  final double? routeDistanceKm;
  final double? routeDurationMin;

  // 🆕 Đa chặng logistics (kho → hub → khách...)
  final List<OrderRouteLeg>? legs;

  const AppOrder({
    // bắt buộc
    required this.id,

    // 🆕 orderCode
    required this.orderCode,

    required this.customerId,
    required this.subtotal,
    required this.discount,
    required this.shipping,
    required this.total,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.voucher,

    // 🟡 Xu đã dùng
    this.usedXu = 0,
    this.xuDiscount = 0.0,

    // 🟠 Xu thưởng
    this.rewardCoins = 0,
    this.coinsRewarded = false,

    // 🆕 payment
    this.paymentMethodKey,
    this.paymentMethodName,

    // hiển thị
    this.whName,
    this.toName,
    this.toPhone,
    this.toEmail,
    this.shippingNote,
    this.toAddress,
    this.toWard,
    this.toDistrict,
    this.toProvince,
    this.statusTs,

    // shipping method
    this.shippingMethodId,
    this.shippingMethodName,
    this.shippingMethodSubtitle,

    // giao hàng
    this.whLat,
    this.whLng,
    this.toLat,
    this.toLng,
    this.routePolyline,
    this.routeCoords,
    this.routeDistanceKm,
    this.routeDurationMin,

    // 🆕 legs
    this.legs,
  });

  // ---------------- Helpers ép/chuẩn hoá ----------------

  /// Convert dynamic → double?
  static double? _toD(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  /// Convert dynamic → int
  static int _toI(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  /// Convert dynamic → String? (trim, rỗng => null)
  static String? _toS(dynamic v) {
    if (v == null) return null;
    if (v is String) {
      final s = v.trim();
      return s.isEmpty ? null : s;
    }
    final s = v.toString().trim();
    return s.isEmpty ? null : s;
  }

  /// Convert dynamic → Timestamp?
  static Timestamp? _toTs(dynamic v) {
    if (v == null) return null;
    if (v is Timestamp) return v;
    if (v is int) return Timestamp.fromMillisecondsSinceEpoch(v);
    if (v is String) {
      try {
        final dt = DateTime.parse(v);
        return Timestamp.fromDate(dt);
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  /// Lấy string đầu tiên khác null trong list key
  static String? _pickStr(Map map, List<String> keys) {
    for (final k in keys) {
      if (map.containsKey(k)) {
        final s = _toS(map[k]);
        if (s != null) return s;
      }
    }
    return null;
  }

  /// Chuẩn hoá lat (xử lý trường hợp lưu micro-degree 1e6)
  static double? _normLat(double? lat) {
    if (lat == null) return null;
    var x = lat;
    if (x.abs() > 180) x = x / 1e6; // 106000000 -> 106.0
    if (x.abs() > 90) return null;
    return x;
  }

  /// Chuẩn hoá lng (xử lý trường hợp lưu micro-degree 1e6)
  static double? _normLng(double? lng) {
    if (lng == null) return null;
    var x = lng;
    if (x.abs() > 360) x = x / 1e6;
    if (x.abs() > 180) return null;
    return x;
  }

  // ---------------- Factory/Map ----------------

  /// Tạo từ DocumentSnapshot Firestore
  factory AppOrder.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return AppOrder.fromMap({
      ...data,
      'id': doc.id,
    });
  }

  /// Tạo từ Map Firestore / JSON (cực kỳ phòng thủ)
  factory AppOrder.fromMap(Map<String, dynamic> map) {
    try {
      // routeCoords
      List<Map<String, double>>? rc;
      final rawRc = map['routeCoords'];
      if (rawRc is List) {
        final tmp = <Map<String, double>>[];
        for (final e in rawRc) {
          if (e is Map) {
            final m = Map<String, dynamic>.from(e);
            final lat = _toD(m['lat']);
            final lng = _toD(m['lng']);
            if (lat == null || lng == null) continue;
            final nlat = _normLat(lat);
            final nlng = _normLng(lng);
            if (nlat == null || nlng == null) continue;
            tmp.add({'lat': nlat, 'lng': nlng});
          }
        }
        if (tmp.isNotEmpty) rc = tmp;
      }

      // statusTs
      Map<String, Timestamp>? sts;
      if (map['statusTs'] is Map) {
        final m = Map<String, dynamic>.from(map['statusTs']);
        final tmp = <String, Timestamp>{};
        m.forEach((key, val) {
          final ts = _toTs(val);
          if (ts != null) tmp[key] = ts;
        });
        if (tmp.isNotEmpty) sts = tmp;
      }

      // 🆕 legs (đa chặng) - hỗ trợ 'legs' và alias 'routeLegs'
      List<OrderRouteLeg>? legs;
      final rawLegs = map['legs'] ?? map['routeLegs'];
      if (rawLegs is List) {
        final tmp = <OrderRouteLeg>[];
        for (final e in rawLegs) {
          if (e is Map) {
            tmp.add(
              OrderRouteLeg.fromMap(
                Map<String, dynamic>.from(e),
              ),
            );
          }
        }
        if (tmp.isNotEmpty) legs = tmp;
      }

      // Địa chỉ chi tiết
      String? toAddress;
      String? toWard;
      String? toDistrict;
      String? toProvince;

      final rawAddr =
          map['toAddress'] ?? map['address'] ?? map['shippingAddress'];

      if (rawAddr is Map) {
        final addr = Map<String, dynamic>.from(rawAddr);
        toAddress = _toS(addr['line1'] ?? addr['address'] ?? addr['street']);
        toWard = _toS(addr['ward'] ?? addr['wardName']);
        toDistrict = _toS(addr['district'] ?? addr['districtName']);
        toProvince =
            _toS(addr['province'] ?? addr['city'] ?? addr['provinceName']);
      } else {
        toAddress = _toS(rawAddr);
        toWard = _toS(map['toWard']);
        toDistrict = _toS(map['toDistrict']);
        toProvince = _toS(map['toProvince']);
      }

      // 🆕 xử lý id + orderCode
      final id = (map['id'] ?? '').toString();

      // ưu tiên lấy từ 'orderCode' trên Firestore, hoặc các alias khác
      String? rawCode =
      _toS(map['orderCode'] ?? map['code'] ?? map['orderId'] ?? map['order_no']);

      // fallback: tự tạo code từ id nếu chưa có
      String code = rawCode ?? '';
      if (code.isEmpty && id.isNotEmpty) {
        final suffix = id.length <= 6 ? id : id.substring(id.length - 6);
        code = 'CSES-$suffix'.toUpperCase();
      }

      return AppOrder(
        id: id,
        orderCode: code,

        customerId: (map['customerId'] ?? '').toString(),
        subtotal: _toD(map['subtotal']) ?? 0.0,
        discount: _toD(map['discount']) ?? 0.0,
        shipping: _toD(map['shipping']) ?? 0.0,
        total: _toD(map['total']) ?? 0.0,
        status: (map['status'] ?? 'pending').toString(),
        voucher: (map['voucher'] is Map)
            ? Map<String, dynamic>.from(map['voucher'] as Map)
            : null,
        createdAt: _toTs(map['createdAt']) ?? Timestamp.now(),
        updatedAt: _toTs(map['updatedAt']) ?? Timestamp.now(),

        // 🟡 Xu đã dùng
        usedXu: _toI(map['usedXu']),
        xuDiscount: _toD(map['xuDiscount']) ?? 0.0,

        // 🟠 Xu thưởng
        rewardCoins: _toI(map['rewardCoins']),
        coinsRewarded: map['coinsRewarded'] == true,

        // 🆕 payment
        paymentMethodKey:
        _toS(map['paymentMethodKey'] ?? map['payMethodKey']),
        paymentMethodName:
        _toS(map['paymentMethodName'] ?? map['payMethodName']),

        // hiển thị (alias nhiều key khác nhau)
        whName: _pickStr(
            map, ['whName', 'warehouseName', 'fromName', 'from_name']),
        toName: _pickStr(map, [
          'toName',
          'recipientName',
          'receiverName',
          'customerName',
          'name'
        ]),
        toPhone: _pickStr(
            map, ['toPhone', 'recipientPhone', 'phone', 'customerPhone']),
        toEmail:
        _pickStr(map, ['toEmail', 'email', 'customerEmail', 'receiverEmail']),
        shippingNote: _toS(map['shippingNote'] ??
            map['note'] ??
            map['orderNote'] ??
            map['shipping_note']),
        toAddress: toAddress,
        toWard: toWard,
        toDistrict: toDistrict,
        toProvince: toProvince,
        statusTs: sts,

        // shipping method
        shippingMethodId:
        _toS(map['shippingMethodId'] ?? map['shipMethodId']),
        shippingMethodName:
        _toS(map['shippingMethodName'] ?? map['shipMethodName']),
        shippingMethodSubtitle:
        _toS(map['shippingMethodSubtitle'] ?? map['shipMethodSubtitle']),

        // giao hàng
        whLat: _normLat(_toD(map['whLat'])),
        whLng: _normLng(_toD(map['whLng'])),
        toLat: _normLat(_toD(map['toLat'])),
        toLng: _normLng(_toD(map['toLng'])),
        routePolyline: map['routePolyline']?.toString(),
        routeCoords: rc,
        routeDistanceKm: _toD(map['routeDistanceKm']),
        routeDurationMin: _toD(map['routeDurationMin']),

        // 🆕 legs
        legs: legs,
      );
    } catch (e, st) {
      // backup cực an toàn: nếu có lỗi parse thì vẫn trả về AppOrder tối thiểu
      // ignore: avoid_print
      print('❌ AppOrder.fromMap error: $e\n$st');

      final id = (map['id'] ?? '').toString();
      String code = _toS(map['orderCode']) ?? '';
      if (code.isEmpty && id.isNotEmpty) {
        final suffix = id.length <= 6 ? id : id.substring(id.length - 6);
        code = 'CSES-$suffix'.toUpperCase();
      }

      return AppOrder(
        id: id,
        orderCode: code.isEmpty ? 'CSES-UNKNOWN' : code,
        customerId: (map['customerId'] ?? '').toString(),
        subtotal: 0,
        discount: 0,
        shipping: 0,
        total: 0,
        status: (map['status'] ?? 'pending').toString(),
        createdAt: Timestamp.now(),
        updatedAt: Timestamp.now(),
      );
    }
  }

  /// Ghi order ra Map để lưu Firestore
  Map<String, dynamic> toMap() {
    final data = <String, dynamic>{
      'id': id,

      // 🆕 lưu mã đơn
      'orderCode': orderCode,

      'customerId': customerId,
      'subtotal': subtotal,
      'discount': discount,
      'shipping': shipping,
      'total': total,
      'status': status,
      'voucher': voucher,
      'createdAt': createdAt,
      'updatedAt': updatedAt,

      // 🟡 Xu đã dùng
      'usedXu': usedXu,
      'xuDiscount': xuDiscount,

      // 🟠 Xu thưởng
      'rewardCoins': rewardCoins,
      'coinsRewarded': coinsRewarded,

      // 🆕 payment
      if (paymentMethodKey != null) 'paymentMethodKey': paymentMethodKey,
      if (paymentMethodName != null) 'paymentMethodName': paymentMethodName,

      // hiển thị
      if (whName != null) 'whName': whName,
      if (toName != null) 'toName': toName,
      if (toPhone != null) 'toPhone': toPhone,
      if (toEmail != null) 'toEmail': toEmail,
      if (shippingNote != null) 'shippingNote': shippingNote,
      if (toAddress != null) 'toAddress': toAddress,
      if (toWard != null) 'toWard': toWard,
      if (toDistrict != null) 'toDistrict': toDistrict,
      if (toProvince != null) 'toProvince': toProvince,
      if (statusTs != null) 'statusTs': statusTs,

      // shipping method
      if (shippingMethodId != null) 'shippingMethodId': shippingMethodId,
      if (shippingMethodName != null) 'shippingMethodName': shippingMethodName,
      if (shippingMethodSubtitle != null)
        'shippingMethodSubtitle': shippingMethodSubtitle,

      // giao hàng
      if (whLat != null) 'whLat': whLat,
      if (whLng != null) 'whLng': whLng,
      if (toLat != null) 'toLat': toLat,
      if (toLng != null) 'toLng': toLng,
      if (routePolyline != null && routePolyline!.isNotEmpty)
        'routePolyline': routePolyline,
      if (routeCoords != null && routeCoords!.isNotEmpty)
        'routeCoords':
        routeCoords!.map((e) => {'lat': e['lat'], 'lng': e['lng']}).toList(),
      if (routeDistanceKm != null) 'routeDistanceKm': routeDistanceKm,
      if (routeDurationMin != null) 'routeDurationMin': routeDurationMin,
    };

    // 🆕 legs (chỉ lưu tên mới 'legs'; vẫn đọc được key cũ 'routeLegs' ở fromMap)
    if (legs != null && legs!.isNotEmpty) {
      data['legs'] = legs!.map((e) => e.toMap()).toList();

      // 🆕 Build tập mã kho/hub xuất hiện trong các leg để query luồng đơn
      final whCodes = <String>{};
      for (final leg in legs!) {
        final fc = leg.fromCode ?? leg.fromWhCode;
        final tc = leg.toCode ?? leg.toWhCode;
        if (fc != null && fc.isNotEmpty) whCodes.add(fc);
        if (tc != null && tc.isNotEmpty) whCodes.add(tc);
      }
      if (whCodes.isNotEmpty) {
        data['legWhCodes'] = whCodes.toList();
      }
    }

    return data;
  }

  /// Tạo bản copy mới với một số field thay đổi
  AppOrder copyWith({
    String? id,

    // 🆕 orderCode
    String? orderCode,

    String? customerId,
    double? subtotal,
    double? discount,
    double? shipping,
    double? total,
    String? status,
    Map<String, dynamic>? voucher,
    Timestamp? createdAt,
    Timestamp? updatedAt,

    // 🟡 Xu đã dùng
    int? usedXu,
    double? xuDiscount,

    // 🟠 Xu thưởng
    int? rewardCoins,
    bool? coinsRewarded,

    // 🆕 payment
    String? paymentMethodKey,
    String? paymentMethodName,

    // hiển thị
    String? whName,
    String? toName,
    String? toPhone,
    String? toEmail,
    String? shippingNote,
    String? toAddress,
    String? toWard,
    String? toDistrict,
    String? toProvince,
    Map<String, Timestamp>? statusTs,

    // shipping method
    String? shippingMethodId,
    String? shippingMethodName,
    String? shippingMethodSubtitle,

    // giao hàng
    double? whLat,
    double? whLng,
    double? toLat,
    double? toLng,
    String? routePolyline,
    List<Map<String, double>>? routeCoords,
    double? routeDistanceKm,
    double? routeDurationMin,

    // 🆕 legs
    List<OrderRouteLeg>? legs,
  }) {
    return AppOrder(
      id: id ?? this.id,
      orderCode: orderCode ?? this.orderCode, // 🆕

      customerId: customerId ?? this.customerId,
      subtotal: subtotal ?? this.subtotal,
      discount: discount ?? this.discount,
      shipping: shipping ?? this.shipping,
      total: total ?? this.total,
      status: status ?? this.status,
      voucher: voucher ?? this.voucher,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,

      // 🟡 Xu đã dùng
      usedXu: usedXu ?? this.usedXu,
      xuDiscount: xuDiscount ?? this.xuDiscount,

      // 🟠 Xu thưởng
      rewardCoins: rewardCoins ?? this.rewardCoins,
      coinsRewarded: coinsRewarded ?? this.coinsRewarded,

      // 🆕 payment
      paymentMethodKey: paymentMethodKey ?? this.paymentMethodKey,
      paymentMethodName: paymentMethodName ?? this.paymentMethodName,

      // hiển thị
      whName: whName ?? this.whName,
      toName: toName ?? this.toName,
      toPhone: toPhone ?? this.toPhone,
      toEmail: toEmail ?? this.toEmail,
      shippingNote: shippingNote ?? this.shippingNote,
      toAddress: toAddress ?? this.toAddress,
      toWard: toWard ?? this.toWard,
      toDistrict: toDistrict ?? this.toDistrict,
      toProvince: toProvince ?? this.toProvince,
      statusTs: statusTs ?? this.statusTs,

      // shipping method
      shippingMethodId: shippingMethodId ?? this.shippingMethodId,
      shippingMethodName: shippingMethodName ?? this.shippingMethodName,
      shippingMethodSubtitle:
      shippingMethodSubtitle ?? this.shippingMethodSubtitle,

      // giao hàng
      whLat: whLat ?? this.whLat,
      whLng: whLng ?? this.whLng,
      toLat: toLat ?? this.toLat,
      toLng: toLng ?? this.toLng,
      routePolyline: routePolyline ?? this.routePolyline,
      routeCoords: routeCoords ?? this.routeCoords,
      routeDistanceKm: routeDistanceKm ?? this.routeDistanceKm,
      routeDurationMin: routeDurationMin ?? this.routeDurationMin,

      // 🆕 legs
      legs: legs ?? this.legs,
    );
  }

  // ================== GETTER PHỤC VỤ UI ==================

  /// Gộp lại địa chỉ đầy đủ (dùng cho hiển thị)
  String get fullToAddress {
    final parts = <String>[];

    void add(String? v) {
      if (v == null) return;
      final s = v.trim();
      if (s.isNotEmpty) parts.add(s);
    }

    add(toAddress);
    add(toWard);
    add(toDistrict);
    add(toProvince);

    return parts.join(', ');
  }

  /// Tóm tắt khách hàng: Tên • SĐT • Địa chỉ
  String get customerSummary {
    final parts = <String>[];

    if (toName != null && toName!.trim().isNotEmpty) {
      parts.add(toName!.trim());
    }
    if (toPhone != null && toPhone!.trim().isNotEmpty) {
      parts.add(toPhone!.trim());
    }
    final addr = fullToAddress;
    if (addr.isNotEmpty) {
      parts.add(addr);
    }

    return parts.join(' • ');
  }

  /// Hiển thị phương thức vận chuyển
  String get shippingMethodDisplay {
    final name = shippingMethodName ?? 'Tiêu chuẩn';
    final eta = shippingMethodSubtitle?.trim();
    if (eta == null || eta.isEmpty) return name;
    return '$name • $eta';
  }

  /// 🆕 Text hiển thị phương thức thanh toán trong UI
  String get paymentMethodDisplay {
    return paymentMethodName ??
        (paymentMethodKey == 'bank_transfer'
            ? 'Chuyển khoản ngân hàng'
            : paymentMethodKey == 'momo'
            ? 'Ví MoMo'
            : 'Thanh toán khi nhận hàng (COD)');
  }

  /// 🆕 Lấy leg đầu tiên (ví dụ để lấy kho/hub đầu tiên hiển thị)
  OrderRouteLeg? get firstLeg =>
      legs != null && legs!.isNotEmpty ? legs!.first : null;

  /// 🆕 Chuỗi mô tả lộ trình: "Kho xuất phát → Kho trung chuyển ... → Khách hàng"
  ///
  /// Dùng được ở nhiều chỗ: chip "Lộ trình" trong màn route, mô tả timeline,...
  String get legsRouteSummary {
    final ls = legs ?? const <OrderRouteLeg>[];
    if (ls.isEmpty) {
      // fallback: từ whName -> Khách hàng
      final labels = <String>[];
      if (whName != null && whName!.trim().isNotEmpty) {
        labels.add(whName!.trim());
      }
      labels.add('Khách hàng');
      return labels.join(' → ');
    }

    final labels = <String>[];

    // Điểm đầu tiên: fromLabel của leg đầu
    final firstFrom = ls.first.fromLabel.trim();
    if (firstFrom.isNotEmpty) labels.add(firstFrom);

    // Các điểm còn lại: toLabel của từng leg
    for (final l in ls) {
      final to = l.toLabel.trim();
      if (to.isNotEmpty && (labels.isEmpty || labels.last != to)) {
        labels.add(to);
      }
    }

    return labels.join(' → ');
  }
}
