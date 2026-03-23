import 'dart:async';
import 'dart:collection';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/product.dart';
import '../models/voucher.dart';
import '../data/repositories/voucher_repository.dart';

class CartItemVM {
  final String key; // productId#variantId#size#color
  final Product product;
  int qty;
  final double unitPrice;
  final Map<String, dynamic>? options;

  CartItemVM({
    required this.key,
    required this.product,
    required this.qty,
    required this.unitPrice,
    this.options,
  });

  String? get variantId => options?['variantId'] as String?;

  Map<String, dynamic> toJson() => {
    'productId': product.id,
    'name': product.name,
    'imageUrl': (product as dynamic).imageUrl,
    'qty': qty,
    'unitPrice': unitPrice,
    'price': unitPrice,
    if (options != null) 'options': options,
  };
}

class CartController extends ChangeNotifier {
  // ----------------------- STATE -----------------------
  final Map<String, CartItemVM> _items = {};
  UnmodifiableListView<CartItemVM> get items =>
      UnmodifiableListView(_items.values);

  // 🆕: danh sách key item đang được chọn để thanh toán
  final Set<String> _selectedKeys = {};
  UnmodifiableSetView<String> get selectedKeys =>
      UnmodifiableSetView(_selectedKeys);

  // Tổng của toàn bộ giỏ (không phân biệt chọn / không chọn)
  double get subtotal =>
      _items.values.fold<double>(0.0, (s, e) => s + e.unitPrice * e.qty);

  // 🆕 tổng chỉ của các item được chọn
  double get selectedSubtotal => _items.entries
      .where((e) => _selectedKeys.contains(e.key))
      .fold<double>(0.0, (s, e) => s + e.value.unitPrice * e.value.qty);

  // 🆕 một số helper cho UI
  int get selectedCount => _selectedKeys.length;
  bool get isAllSelected =>
      _items.isNotEmpty && _selectedKeys.length == _items.length;
  bool get hasSelection => _selectedKeys.isNotEmpty;

  // --------------------- SHIPPING ----------------------
  double _shippingFee = 0.0;
  double get shippingFee => _shippingFee;

  /// Hàm mới “chuẩn tên”
  void setShippingFee(double fee) {
    _shippingFee = fee < 0 ? 0.0 : fee;
    notifyListeners();
    _scheduleSave();
  }

  /// Alias để không bị lỗi nếu chỗ khác vẫn gọi setShipping()
  void setShipping(double fee) => setShippingFee(fee);

  // ---------------------- XU (COIN) --------------------
  int _usedXu = 0; // số Xu user chọn dùng cho đơn hiện tại
  double _xuDiscount = 0.0; // số tiền tương ứng được trừ

  int get usedXu => _usedXu;
  double get xuDiscount => _xuDiscount;

  /// Áp dụng Xu (UI gọi khi user gạt switch / chọn số Xu)
  void applyXu({required int used, required double discount}) {
    _usedXu = used < 0 ? 0 : used;
    _xuDiscount = discount < 0 ? 0.0 : discount;
    notifyListeners();
    _scheduleSave();
  }

  /// Xoá toàn bộ Xu đã áp dụng
  void clearXu() {
    if (_usedXu == 0 && _xuDiscount == 0.0) return;
    _usedXu = 0;
    _xuDiscount = 0.0;
    notifyListeners();
    _scheduleSave();
  }

  // ---------------------- VOUCHER ----------------------
  Voucher? _applied;
  String? _voucherError;
  Voucher? get appliedVoucher => _applied;
  String? get voucherError => _voucherError;

  Map<String, dynamic>? get voucherSnapshot => _applied == null
      ? null
      : {
    'id': _applied!.id,
    'code': _applied!.code,
    'isPercent': _applied!.isPercent,
    'discount': _applied!.discount,
    if (_applied!.minSubtotal != null)
      'minSubtotal': _applied!.minSubtotal,
    if (_applied!.maxDiscount != null)
      'maxDiscount': _applied!.maxDiscount,
  };

  double get discountAmount => _calcDiscountAmount();

  // 🆕 tổng tiền thanh toán chỉ cho item đã chọn
  double get total {
    // total = selectedSubtotal + shippingFee - discount(voucher) - xuDiscount
    final t = selectedSubtotal + shippingFee - discountAmount - _xuDiscount;
    return t < 0 ? 0.0 : t;
  }

  // -------------------- FIRESTORE META -----------------
  final _db = FirebaseFirestore.instance;
  String? _uid;
  Timer? _deb;
  bool _muteSave = false;

  DocumentReference<Map<String, dynamic>>? get _cartDoc =>
      _uid == null ? null : _db.doc('users/$_uid/cart/cart');

