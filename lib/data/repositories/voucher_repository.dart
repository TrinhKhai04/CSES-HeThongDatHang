import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/voucher.dart';

/// Repository làm việc với collection vouchers trên Firestore.
/// - Hỗ trợ kiểm tra hiệu lực theo thời gian/active/giới hạn hệ thống
/// - Theo dõi lượt dùng theo từng user trong subcollection usages
/// - Cung cấp API lọc voucher *khả dụng cho 1 user + 1 giỏ hàng*
class VoucherRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  static const String _collection = 'vouchers';
  static const String _subUsages = 'usages'; // /vouchers/{id}/usages/{uid}

  /// Dùng withConverter để map data <-> Voucher. Giữ tương thích bằng cách
  /// merge id từ docId vào map (phòng model không có).
  CollectionReference<Voucher> get _col =>
      _db.collection(_collection).withConverter<Voucher>(
        fromFirestore: (snap, _) =>
            Voucher.fromMap({'id': snap.id, ...?snap.data()}),
        toFirestore: (v, _) => v.toMap(),
      );

  String _normalize(String code) => code.trim().toUpperCase();

  // ----------------- Helpers an toàn kiểu dữ liệu -----------------
  int _toInt(dynamic v, [int def = 0]) {
    if (v == null) return def;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse('$v') ?? def;
  }

  bool _toBool(dynamic v, [bool def = true]) {
    if (v == null) return def;
    if (v is bool) return v;
    if (v is num) return v != 0;
    final s = ('$v').toLowerCase();
    return s == 'true' || s == '1';
  }

  num? _toNum(dynamic v) {
    if (v == null) return null;
    if (v is num) return v;
    return num.tryParse('$v');
  }

  /// Kiểm tra 1 voucher có đang dùng được *ở thời điểm now* hay không,
  /// dựa vào: startAt/endAt, active, qtyLimit/usedCount.
  bool _isUsableNow(Voucher v, int now) {
    // Thời gian hiệu lực (millis since epoch)
    final sOK = v.startAt == null || now >= v.startAt!;
    final eOK = v.endAt == null || now <= v.endAt!;

    // Nếu model có field active → dùng; nếu không có thì mặc định true
    final aOK = _toBool((v as dynamic).active, true);

    // Giới hạn toàn hệ thống (qtyLimit - usedCount)
    final qty = (v as dynamic).qtyLimit;               // tổng lượt cho phép
    final used = _toInt((v as dynamic).usedCount, 0);  // đã dùng
    final qOK = qty == null || used < _toInt(qty);

    return sOK && eOK && aOK && qOK;
  }

  // ======================================================================
  // Truy vấn đơn lẻ
  // ======================================================================

  /// Lấy 1 voucher theo code (ưu tiên active == true) và còn hiệu lực.
  Future<Voucher?> getByCode(String code, {int? nowMillis}) async {
    if (code.trim().isEmpty) return null;
    final now = nowMillis ?? DateTime.now().millisecondsSinceEpoch;
    final upper = _normalize(code);

    // Ưu tiên doc có active = true
    var qs = await _col
        .where('code', isEqualTo: upper)
        .where('active', isEqualTo: true)
        .limit(5)
        .get();

    // Fallback: doc cũ chưa có field active
    if (qs.docs.isEmpty) {
      qs = await _col.where('code', isEqualTo: upper).limit(5).get();
    }
    if (qs.docs.isEmpty) return null;

    final candidates =
    qs.docs.map((d) => d.data()).where((v) => _isUsableNow(v, now)).toList();
    return candidates.isEmpty ? null : candidates.first;
  }

  Future<Voucher?> getById(String id) async {
    final snap = await _col.doc(id).get();
    return snap.exists ? snap.data() : null;
  }

  Future<void> upsert(Voucher voucher, {bool forceUppercaseCode = true}) async {
    final data = voucher.toMap();
    if (forceUppercaseCode && data['code'] is String) {
      data['code'] = (data['code'] as String).trim().toUpperCase();
    }
    await _db.collection(_collection).doc(voucher.id).set(
      data,
      SetOptions(merge: true),
    );
  }

  Future<void> delete(String id) async {
    await _db.collection(_collection).doc(id).delete();
  }

  Future<bool> codeExists(String code) async {
    final qs = await _col
        .where('code', isEqualTo: _normalize(code))
        .limit(1)
        .get();
    return qs.docs.isNotEmpty;
  }

  // ======================================================================
  // Danh sách / streams
  // ======================================================================

  /// Stream tất cả voucher đang còn hiệu lực (client-side filter).
  Stream<List<Voucher>> getActiveStream({int? nowMillis}) {
    final now = nowMillis ?? DateTime.now().millisecondsSinceEpoch;
    return _col.snapshots().map((s) {
      final list = s.docs.map((d) => d.data()).toList();
      return list.where((v) => _isUsableNow(v, now)).toList();
    });
  }

  /// Alias cho UI người dùng.
  Stream<List<Voucher>> getUserVisibleStream({int? nowMillis}) =>
      getActiveStream(nowMillis: nowMillis);

  /// Danh sách voucher còn hiệu lực (dùng cho gợi ý).
  Future<List<Voucher>> listActive({int? nowMillis, int limit = 200}) async {
    final now = nowMillis ?? DateTime.now().millisecondsSinceEpoch;
    final qs = await _col.limit(limit).get();
    final list = qs.docs.map((d) => d.data()).toList();
    return list.where((v) => _isUsableNow(v, now)).toList();
  }

  /// Lấy *tất cả* voucher (không lọc) — hữu ích cho debug/điều hành.
  Future<List<Voucher>> listAll({int limit = 500}) async {
    final qs = await _col.limit(limit).get();
    return qs.docs.map((d) => d.data()).toList();
  }

  /// Danh sách voucher KHẢ DỤNG cho *một user* ở thời điểm hiện tại và *một subtotal*.
  /// Ẩn các voucher đã hết lượt theo user (perUserLimit) hoặc không đạt minSubtotal.
  Future<List<Voucher>> listAvailableForUser({
    required String uid,
    required num subtotal,
    int? nowMillis,
    int limit = 200,
  }) async {
    final now = nowMillis ?? DateTime.now().millisecondsSinceEpoch;
    final qs = await _col.limit(limit).get();
    final out = <Voucher>[];

    for (final d in qs.docs) {
      final v = d.data();
      if (!_isUsableNow(v, now)) continue;

      // minSubtotal (nếu có)
      final minSubtotal = _toNum((v as dynamic).minSubtotal);
      if (minSubtotal != null && subtotal < minSubtotal) continue;

      // maxDiscount, isPercent… là phần áp dụng lúc tính tiền; ở đây không cần.

      // perUserLimit (ẩn nếu user đã dùng hết)
      final perUserLimit = _toNum((v as dynamic).perUserLimit);
      if (perUserLimit != null) {
        final used = await userUsedCount(voucherId: v.id, userId: uid);
        if (used >= perUserLimit) continue;
      }

      out.add(v);
    }
    return out;
  }

  // ======================================================================
  // Thống kê & kiểm tra giới hạn
  // ======================================================================

  /// Số lượt còn lại (null = vô hạn) ở cấp hệ thống.
  Future<int?> remainingCount(String voucherId) async {
    final v = await getById(voucherId);
    if (v == null) return null;
    final qty = (v as dynamic).qtyLimit;
    if (qty == null) return null;
    final used = _toInt((v as dynamic).usedCount, 0);
    final remain = _toInt(qty) - used;
    return remain < 0 ? 0 : remain;
  }

  /// Đếm số lần 1 user đã dùng mã này (từ subcollection /usages).
  Future<int> userUsedCount({
    required String voucherId,
    required String userId,
  }) async {
    final ref = _db
        .collection(_collection)
        .doc(voucherId)
        .collection(_subUsages)
        .doc(userId);
    final snap = await ref.get();
    if (!snap.exists) return 0;
    final data = snap.data();
    return _toInt(data?['count'], 0);
  }

  /// User còn được dùng theo perUserLimit?
  Future<bool> canUserUse({
    required Voucher voucher,
    required String userId,
  }) async {
    final limit = (voucher as dynamic).perUserLimit;
    if (limit == null) return true;
    final used = await userUsedCount(voucherId: voucher.id, userId: userId);
    return used < _toInt(limit);
  }

  // ======================================================================
  // Ghi nhận tiêu thụ lượt
  // ======================================================================

  /// Tăng usedCount (cấp hệ thống). Dùng khi không theo dõi theo user.
  /// Dùng transaction để tránh vượt qtyLimit.
  Future<void> consumeOne({required String voucherId}) async {
    final vRef = _db.collection(_collection).doc(voucherId);

    await _db.runTransaction((tx) async {
      final snap = await tx.get(vRef);
      if (!snap.exists) throw StateError('Voucher không tồn tại');

      final data = snap.data() as Map<String, dynamic>? ?? {};
      final active = _toBool(data['active'], true);
      final now = DateTime.now().millisecondsSinceEpoch;
      final startOK = data['startAt'] == null || now >= _toInt(data['startAt']);
      final endOK   = data['endAt']   == null || now <= _toInt(data['endAt']);
      if (!active || !startOK || !endOK) {
        throw StateError('Voucher không còn hiệu lực');
      }

      final qtyLimit = data['qtyLimit'];
      final usedCount = _toInt(data['usedCount'], 0);
      if (qtyLimit != null && usedCount >= _toInt(qtyLimit)) {
        throw StateError('Voucher đã hết lượt sử dụng');
      }

      tx.update(vRef, {'usedCount': FieldValue.increment(1)});
    });
  }

  /// Tiêu thụ 1 lượt *kèm* ghi nhận theo user (để giới hạn mỗi người).
  /// - Tăng `usedCount` của voucher
  /// - Tăng `count` trong `/vouchers/{id}/usages/{uid}`
  /// - Từ chối nếu vượt `qtyLimit` hoặc `perUserLimit`
  Future<void> consumeOneForUser({
    required String voucherId,
    required String userId,
  }) async {
    final vRef = _db.collection(_collection).doc(voucherId);
    final uRef = vRef.collection(_subUsages).doc(userId);

    await _db.runTransaction((tx) async {
      // 1) Đọc voucher
      final vSnap = await tx.get(vRef);
      if (!vSnap.exists) throw StateError('Voucher không tồn tại');

      final vData = vSnap.data() as Map<String, dynamic>? ?? {};
      final active = _toBool(vData['active'], true);
      final now = DateTime.now().millisecondsSinceEpoch;
      final startOK = vData['startAt'] == null || now >= _toInt(vData['startAt']);
      final endOK   = vData['endAt']   == null || now <= _toInt(vData['endAt']);
      if (!active || !startOK || !endOK) {
        throw StateError('Voucher không còn hiệu lực');
      }

      // Giới hạn hệ thống
      final qtyLimit  = vData['qtyLimit'];
      final usedCount = _toInt(vData['usedCount'], 0);
      if (qtyLimit != null && usedCount >= _toInt(qtyLimit)) {
        throw StateError('Voucher đã hết lượt sử dụng');
      }

      // 2) Đọc usage theo user
      final uSnap = await tx.get(uRef);
      final uData = uSnap.data() as Map<String, dynamic>? ?? {};
      final currentUserCount = _toInt(uData['count'], 0);

      // Giới hạn theo user
      final perUserLimit = vData['perUserLimit'];
      if (perUserLimit != null && currentUserCount >= _toInt(perUserLimit)) {
        throw StateError('Bạn đã dùng tối đa số lần cho mã này');
      }

      // 3) Cập nhật cả hai nơi
      tx.update(vRef, {'usedCount': FieldValue.increment(1)});
      if (uSnap.exists) {
        tx.update(uRef, {
          'count'    : FieldValue.increment(1),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        // FieldValue.increment trên field mới an toàn khi dùng merge:true
        tx.set(uRef, {
          'count'    : FieldValue.increment(1),
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    });
  }
}

/// (Tuỳ chọn) Migration một lần: thêm `active:true` & `usedCount:0`
/// cho các doc cũ chưa có 2 field này.
Future<void> migrateVouchersAddActiveTrue() async {
  final col = FirebaseFirestore.instance.collection('vouchers');
  final qs  = await col.get();
  for (final d in qs.docs) {
    final data = d.data();
    final patch = <String, dynamic>{};
    if (!data.containsKey('active'))    patch['active']    = true;
    if (!data.containsKey('usedCount')) patch['usedCount'] = 0;
    if (patch.isNotEmpty) {
      await d.reference.set(patch, SetOptions(merge: true));
    }
  }
}
