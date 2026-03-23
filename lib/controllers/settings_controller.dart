import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 🆕 Enum phương thức thanh toán dùng chung toàn app
enum PaymentMethod {
  cod,          // Thanh toán khi nhận hàng
  bankTransfer, // Chuyển khoản ngân hàng
  momo,         // Ví MoMo
}

class SettingsController extends ChangeNotifier {
  final SharedPreferences _prefs;
  SettingsController(this._prefs);

  static const _kNotiOrder       = 'notiOrder';
  static const _kNotiPromo       = 'notiPromo';
  static const _kDarkMode        = 'darkMode';
  static const _kLanguage        = 'language';
  static const _kPaymentMethod   = 'paymentMethod'; // 🆕 key lưu payment

  // ----- Getters (không-null) -----
  bool get notiOrder => _prefs.getBool(_kNotiOrder) ?? true;
  bool get notiPromo => _prefs.getBool(_kNotiPromo) ?? true;
  bool get darkMode  => _prefs.getBool(_kDarkMode)  ?? false;
  String get language => _prefs.getString(_kLanguage) ?? 'vi';

  /// 🆕 Phương thức thanh toán mặc định
  PaymentMethod get paymentMethod {
    final raw = _prefs.getString(_kPaymentMethod);
    switch (raw) {
      case 'bank_transfer':
        return PaymentMethod.bankTransfer;
      case 'momo':
        return PaymentMethod.momo;
      case 'cod':
      default:
        return PaymentMethod.cod;
    }
  }

  // ----- Setters -----
  Future<void> setNotiOrder(bool v) async {
    await _prefs.setBool(_kNotiOrder, v);
    notifyListeners();
  }

  Future<void> setNotiPromo(bool v) async {
    await _prefs.setBool(_kNotiPromo, v);
    notifyListeners();
  }

  Future<void> setDarkMode(bool v) async {
    await _prefs.setBool(_kDarkMode, v);
    notifyListeners();
  }

  Future<void> setLanguage(String v) async {
    await _prefs.setString(_kLanguage, v);
    notifyListeners();
  }

  /// 🆕 Lưu phương thức thanh toán
  Future<void> setPaymentMethod(PaymentMethod m) async {
    await _prefs.setString(_kPaymentMethod, _paymentToKey(m));
    notifyListeners();
  }

  // 🆕 Helper: map enum <-> string để lưu SharedPreferences
  String _paymentToKey(PaymentMethod m) {
    switch (m) {
      case PaymentMethod.cod:
        return 'cod';
      case PaymentMethod.bankTransfer:
        return 'bank_transfer';
      case PaymentMethod.momo:
        return 'momo';
    }
  }
}