  // ----------------------- HELPERS ---------------------
  String _makeKey(String productId,
      {String? variantId, String? size, String? color}) =>
      [productId, variantId ?? '', size ?? '', color ?? ''].join('#');

  List<String> _splitKey(String key) {
    final parts = key.split('#');
    while (parts.length < 4) parts.add('');
    return parts;
  }

  void _resetInMemory({bool notify = true}) {
    _items.clear();
    _selectedKeys.clear(); // 🆕 clear luôn selection
    _applied = null;
    _voucherError = null;
    _shippingFee = 0.0;
    _usedXu = 0;
    _xuDiscount = 0.0;
    if (notify) notifyListeners();
  }

  int quantityOfVariant(String? variantId) {
    if (variantId == null || variantId.isEmpty) return 0;
    int sum = 0;
    for (final e in _items.entries) {
      if (e.value.variantId == variantId) sum += e.value.qty;
    }
    return sum;
  }

  int maxQtyCanAdd({required int stock, String? variantId}) {
    final have = quantityOfVariant(variantId);
    final remain = stock - have;
    return remain > 0 ? remain : 0;
  }

  // --------------------- SELECTION OPS -----------------
  // Toggle chọn một item
  void toggleItemSelected(String key, {bool? selected}) {
    if (!_items.containsKey(key)) return;
    final shouldSelect = selected ?? !_selectedKeys.contains(key);
    if (shouldSelect) {
      _selectedKeys.add(key);
    } else {
      _selectedKeys.remove(key);
    }
    notifyListeners();
  }

  // Chọn / bỏ chọn tất cả
  void toggleSelectAll({bool? selected}) {
    final shouldSelectAll = selected ?? !isAllSelected;
    _selectedKeys.clear();
    if (shouldSelectAll) {
      _selectedKeys.addAll(_items.keys);
    }
    notifyListeners();
  }

  // -------------------- AUTH LIFECYCLE -----------------
  Future<void> attachToUser(String uid) async {
    if (_uid == uid) {
      await _loadFromCloud();
      return;
    }
    _deb?.cancel();
    _muteSave = true;
    _uid = uid;
    await _loadFromCloud();
    _muteSave = false;
  }

  Future<void> detach() async {
    _deb?.cancel();
    _muteSave = true;
    _uid = null;
    _resetInMemory(notify: true);
    _muteSave = false;
  }

  // ---------------------- CLOUD SYNC -------------------
  Future<void> _loadFromCloud() async {
    final ref = _cartDoc;
    if (ref == null) return;

    final snap = await ref.get();
    _items.clear();
    _selectedKeys.clear();
    _applied = null;
    _voucherError = null;
    _shippingFee = 0.0;
    _usedXu = 0;
    _xuDiscount = 0.0;

    if (snap.exists) {
      final data = snap.data()!;
      final raw = (data['items'] as Map?)?.cast<String, dynamic>() ?? {};

      raw.forEach((key, v) {
        final m = (v as Map).cast<String, dynamic>();
        final productId = (m['productId'] as String?) ?? key.split('#').first;

        final product = Product(
          id: productId,
          name: (m['name'] ?? '') as String,
          price: ((m['unitPrice'] ?? m['price'] ?? 0) as num).toDouble(),
          imageUrl: m['imageUrl'],
        );

        _items[key] = CartItemVM(
          key: key,
          product: product,
          qty: (m['qty'] ?? 1) as int,
          unitPrice: ((m['unitPrice'] ?? m['price'] ?? 0) as num).toDouble(),
          options: (m['options'] is Map)
              ? (m['options'] as Map).cast<String, dynamic>()
              : null,
        );
      });

      // Mặc định: chọn tất cả item trong giỏ khi load
      _selectedKeys.addAll(_items.keys);

      // đọc lại phí ship từ cloud (nếu có)
      _shippingFee = (data['shippingFee'] is num)
          ? (data['shippingFee'] as num).toDouble()
          : 0.0;

      // đọc Xu từ cloud (nếu có)
      _usedXu = (data['usedXu'] as num?)?.toInt() ?? 0;
      _xuDiscount =
          (data['xuDiscount'] as num?)?.toDouble() ?? 0.0;
    }

    notifyListeners();
  }

  void _scheduleSave() {
    final uidSnapshot = _uid;
    if (uidSnapshot == null || _muteSave) return;

    _deb?.cancel();
    _deb = Timer(const Duration(milliseconds: 400), () {
      if (_muteSave || _uid != uidSnapshot) return;
      _saveToCloudFor(uidSnapshot);
    });
  }

