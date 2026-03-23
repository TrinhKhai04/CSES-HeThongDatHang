// 📁 lib/views/profile/user_settings_screen.dart
// ============================================================================
// ⚙️ Màn hình "Cài đặt tài khoản" — Apple Store style (grouped list, Light/Dark)
// ----------------------------------------------------------------------------
// • Dark/Light chuẩn: không hard-code màu sáng.
// • Nền grouped theo iOS, mỗi group là card bo 12px, divider mảnh.
// • Row điều hướng: icon trái + title/subtitle + chevron phải.
// • Row switch: CupertinoSwitch có track Dark chuẩn.
// • AppBar large-title gọn, tự đổi màu theo theme.
// • Hỗ trợ chọn ngôn ngữ & gửi email hỗ trợ (mailto).
// ============================================================================

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart'; // launch email

import '../../../controllers/settings_controller.dart';
import '../profile/profile_screen.dart';
import '../../../routes/app_routes.dart';
import '../../../l10n/app_i18n.dart';

class UserSettingsScreen extends StatelessWidget {
  const UserSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<SettingsController>();

    // ========================= BẢNG MÀU THEO THEME =========================
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // iOS grouped colors (tham chiếu Human Interface Guidelines)
    final bg         = isDark ? const Color(0xFF000000) : const Color(0xFFF2F2F7);
    final cardBg     = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    final shadowCol  = isDark ? Colors.transparent      : const Color(0x0C000000);
    final borderCol  = isDark ? const Color(0xFF2C2C2E) : Colors.transparent;
    final headText   = isDark ? const Color(0xFF98989F) : const Color(0xFF6B7280);
    final iconColor  = isDark ? const Color(0xFF8E8E93) : const Color(0xFF6B7280);
    final chevronCol = isDark ? const Color(0xFF636366) : const Color(0xFFC7C7CC);
    final dividerCol = isDark ? const Color(0x332C2C2E) : const Color(0x1A000000);

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // ---------------- AppBar kiểu iOS (large title gọn) ----------------
            SliverAppBar(
              pinned: true,
              backgroundColor: bg,
              elevation: 0,
              expandedHeight: 72,
              leading: IconButton(
                icon: Icon(CupertinoIcons.back,
                    color: Theme.of(context).colorScheme.onSurface),
                onPressed: () => Navigator.of(context).maybePop(),
                tooltip: context.tr('common.back'),
              ),
              flexibleSpace: FlexibleSpaceBar(
                titlePadding:
                const EdgeInsetsDirectional.only(start: 56, bottom: 12),
                title: Text(
                  context.tr('settings.title'),
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
            ),

            // ======================== MỤC 1: Thông báo =========================
            _SectionHeader(context.tr('settings.section.notifications'),
                headText: headText),
            _Group(
              cardBg: cardBg,
              shadowCol: shadowCol,
              borderCol: borderCol,
              dividerCol: dividerCol,
              children: [
                _SwitchRow(
                  icon: CupertinoIcons.bell,
                  iconColor: iconColor,
                  title: context.tr('settings.orderUpdates'),
                  value: s.notiOrder,
                  onChanged: (v) =>
                      context.read<SettingsController>().setNotiOrder(v),
                  isDark: isDark,
                ),
                _SwitchRow(
                  icon: CupertinoIcons.tag,
                  iconColor: iconColor,
                  title: context.tr('settings.promos'),
                  value: s.notiPromo,
                  onChanged: (v) =>
                      context.read<SettingsController>().setNotiPromo(v),
                  isDark: isDark,
                ),
              ],
            ),

            // =================== MỤC 2: Giao diện & Ngôn ngữ ===================
            _SectionHeader(context.tr('settings.section.ui'), headText: headText),
            _Group(
              cardBg: cardBg,
              shadowCol: shadowCol,
              borderCol: borderCol,
              dividerCol: dividerCol,
              children: [
                _SwitchRow(
                  icon: CupertinoIcons.moon,
                  iconColor: iconColor,
                  title: context.tr('settings.darkMode'),
                  value: s.darkMode,
                  onChanged: (v) =>
                      context.read<SettingsController>().setDarkMode(v),
                  isDark: isDark,
                ),
                _NavRow(
                  icon: CupertinoIcons.globe,
                  iconColor: iconColor,
                  chevronColor: chevronCol,
                  title: context.tr('settings.language'),
                  subtitle: s.language == 'vi'
                      ? context.tr('settings.language.vi')
                      : context.tr('settings.language.en'),
                  onTap: () => _pickLanguage(context, s.language),
                ),
              ],
            ),

            // =================== MỤC 3: Tài khoản & Bảo mật ====================
            _SectionHeader(context.tr('settings.section.account'),
                headText: headText),
            _Group(
              cardBg: cardBg,
              shadowCol: shadowCol,
              borderCol: borderCol,
              dividerCol: dividerCol,
              children: [
                _NavRow(
                  icon: CupertinoIcons.person,
                  iconColor: iconColor,
                  chevronColor: chevronCol,
                  title: context.tr('settings.editProfile'),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const ProfileScreen(showBack: true)),
                  ),
                ),
                _NavRow(
                  icon: CupertinoIcons.lock,
                  iconColor: iconColor,
                  chevronColor: chevronCol,
                  title: context.tr('settings.changePassword'),
                  onTap: () =>
                      Navigator.pushNamed(context, AppRoutes.changePassword),
                ),
                _NavRow(
                  icon: CupertinoIcons.house,
                  iconColor: iconColor,
                  chevronColor: chevronCol,
                  title: context.tr('settings.address'),
                  onTap: () =>
                      Navigator.pushNamed(context, AppRoutes.addressList),
                ),
                _NavRow(
                  icon: CupertinoIcons.creditcard,
                  iconColor: iconColor,
                  chevronColor: chevronCol,
                  title: context.tr('settings.payment'),
                  // 🆕 Mở màn hình Phương thức thanh toán
                  onTap: () =>
                      Navigator.pushNamed(context, AppRoutes.paymentMethods),
                ),
              ],
            ),

