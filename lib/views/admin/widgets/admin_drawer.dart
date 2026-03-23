import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../controllers/auth_controller.dart';
import '../../../routes/app_routes.dart';

class AdminDrawer extends StatelessWidget {
  const AdminDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final auth = context.watch<AuthController>();
    final userName = auth.profile?['name'] ?? 'Admin';
    final userEmail = auth.user?.email ?? 'admin@cses.store';
    final userRole = auth.profile?['role'] ?? 'admin';

    final divider =
    Divider(color: cs.outlineVariant.withValues(alpha: .5), height: 1);

    return Drawer(
      backgroundColor: cs.surface,
      child: SafeArea(
        child: Column(
          children: [
            // HEADER (click → về trang chủ admin)
            InkWell(
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  AppRoutes.adminRoot,
                      (route) => false,
                );
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
                decoration: BoxDecoration(
                  // gradient theo theme (đẹp trong cả dark/light)
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      cs.primary,
                      cs.primaryContainer,
                    ],
                  ),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: cs.onPrimary.withValues(alpha: .95),
                      child: Icon(
                        Icons.admin_panel_settings,
                        size: 28,
                        color: cs.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            userName,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                              color: cs.onPrimaryContainer,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            userEmail,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                              color: cs.onPrimaryContainer
                                  .withValues(alpha: .8),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            userRole == 'admin' ? 'Quản trị viên' : 'Nhân viên',
                            style: TextStyle(
                              fontSize: 12,
                              color:
                              cs.onPrimaryContainer.withValues(alpha: .8),
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // MENU
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  const _SectionTitle('Sản phẩm'),
                  _NavTile(
                    icon: Icons.inventory_2_outlined,
                    title: 'Danh sách sản phẩm',
                    route: AppRoutes.adminProducts,
                  ),
                  _NavTile(
                    icon: Icons.sell_outlined,
                    title: 'Thương hiệu',
                    route: AppRoutes.adminBrands,
                  ),
                  _NavTile(
                    icon: Icons.category_outlined,
                    title: 'Danh mục',
                    route: AppRoutes.adminCategories,
                  ),
                  divider,

                  const _SectionTitle('Vận hành'),
                  _NavTile(
                    icon: Icons.people_outline,
                    title: 'Người dùng',
                    route: AppRoutes.adminUsers,
                  ),
                  _NavTile(
                    icon: Icons.receipt_long_outlined,
                    title: 'Đơn hàng',
                    route: AppRoutes.adminOrders,
                  ),

                  // 🆕 CẤU HÌNH PHÍ SHIP
                  _NavTile(
                    icon: Icons.local_shipping_outlined,
                    title: 'Cấu hình phí ship',
                    route: AppRoutes.adminShippingConfig,
                  ),

                  // 🆕 KHO & HUB
                  _NavTile(
                    icon: Icons.home_work_outlined,
                    title: 'Kho & Hub',
                    route: AppRoutes.adminWarehouses,
                  ),

                  const _SupportTile(),
                  divider,

                  const _SectionTitle('Marketing & Báo cáo'),
                  _NavTile(
                    icon: Icons.slideshow_outlined,
                    title: 'Banner quảng cáo',
                    route: AppRoutes.adminBanners,
                  ),

                  // ✅✅✅ ĐÃ THÊM: Video sản phẩm (mở màn hình quản lý video)
                  _NavTile(
                    icon: Icons.video_library_outlined,
                    title: 'Video sản phẩm',
                    route: AppRoutes.adminVideoManager, // 👈 mở màn hình (hình 1)
                  ),
                  // ✅✅✅ HẾT PHẦN THÊM

                  _NavTile(
                    icon: Icons.discount_outlined,
                    title: 'Khuyến mãi / Voucher',
                    route: AppRoutes.adminVouchers,
                  ),
                  _NavTile(
                    icon: Icons.policy_outlined,
                    title: 'Chính sách & Điều khoản',
                    route: AppRoutes.adminPolicies,
                  ),

                  // 🆕 MINI-GAME XU
                  _NavTile(
                    icon: Icons.casino_outlined,
                    title: 'Mini-game Xu',
                    route: AppRoutes.adminXuMiniGameStats, // 👈 route mới
                  ),

                  _NavTile(
                    icon: Icons.bar_chart_outlined,
                    title: 'Thống kê & Báo cáo',
                    route: AppRoutes.adminReports,
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),

            // ĐĂNG XUẤT
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(46),
                  side: BorderSide(
                    color: Theme.of(context).colorScheme.error,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  foregroundColor: cs.error,
                ),
                icon: const Icon(Icons.logout),
                label: const Text('Đăng xuất'),
                onPressed: () async {
                  await context.read<AuthController>().logout();
                  if (!context.mounted) return;
                  Navigator.of(context).pushNamedAndRemoveUntil(
                    AppRoutes.login,
                        (route) => false,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Nav item: tự đổi màu khi “active”, bám theo theme
// ─────────────────────────────────────────────────────────────────────────────
class _NavTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String route;
  const _NavTile({
    required this.icon,
    required this.title,
    required this.route,
  });

  bool _isActive(BuildContext context) =>
      ModalRoute.of(context)?.settings.name == route;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final active = _isActive(context);

    final fg = active ? cs.primary : cs.onSurface;
    final tileBg =
    active ? cs.primaryContainer.withValues(alpha: .18) : Colors.transparent;

    return Container(
      color: tileBg,
      child: ListTile(
        leading: Icon(icon, color: fg),
        title: Text(
          title,
          style: TextStyle(
            color: fg,
            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
        trailing: Icon(
          Icons.chevron_right,
          color: fg.withValues(alpha: .7),
        ),
        onTap: () {
          Navigator.pop(context);
          Navigator.pushNamed(context, route);
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Section title: dùng onSurface mờ để hợp dark/light
// ─────────────────────────────────────────────────────────────────────────────
class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListTile(
      dense: true,
      title: Text(
        text,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: cs.onSurface.withValues(alpha: .6),
          letterSpacing: .3,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Support tile + badge realtime
// ─────────────────────────────────────────────────────────────────────────────
class _SupportTile extends StatelessWidget {
  const _SupportTile();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final active =
        ModalRoute.of(context)?.settings.name == AppRoutes.adminTickets;
    final fg = active ? cs.primary : cs.onSurface;

    return ListTile(
      leading: Icon(Icons.headset_mic_outlined, color: fg),
      title: Text(
        'Hỗ trợ / Ticket',
        style: TextStyle(
          color: fg,
          fontWeight: active ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const _OpenTicketsBadge(),
          const SizedBox(width: 8),
          Icon(
            Icons.chevron_right,
            color: fg.withValues(alpha: .7),
          ),
        ],
      ),
      onTap: () {
        Navigator.pop(context);
        Navigator.pushNamed(context, AppRoutes.adminTickets);
      },
    );
  }
}

class _OpenTicketsBadge extends StatelessWidget {
  const _OpenTicketsBadge();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('support_tickets')
          .where('status', isEqualTo: 'open')
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData || (snap.data?.docs.isEmpty ?? true)) {
          return const SizedBox.shrink();
        }
        final n = snap.data!.docs.length;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: cs.primaryContainer,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            '$n mới',
            style: TextStyle(
              color: cs.onPrimaryContainer,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        );
      },
    );
  }
}