  Future<void> _saveToCloudFor(String uid) async {
    final ref = _db.doc('users/$uid/cart/cart');
    final payload = {
      'uid': uid,
      'items': _items.map((k, v) => MapEntry(k, v.toJson())),
      'shippingFee': _shippingFee,
      'usedXu': _usedXu,
      'xuDiscount': _xuDiscount,
      'updatedAt': FieldValue.serverTimestamp(),
      // Nếu muốn lưu selection lên cloud thì thêm field riêng ở đây
    };
    await ref.set(payload, SetOptions(merge: true));
  }

  // ------------------- PUBLIC OPS -------------------
  void add(Product p, {int qty = 1}) {
    addCustomized(product: p, qty: qty, price: (p.price as num).toDouble());
  }

  void addCustomized({
    required Product product,
    int qty = 1,
    required double price,
    String? variantId,
    Map<String, dynamic>? options,
    int? stock,
  }) {
    if (qty <= 0) return;

    if (stock != null) {
      final remain = maxQtyCanAdd(stock: stock, variantId: variantId);
      if (remain <= 0) {
        if (kDebugMode) {
          print('⛔ Không thể thêm: đã đạt tối đa tồn kho (variant=$variantId)');
        }
        return;
      }
      qty = qty.clamp(1, remain);
    }

    final key = _makeKey(
      product.id,
      variantId: variantId,
      size: options?['size'] as String?,
      color: options?['color'] as String?,
    );

    final existed = _items[key];
    if (existed != null) {
      existed.qty += qty;
    } else {
      _items[key] = CartItemVM(
        key: key,
        product: product,
        qty: qty,
        unitPrice: price,
        options: {
          if (variantId != null) 'variantId': variantId,
          ...?options,
        },
      );
      // item mới thêm -> mặc định được chọn
      _selectedKeys.add(key);
    }
    notifyListeners();
    _scheduleSave();
  }

  void increment(String key, {int step = 1}) {
    final it = _items[key];
    if (it == null || step <= 0) return;
    it.qty += step;
    notifyListeners();
    _scheduleSave();
  }

  void decrement(String key, {int step = 1}) {
    final it = _items[key];
    if (it == null || step <= 0) return;
    it.qty -= step;
    if (it.qty <= 0) {
      _items.remove(key);
      _selectedKeys.remove(key); // nếu xóa thì bỏ luôn selection
    }
    notifyListeners();
    _scheduleSave();
  }

  void changeQty(String key, int qty) {
    final it = _items[key];
    if (it == null) return;
    if (qty <= 0) {
      _items.remove(key);
      _selectedKeys.remove(key);
    } else {
      it.qty = qty;
    }
    notifyListeners();
    _scheduleSave();
  }

  bool incrementClamped(String key, {required int stock}) {
    final it = _items[key];
    if (it == null) return false;

    final vid = it.variantId;
    final remain = maxQtyCanAdd(stock: stock, variantId: vid);
    if (remain <= 0) return false;

    it.qty += 1;
    notifyListeners();
    _scheduleSave();
    return true;
  }

  int setQtyClamped(String key, int desired, {required int stock}) {
    final it = _items[key];
    if (it == null) return 0;

    final vid = it.variantId;

    int others = 0;
    for (final e in _items.entries) {
      if (e.key == key) continue;
      if (e.value.variantId == vid) others += e.value.qty;
    }

    final cap = stock - others;

    if (cap <= 0) {
      _items.remove(key);
      _selectedKeys.remove(key);
      notifyListeners();
      _scheduleSave();
      return 0;
    }

    final clamped = desired.clamp(1, cap);
    it.qty = clamped;
    notifyListeners();
    _scheduleSave();
    return clamped;
  }

  void remove(String key) {
    if (_items.remove(key) != null) {
      _selectedKeys.remove(key); // 🆕
      if (kDebugMode) print('🗑 Đã xóa sản phẩm: $key');
      notifyListeners();
      _scheduleSave();
    }
  }

  void clearLocal() {
    _deb?.cancel();
    _muteSave = true;
    _resetInMemory(notify: true);
    _muteSave = false;
  }

  void clear() {
    _resetInMemory(notify: true);
    _scheduleSave();
  }

  void clearCart() => clear();