            // ===================== MỤC 4: Hỗ trợ & Pháp lý =====================
            _SectionHeader(context.tr('settings.section.legal'),
                headText: headText),
            _Group(
              cardBg: cardBg,
              shadowCol: shadowCol,
              borderCol: borderCol,
              dividerCol: dividerCol,
              children: [
                _NavRow(
                  icon: CupertinoIcons.shield,
                  iconColor: iconColor,
                  chevronColor: chevronCol,
                  title: context.tr('settings.policy'),
                  onTap: () => Navigator.pushNamed(
                    context,
                    AppRoutes.policyTerms,
                  ),
                ),
                _NavRow(
                  icon: CupertinoIcons.envelope,
                  iconColor: iconColor,
                  chevronColor: chevronCol,
                  title: context.tr('settings.supportEmail'),
                  subtitle: 'support@cses.store',
                  onTap: () => _launchEmail(context),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // --------------------------------------------------------------------------
  // 🌍 BOTTOM SHEET CHỌN NGÔN NGỮ
  // --------------------------------------------------------------------------
  Future<void> _pickLanguage(BuildContext context, String current) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1C1C1E) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<String>(
              value: 'vi',
              groupValue: current,
              title: Text(context.tr('settings.language.vi')),
              onChanged: (v) => Navigator.pop(context, v),
            ),
            Divider(
              height: 0,
              color: isDark ? const Color(0x332C2C2E) : const Color(0x1A000000),
            ),
            RadioListTile<String>(
              value: 'en',
              groupValue: current,
              title: Text(context.tr('settings.language.en')),
              onChanged: (v) => Navigator.pop(context, v),
            ),
            const SizedBox(height: 6),
          ],
        ),
      ),
    );

    if (choice != null) {
      await context.read<SettingsController>().setLanguage(choice);
    }
  }

  // --------------------------------------------------------------------------
  // ✉️ EMAIL HỖ TRỢ: mở app mail; nếu không có app -> copy địa chỉ
  // --------------------------------------------------------------------------
  Future<void> _launchEmail(BuildContext context) async {
    final uri = Uri(
      scheme: 'mailto',
      path: 'support@cses.store',
      // Dùng queryParameters để auto encode
      queryParameters: const {
        'subject': 'Hỗ trợ khách hàng CSES App',
        'body': 'Xin chào đội ngũ hỗ trợ,\n\n',
      },
    );

    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        await _copy(context, 'support@cses.store');
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Không thể mở ứng dụng email — Đã sao chép địa chỉ'),
            ),
          );
        }
      }
    } catch (e) {
      await _copy(context, 'support@cses.store');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi khi mở email: $e')),
        );
      }
    }
  }

  // --------------------------------------------------------------------------
  // 📋 SAO CHÉP CHUỖI (fallback cho email/link)
  // --------------------------------------------------------------------------
  Future<void> _copy(BuildContext context, String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${context.tr('common.copied')}$text')),
      );
    }
  }
}

