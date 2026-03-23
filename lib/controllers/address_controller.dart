import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/app_address.dart';

class AddressController extends ChangeNotifier {
  // 🧭 Truy cập nhanh đến collection địa chỉ của user
  CollectionReference<Map<String, dynamic>> _col(String uid) =>
      FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('addresses');

  // ===========================================================
  // 🔹 STREAM DANH SÁCH ĐỊA CHỈ
  // ===========================================================
  /// Dùng trong màn hình “Danh sách địa chỉ”
  /// Tự động sắp xếp: địa chỉ mặc định lên đầu.
  Stream<List<AppAddress>> streamAddresses(String uid) {
    return _col(uid)
        .orderBy('isDefault', descending: true)
        .orderBy('province')
        .snapshots()
        .map(
          (q) => q.docs
          .map((d) => AppAddress.fromMap(d.id, d.data()))
          .toList(),
    );
  }

  // ===========================================================
  // 🔹 CRUD CƠ BẢN
  // ===========================================================
  Future<void> addAddress(String uid, AppAddress a) async {
    await _col(uid).add(a.toMap());
  }

  /// ✅ Thêm địa chỉ mới và trả về `id` để set mặc định ngay
  Future<String> addAddressReturnId(String uid, AppAddress a) async {
    final ref = await _col(uid).add(a.toMap());
    return ref.id;
  }

  Future<void> updateAddress(String uid, AppAddress a) async {
    await _col(uid).doc(a.id).update(a.toMap());
  }

  Future<void> deleteAddress(String uid, String id) async {
    await _col(uid).doc(id).delete();
  }

  // ===========================================================
  // 🔹 LƯU ĐỊA CHỈ MẶC ĐỊNH TRONG CONTROLLER
  // ===========================================================
  AppAddress? _defaultAddress;
  AppAddress? get defaultAddress => _defaultAddress;

  // ===========================================================
  // 🔹 ĐẶT MẶC ĐỊNH (transaction an toàn) + CẬP NHẬT local
  // ===========================================================
  Future<void> setDefault(String uid, String id) async {
    final col = _col(uid);

    await FirebaseFirestore.instance.runTransaction((tx) async {
      // Bỏ default cũ
      final currentDefault =
      await col.where('isDefault', isEqualTo: true).get();
      for (final doc in currentDefault.docs) {
        tx.update(doc.reference, {'isDefault': false});
      }
      // Set default mới
      tx.update(col.doc(id), {'isDefault': true});
    });

    try {
      // 🔁 Sau khi transaction xong, đọc lại doc default mới
      final doc = await col.doc(id).get();
      if (doc.exists && doc.data() != null) {
        _defaultAddress =
            AppAddress.fromMap(doc.id, doc.data()!);
      } else {
        _defaultAddress = null;
      }
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ [AddressController] setDefault fetch error: $e');
      }
      _defaultAddress = null;
    }

    // 👉 Thông báo cho tất cả widget đang watch AddressController
    notifyListeners();
  }

  // ===========================================================
  // 🔹 DÙNG CHO CHECKOUT (LOAD DEFAULT KHI VÀO MÀN)
  // ===========================================================
  /// Hàm này để `CheckoutScreen` dùng khi mở.
  /// Nó sẽ lấy địa chỉ mặc định đầu tiên trong Firestore.
  Future<void> fetchDefaultAddress(String uid) async {
    try {
      final snapshot = await _col(uid)
          .where('isDefault', isEqualTo: true)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        _defaultAddress = AppAddress.fromMap(
          snapshot.docs.first.id,
          snapshot.docs.first.data(),
        );
      } else {
        _defaultAddress = null;
      }

      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ [AddressController] fetchDefaultAddress error: $e');
      }
      _defaultAddress = null;
      notifyListeners();
    }
  }

  // ===========================================================
  // 🔹 PATCH THÊM CÁC FIELD PHỤ (VD: lat/lng) SAU KHI LƯU
  // ===========================================================
  /// Ghi *merge* để không làm mất các field đã có.
  /// Dùng khi model chưa khai báo sẵn `lat/lng` nhưng vẫn muốn lưu toạ độ.
  Future<void> patchExtra(
      String uid,
      String addressId,
      Map<String, dynamic> data,
      ) async {
    if (uid.isEmpty || addressId.isEmpty) {
      throw ArgumentError('uid/addressId trống');
    }
    await _col(uid).doc(addressId).set(data, SetOptions(merge: true));
  }
}