  // ------------------- VOUCHER -------------------
  Future<void> applyVoucherCode(String code, String? userId) async {
    _voucherError = null;
    notifyListeners();

    final repo = VoucherRepository();
    final now = DateTime.now().millisecondsSinceEpoch;
    final v = await repo.getByCode(code, nowMillis: now);

    if (v == null) {
      _applied = null;
      _voucherError = 'Mã không tồn tại hoặc đã hết hiệu lực.';
      notifyListeners();
      return;
    }

    // 🆕 kiểm tra minSubtotal dựa trên selectedSubtotal
    if (v.minSubtotal != null && selectedSubtotal < v.minSubtotal!) {
      final need = v.minSubtotal! - selectedSubtotal;
      _applied = null;
      _voucherError = 'Chưa đủ đơn tối thiểu, thiếu ${_vnd(need)}.';
      notifyListeners();
      return;
    }

    if (userId != null) {
      final ok = await repo.canUserUse(voucher: v, userId: userId);
      if (!ok) {
        final limit = (v as dynamic).perUserLimit;
        _applied = null;
        _voucherError = limit == null
            ? 'Bạn đã dùng tối đa mã này.'
            : 'Bạn đã dùng tối đa $limit lần.';
        notifyListeners();
        return;
      }
    }

    final remain = await repo.remainingCount(v.id);
    if (remain != null && remain <= 0) {
      _applied = null;
      _voucherError = 'Voucher đã hết lượt sử dụng.';
      notifyListeners();
      return;
    }

    _applied = v;
    _voucherError = null;
    notifyListeners();
  }

  void removeVoucher() {
    _applied = null;
    _voucherError = null;
    notifyListeners();
  }

  // ------------------- DISCOUNT -------------------
  double _calcDiscountAmount() {
    final v = _applied;
    if (v == null) return 0;
    final sbt = selectedSubtotal; // 🆕 chỉ tính trên hàng được chọn
    if (sbt <= 0) return 0;

    if (v.minSubtotal != null && sbt < v.minSubtotal!) return 0;

    double d = v.isPercent ? sbt * v.discount : v.discount;
    if (d < 0) d = 0;
    if (v.maxDiscount != null && d > v.maxDiscount!) d = v.maxDiscount!;
    if (d > sbt) d = sbt;
    return d;
  }

  // ------------------- REORDER / MUA LẠI -------------------
  Future<int> addFromOrder(String orderId) async {
    if (_uid == null) {
      throw StateError('CartController chưa được attachToUser.');
    }

    final snap =
    await _db.collection('orders').doc(orderId).collection('items').get();

    if (snap.docs.isEmpty) return 0;

    int totalAdded = 0;

    for (final doc in snap.docs) {
      final m = doc.data();

      final productId = (m['productId'] as String?) ?? doc.id;
      String name = (m['name'] ?? '') as String;
      final priceNum = (m['unitPrice'] ?? m['price'] ?? 0) as num;
      final qty = (m['qty'] ?? m['quantity'] ?? 1) as int;
      final variantId = m['variantId'] as String?;

      // -------- LẤY ẢNH + TÊN --------
      dynamic imageUrl =
          m['imageUrl'] ?? m['image'] ?? m['thumb'] ?? m['thumbnail'];

      Map<String, dynamic>? prodData;
      if ((name.isEmpty || imageUrl == null) && productId.isNotEmpty) {
        try {
          final prodSnap =
          await _db.collection('products').doc(productId).get();
          if (prodSnap.exists) {
            prodData = prodSnap.data() as Map<String, dynamic>;
          }
        } catch (_) {
          // ignore lỗi network
        }
      }

      if (name.isEmpty && prodData != null) {
        name = (prodData['name'] ?? '') as String;
      }

      if (imageUrl == null && prodData != null) {
        imageUrl = prodData['imageUrl'] ??
            prodData['image'] ??
            prodData['thumb'] ??
            (prodData['images'] is List &&
                (prodData['images'] as List).isNotEmpty
                ? (prodData['images'] as List).first
                : null);
      }

      // Options (size/color/…)
      Map<String, dynamic>? options;
      final rawOpt = m['options'];
      if (rawOpt is Map) {
        options = rawOpt.cast<String, dynamic>();
      }
      if (variantId != null && variantId.isNotEmpty) {
        options ??= {};
        options['variantId'] = variantId;
      }
      if (imageUrl != null) {
        options ??= {};
        options['imageUrl'] = imageUrl;
      }

      // Product tối thiểu dùng cho Cart
      final p = Product(
        id: productId,
        name: name,
        price: priceNum.toDouble(),
        imageUrl: imageUrl,
      );

      addCustomized(
        product: p,
        qty: qty,
        price: priceNum.toDouble(),
        variantId: variantId,
        options: options,
      );

      totalAdded += qty;
    }

    return totalAdded;
  }

  @override
  void dispose() {
    _deb?.cancel();
    super.dispose();
  }
}

// ======================================================================
// 🔹 Helper định dạng tiền Việt Nam (₫)
// ======================================================================
String _vnd(Object value) {
  final n = (value as num).toDouble();
  final s = n.toStringAsFixed(0);
  final buf = StringBuffer();
  for (int i = 0; i < s.length; i++) {
    final rev = s.length - i;
    buf.write(s[i]);
    if (rev > 1 && rev % 3 == 1) buf.write(',');
  }
  return '₫${buf.toString()}';
}
