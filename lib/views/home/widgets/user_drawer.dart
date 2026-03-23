import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

// Các controller xử lý logic tài khoản, giỏ hàng, danh sách yêu thích
import '../../../controllers/auth_controller.dart';
import '../../../controllers/cart_controller.dart';
import '../../../controllers/wishlist_controller.dart';
import '../../../routes/app_routes.dart';
import '../../../theme/app_theme.dart';

// Màn hình chỉnh sửa hồ sơ cá nhân
import '../../profile/edit_profile_screen.dart';

/// ============================================================================
/// 🧭 UserDrawer — Drawer hiển thị thông tin tài khoản & điều hướng người dùng
/// ----------------------------------------------------------------------------
/// ✅ Có thể cuộn nếu nội dung dài (tránh lỗi RenderFlex overflow)
/// ✅ Hiển thị avatar, tên, email, số điện thoại
/// ✅ Liên kết nhanh đến Yêu thích, Đơn hàng, Cài đặt, Trợ giúp, Giới thiệu
/// ✅ Nút đăng xuất an toàn, detach các controller trước khi logout
/// ============================================================================
class UserDrawer extends StatelessWidget {
  const UserDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final user = auth.user;
    final profile = auth.profile;

    // ======= Xử lý thông tin người dùng hiển thị =======
    final String displayName = (() {
      final raw = (profile?['name'] ??
          profile?['displayName'] ??
          user?.displayName ??
          '')
          .toString()
          .trim();
      return raw.isEmpty ? 'Khách hàng thân thiết' : raw;
    })();

    final String email =
    (user?.email ?? (profile?['email'] ?? 'user@youremail.com')).toString();
    final String photoUrl =
    (user?.photoURL ?? (profile?['photoURL'] ?? '')).toString();
    final String phone = (profile?['phone'] as String?)?.trim() ?? '';

    return Drawer(
      child: SafeArea(
        // Dùng SingleChildScrollView để tránh lỗi RenderFlex overflow
        child: SingleChildScrollView(
          child: Column(
            children: [
              // ==== HEADER NGƯỜI DÙNG ====
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(gradient: AppTheme.authGradient),
                child: Row(
                  children: [
                    // Ảnh đại diện (hoặc icon mặc định)
                    CircleAvatar(
                      radius: 26,
                      backgroundColor: Colors.white,
                      backgroundImage:
                      photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
                      child: photoUrl.isEmpty
                          ? Icon(
                        Icons.person_outline,
                        size: 28,
                        color: Colors.grey.shade800,
                      )
                          : null,
                    ),
                    const SizedBox(width: 14),

                    // Thông tin cơ bản
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.ivory,
                            ),
                          ),
                          if (email.isNotEmpty) const SizedBox(height: 2),
                          if (email.isNotEmpty)
                            Text(
                              email,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13,
                                color: Colors.white70,
                              ),
                            ),
                          if (phone.isNotEmpty) const SizedBox(height: 2),
                          if (phone.isNotEmpty)
                            Text(
                              phone,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13,
                                color: Colors.white60,
                              ),
                            ),
                        ],
                      ),
                    ),

