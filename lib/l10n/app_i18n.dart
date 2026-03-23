import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import '../controllers/settings_controller.dart';

/// Bảng dịch đơn giản (thêm key khi cần)
const Map<String, Map<String, String>> _t = {
  'vi': {
    'settings.title': 'Cài đặt tài khoản',
    'settings.section.notifications': 'Thông báo',
    'settings.orderUpdates': 'Cập nhật trạng thái đơn hàng',
    'settings.promos': 'Khuyến mãi & ưu đãi',
    'settings.section.ui': 'Giao diện & Ngôn ngữ',
    'settings.darkMode': 'Chế độ tối',
    'settings.language': 'Ngôn ngữ',
    'settings.language.vi': 'Tiếng Việt',
    'settings.language.en': 'English',
    'settings.section.account': 'Tài khoản & Bảo mật',
    'settings.editProfile': 'Chỉnh sửa hồ sơ',
    'settings.changePassword': 'Đổi mật khẩu',
    'settings.address': 'Địa chỉ giao hàng',
    'settings.payment': 'Phương thức thanh toán',
    'settings.section.legal': 'Hỗ trợ & pháp lý',
    'settings.policy': 'Chính sách & Điều khoản',
    'settings.supportEmail': 'Email hỗ trợ',
    'common.copied': 'Đã sao chép: ',
  },
  'en': {
    'settings.title': 'Account settings',
    'settings.section.notifications': 'Notifications',
    'settings.orderUpdates': 'Order status updates',
    'settings.promos': 'Promotions & deals',
    'settings.section.ui': 'Appearance & Language',
    'settings.darkMode': 'Dark mode',
    'settings.language': 'Language',
    'settings.language.vi': 'Vietnamese',
    'settings.language.en': 'English',
    'settings.section.account': 'Account & Security',
    'settings.editProfile': 'Edit profile',
    'settings.changePassword': 'Change password',
    'settings.address': 'Shipping address',
    'settings.payment': 'Payment methods',
    'settings.section.legal': 'Support & Legal',
    'settings.policy': 'Policy & Terms',
    'settings.supportEmail': 'Support email',
    'common.copied': 'Copied: ',
  },
};

/// Extension để gọi: context.tr('settings.title')
extension AppI18n on BuildContext {
  String tr(String key) {
    final lang = watch<SettingsController>().language; // rebuild khi đổi
    return _t[lang]?[key] ?? _t['en']![key] ?? key;
  }
}
