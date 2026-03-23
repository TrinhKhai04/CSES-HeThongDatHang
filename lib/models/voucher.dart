import 'package:cloud_firestore/cloud_firestore.dart';

/// Voucher model (hỗ trợ millis hoặc Timestamp của Firestore).
class Voucher {
  final String id;
  final String code;

  /// true → discount là tỉ lệ (0.1 = 10%); false → số tiền VND
  final double discount;
  final bool isPercent;

  /// Tuỳ chọn điều kiện
  final double? minSubtotal;   // đơn tối thiểu
  final double? maxDiscount;   // trần giảm (khi isPercent)
  final int? startAt;          // millis
  final int? endAt;            // millis
  final bool active;           // bật/tắt nhanh (mặc định true)

  /// Giới hạn phát hành (null = vô hạn) & đã dùng
  final int? qtyLimit;         // tổng lượt phát hành
  final int usedCount;         // đã dùng bao nhiêu (mặc định 0)

  /// Giới hạn mỗi user (null = không giới hạn)
  final int? perUserLimit;

  final String? description;

  const Voucher({
    required this.id,
    required this.code,
    required this.discount,
    required this.isPercent,
    this.minSubtotal,
    this.maxDiscount,
    this.startAt,
    this.endAt,
    this.active = true,
    this.qtyLimit,
    this.usedCount = 0,
    this.perUserLimit,
    this.description,
  });

  factory Voucher.fromMap(Map<String, dynamic> map) {
    double _d(dynamic v) =>
        v is num ? v.toDouble() : double.tryParse('$v') ?? 0.0;

    int? _i(dynamic v) {
      if (v == null) return null;
      if (v is int) return v;
      if (v is Timestamp) return v.millisecondsSinceEpoch;
      return int.tryParse('$v');
    }

    bool _b(dynamic v) {
      if (v is bool) return v;
      if (v is num) return v != 0;
      final s = ('$v').toLowerCase();
      return s == 'true' || s == '1';
    }

    return Voucher(
      id: (map['id'] ?? '').toString(),
      code: (map['code'] ?? '').toString().toUpperCase(),
      discount: _d(map['discount']),
      isPercent: _b(map['isPercent']),
      minSubtotal: map['minSubtotal'] == null ? null : _d(map['minSubtotal']),
      maxDiscount: map['maxDiscount'] == null ? null : _d(map['maxDiscount']),
      startAt: _i(map['startAt']),
      endAt: _i(map['endAt']),
      active: _b(map['active'] ?? true),
      qtyLimit: _i(map['qtyLimit']),
      usedCount: _i(map['usedCount']) ?? 0,
      perUserLimit: _i(map['perUserLimit']),
      description: map['description'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'code': code.toUpperCase(),
    'discount': discount,
    'isPercent': isPercent,
    if (minSubtotal != null) 'minSubtotal': minSubtotal,
    if (maxDiscount != null) 'maxDiscount': maxDiscount,
    if (startAt != null) 'startAt': startAt,
    if (endAt != null) 'endAt': endAt,
    'active': active,
    if (qtyLimit != null) 'qtyLimit': qtyLimit,
    'usedCount': usedCount,
    if (perUserLimit != null) 'perUserLimit': perUserLimit,
    'description': description,
  };

  /// Đang hiệu lực ở thời điểm hiện tại?
  bool get isActiveNow {
    if (!active) return false;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (startAt != null && now < startAt!) return false;
    if (endAt != null && now > endAt!) return false;
    // kiểm tra đã hết lượt hay chưa
    if (qtyLimit != null && usedCount >= qtyLimit!) return false;
    return true;
  }

  /// Đơn có đủ điều kiện không (xét minSubtotal & thời gian & lượt)?
  bool isEligible({required double cartSubtotal}) {
    if (!isActiveNow) return false;
    if (minSubtotal != null && cartSubtotal < minSubtotal!) return false;
    return true;
  }

  /// Số tiền giảm cho subtotal (đã xét đủ điều kiện & trần giảm).
  double discountFor({required double cartSubtotal}) {
    if (!isEligible(cartSubtotal: cartSubtotal)) return 0.0;
    double d = isPercent ? cartSubtotal * discount : discount;
    if (isPercent && maxDiscount != null && d > maxDiscount!) d = maxDiscount!;
    if (d < 0) d = 0;
    if (d > cartSubtotal) d = cartSubtotal;
    return d;
  }

  /// Số lượt còn lại (null = vô hạn)
  int? get remaining {
    if (qtyLimit == null) return null;
    final r = qtyLimit! - usedCount;
    return r < 0 ? 0 : r;
  }

  /// User còn được dùng theo perUserLimit không? (truyền số lần user đã dùng)
  bool canUserUse(int timesUsedByUser) {
    if (perUserLimit == null) return true;
    return timesUsedByUser < perUserLimit!;
  }
}