                    // Nút chỉnh sửa hồ sơ
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, color: Colors.white),
                      tooltip: 'Chỉnh sửa hồ sơ',
                      onPressed: () {
                        Navigator.of(context).maybePop();
                        Navigator.of(context, rootNavigator: true).push(
                          MaterialPageRoute(
                            builder: (_) => const EditProfileScreen(),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),

              // ==== DANH MỤC TÀI KHOẢN ====
              const _SectionTitle('Tài khoản của tôi'),

              _NavTile(
                icon: Icons.favorite_border,
                title: 'Yêu thích',
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushReplacementNamed(
                    context,
                    AppRoutes.root,
                    arguments: {'tab': 2},
                  );
                },
              ),
              _NavTile(
                icon: Icons.receipt_long_outlined,
                title: 'Đơn hàng của tôi',
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushReplacementNamed(
                    context,
                    AppRoutes.root,
                    arguments: {'tab': 4},
                  );
                },
              ),
              _NavTile(
                icon: Icons.local_offer_outlined,
                title: 'Khuyến mãi',
                onTap: () {
                  Navigator.pop(context);
                  final isAdmin = context.read<AuthController>().isAdmin;
                  Navigator.pushNamed(
                    context,
                    isAdmin
                        ? AppRoutes.adminVouchers
                        : AppRoutes.userVouchers,
                  );
                },
              ),
              _NavTile(
                icon: Icons.settings_outlined,
                title: 'Cài đặt tài khoản',
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, AppRoutes.userSettings);
                },
              ),

              const Divider(),

              // ==== MỤC TRỢ GIÚP ====
              const _SectionTitle('Hỗ trợ & thông tin'),

              _NavTile(
                icon: Icons.help_outline,
                title: 'Trung tâm trợ giúp',
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, AppRoutes.helpCenter);
                },
              ),
              _NavTile(
                icon: Icons.confirmation_num_outlined,
                title: 'Yêu cầu của tôi',
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, AppRoutes.myTickets);
                },
              ),
              _NavTile(
                icon: Icons.info_outline,
                title: 'Giới thiệu ứng dụng',
                onTap: () {
                  Navigator.pop(context);
                  _openAboutDialog(context);
                },
              ),

              // ==== NÚT ĐĂNG XUẤT ====
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(46),
                    side: const BorderSide(color: Colors.redAccent),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.logout, color: Colors.redAccent),
                  label: const Text(
                    'Đăng xuất',
                    style: TextStyle(color: Colors.redAccent),
                  ),
                  onPressed: () async {
                    try {
                      Navigator.pop(context);

                      // Ngắt kết nối các controller
                      await context.read<WishlistController>().detach();
                      await context.read<AuthController>().logout();
                      await context.read<CartController>().detach();

                      if (!context.mounted) return;
                      Navigator.of(context).pushNamedAndRemoveUntil(
                        AppRoutes.login,
                            (route) => false,
                      );
                    } catch (e) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Đăng xuất thất bại: $e')),
                      );
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// ============================================================================
/// 🔹 About dialog — thông tin ứng dụng
/// ============================================================================
void _openAboutDialog(BuildContext context) {
  final year = DateTime.now().year;
  const version = String.fromEnvironment('APP_VERSION', defaultValue: '1.0.0');

  showAboutDialog(
    context: context,
    applicationName: 'CSES',
    applicationVersion: version,
    applicationIcon: const _AppLogo(),
    applicationLegalese: '© $year CSES Team. All rights reserved.',
    children: [
      const SizedBox(height: 8),
      Text(
        'CSES là ứng dụng mua đồ công nghệ, điện thoại & phụ kiện. '
            'Tập trung trải nghiệm an toàn – nhanh – đáng tin cậy.',
        style: Theme.of(context).textTheme.bodyMedium,
      ),
      const SizedBox(height: 12),
      const _Bullet(
        icon: Icons.local_shipping_outlined,
        text: 'Giao nhanh 2H nội thành',
      ),
      const _Bullet(
        icon: Icons.verified_user_outlined,
        text: 'Thanh toán an toàn, bảo mật',
      ),
      const _Bullet(
        icon: Icons.redeem_outlined,
        text: 'Voucher định kỳ & tích điểm thành viên',
      ),
      const SizedBox(height: 12),
      const Divider(height: 20),
      Text('Hỗ trợ', style: Theme.of(context).textTheme.titleSmall),
      const SizedBox(height: 6),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          TextButton.icon(
            onPressed: () async {
              await Clipboard.setData(
                const ClipboardData(text: 'support@cses.store'),
              );
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Đã sao chép email hỗ trợ')),
                );
              }
            },
            icon: const Icon(Icons.email_outlined),
            label: const Text('Email hỗ trợ'),
          ),
          TextButton.icon(
            onPressed: () async {
              await Clipboard.setData(
                const ClipboardData(text: '+84 9xxx xxx xx'),
              );
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Đã sao chép số hotline')),
                );
              }
            },
            icon: const Icon(Icons.phone_outlined),
            label: const Text('Hotline'),
          ),
        ],
      ),
    ],
  );
}

/// ============================================================================
/// 🔹 Các widget con phụ trợ
/// ============================================================================

/// 👉 Mục điều hướng trong Drawer
class _NavTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  const _NavTile({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: Colors.black87),
      title: Text(title),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}

/// 👉 Tiêu đề phân nhóm
class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      title: Text(
        text,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: Colors.black54,
          letterSpacing: .3,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// 👉 Logo gradient tròn trong hộp thoại About
class _AppLogo extends StatelessWidget {
  const _AppLogo();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [Color(0xFF0EA5E9), Color(0xFF6366F1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Icon(Icons.storefront_outlined, color: Colors.white),
    );
  }
}

/// 👉 Dòng mô tả bullet trong AboutDialog
class _Bullet extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Bullet({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18),
        const SizedBox(width: 8),
        Expanded(child: Text(text)),
      ],
    );
  }
}