// ============================================================================
// 🔹 WIDGET PHỤ TRỢ: Header nhóm, Group container, Row điều hướng & Row switch
// ============================================================================

/// Header nhỏ cho từng nhóm — nhận màu theo theme
class _SectionHeader extends StatelessWidget {
  final String text;
  final Color headText;
  const _SectionHeader(this.text, {required this.headText});

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 6),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 12.5,
            color: headText,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
      ),
    );
  }
}

/// Card group — nhận màu nền, border, shadow, divider theo theme
class _Group extends StatelessWidget {
  final List<Widget> children;
  final Color cardBg;
  final Color shadowCol;
  final Color borderCol;
  final Color dividerCol;

  const _Group({
    required this.children,
    required this.cardBg,
    required this.shadowCol,
    required this.borderCol,
    required this.dividerCol,
  });

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderCol),
          boxShadow: [
            // Dark: bỏ shadow để đúng tone iOS
            if (shadowCol != Colors.transparent)
              const BoxShadow(
                color: Color(0x0C000000),
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
          ],
        ),
        child: Column(children: _withDividers(children, dividerCol)),
      ),
    );
  }

  // Divider mảnh giữa các row
  List<Widget> _withDividers(List<Widget> tiles, Color dividerCol) {
    final out = <Widget>[];
    for (int i = 0; i < tiles.length; i++) {
      out.add(tiles[i]);
      if (i != tiles.length - 1) {
        out.add(Divider(height: 1, thickness: 0.5, color: dividerCol));
      }
    }
    return out;
  }
}

/// Row điều hướng — icon trái, title/subtitle, chevron phải
class _NavRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final Color iconColor;
  final Color chevronColor;

  const _NavRow({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.onTap,
    required this.iconColor,
    required this.chevronColor,
  });

  @override
  Widget build(BuildContext context) {
    // Bọc Material để InkWell hiển thị ripple/highlight đúng
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        highlightColor: const Color(0x0F007AFF), // nhấn nhẹ kiểu iOS
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Icon(icon, size: 20, color: iconColor),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.2,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: TextStyle(fontSize: 13.5, color: iconColor),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(CupertinoIcons.chevron_forward,
                  size: 18, color: chevronColor),
            ],
          ),
        ),
      ),
    );
  }
}

/// Row có switch — CupertinoSwitch + track dark
class _SwitchRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;
  final Color iconColor;
  final bool isDark;

  const _SwitchRow({
    required this.icon,
    required this.title,
    required this.value,
    required this.onChanged,
    required this.iconColor,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        // ⚠️ PHẢI dùng List<Widget>, KHÔNG dùng set {} để tránh lỗi runtime.
        children: <Widget>[
          Icon(icon, size: 20, color: iconColor),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.2,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
          CupertinoSwitch(
            value: value,
            onChanged: onChanged,
            activeColor: const Color(0xFF34C759),          // iOS green
            trackColor: isDark ? const Color(0xFF3A3A3C) : null, // iOS dark track
          ),
        ],
      ),
    );
  }
}
