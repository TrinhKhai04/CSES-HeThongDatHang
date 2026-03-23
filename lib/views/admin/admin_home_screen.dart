// lib/views/admin/admin_home_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/auth_controller.dart';
import '../../routes/app_routes.dart';
import '../admin/widgets/admin_drawer.dart';

class AdminHomeScreen extends StatelessWidget {
  const AdminHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();

    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final bg = CupertinoColors.systemGroupedBackground.resolveFrom(context);
    final appBarBg = cs.surface;
    final appBarFg = cs.onSurface;
    final accent = cs.primary;

    return Scaffold(
      backgroundColor: bg,
      drawer: const AdminDrawer(),

      appBar: AppBar(
        backgroundColor: appBarBg,
        foregroundColor: appBarFg,
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false,
        title: Text(
          'Admin Dashboard',
          style: TextStyle(
            color: accent,
            fontWeight: FontWeight.w700,
            fontSize: 20,
          ),
        ),
        actions: [
          CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: () async {
              await auth.logout();
              if (!context.mounted) return;
              Navigator.of(context)
                  .pushNamedAndRemoveUntil(AppRoutes.login, (r) => false);
            },
            child: const Icon(
              CupertinoIcons.arrow_right_square,
              color: Colors.redAccent,
            ),
          ),
        ],
      ),

      // ===================== BODY RESPONSIVE =====================
      body: LayoutBuilder(
        builder: (context, constraints) {
          final maxW = constraints.maxWidth;
          final isWide = maxW >= 700;

          final horizontalPadding = isWide ? 24.0 : 16.0;
          final contentMaxWidth = isWide ? 760.0 : maxW;

          return SafeArea(
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                12,
                horizontalPadding,
                24,
              ),
              children: [
                Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: contentMaxWidth),
                    child: const _AdminDashboardContent(),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Tách phần nội dung để AppBar + layout gọn hơn
class _AdminDashboardContent extends StatelessWidget {
  const _AdminDashboardContent();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ======================= SẢN PHẨM =======================
        _SectionHeader(title: 'Sản phẩm', icon: CupertinoIcons.cube_box),
        _AdminCardGroup(children: [
          _AdminTile(
            icon: CupertinoIcons.cube_box_fill,
            title: 'Quản lý sản phẩm',
            subtitle: 'Thêm / sửa / xóa, hình ảnh, giá, SKU',
            route: AppRoutes.adminProducts,
          ),
          _AdminTile(
            icon: CupertinoIcons.tag_fill,
            title: 'Thương hiệu',
            subtitle: 'Thêm / sửa / xóa thương hiệu',
            route: AppRoutes.adminBrands,
          ),
          _AdminTile(
            icon: CupertinoIcons.square_stack_3d_down_right_fill,
            title: 'Danh mục',
            subtitle: 'Thêm / sửa / xóa danh mục',
            route: AppRoutes.adminCategories,
          ),
        ]),

        // ======================= VẬN HÀNH =======================
        _SectionHeader(
          title: 'Vận hành',
          icon: CupertinoIcons.gear_alt_fill,
        ),
        _AdminCardGroup(children: [
          _AdminTile(
            icon: CupertinoIcons.doc_text_fill,
            title: 'Đơn hàng',
            subtitle: 'Duyệt, giao hàng, hoàn thành, hủy',
            route: AppRoutes.adminOrders,
          ),
          _AdminTile(
            icon: CupertinoIcons.person_2_fill,
            title: 'Người dùng',
            subtitle: 'Danh sách tài khoản / phân quyền',
            route: AppRoutes.adminUsers,
          ),
          _AdminTile(
            icon: CupertinoIcons.car_detailed,
            title: 'Cấu hình phí ship',
            subtitle: 'Thiết lập bảng giá theo khoảng cách',
            route: AppRoutes.adminShippingConfig,
          ),
          _AdminTile(
            icon: CupertinoIcons.building_2_fill,
            title: 'Kho & Hub',
            subtitle: 'Quản lý kho chính & kho trung chuyển',
            route: AppRoutes.adminWarehouses,
          ),
          _AdminTile.withBadge(
            icon: CupertinoIcons.headphones,
            title: 'Hỗ trợ / Ticket',
            subtitle: 'Trả lời & cập nhật trạng thái yêu cầu',
            route: AppRoutes.adminTickets,
          ),
        ]),

        // ================== MARKETING & BÁO CÁO =================
        _SectionHeader(
          title: 'Marketing & Báo cáo',
          icon: CupertinoIcons.graph_square_fill,
        ),
        _AdminCardGroup(children: [
          _AdminTile(
            icon: CupertinoIcons.photo_fill_on_rectangle_fill,
            title: 'Banner quảng cáo',
            subtitle: 'Thêm, sửa, xóa banner hiển thị trên trang chủ',
            route: AppRoutes.adminBanners,
          ),
          _AdminTile(
            icon: CupertinoIcons.gift_fill,
            title: 'Khuyến mãi / Voucher',
            subtitle: 'Thiết lập thời gian, tự động kích hoạt',
            route: AppRoutes.adminVouchers,
          ),

          // ====================== ✅✅✅ ĐÃ THÊM: VIDEO ======================
          _AdminTile(
            icon: CupertinoIcons.play_rectangle_fill,
            title: 'Video sản phẩm',
            subtitle: 'Upload video  & gắn với sản phẩm',
            route: AppRoutes.adminVideoManager, // ✅ route bạn đã tạo trong AppRoutes
          ),
          // =================================================================

          _AdminTile(
            icon: CupertinoIcons.shield_fill,
            title: 'Chính sách & Điều khoản',
            subtitle:
            'Quản lý và cập nhật nội dung hiển thị cho người dùng',
            route: AppRoutes.adminPolicies,
          ),
          _AdminTile(
            icon: CupertinoIcons.game_controller_solid,
            title: 'Mini-game Xu',
            subtitle: 'Theo dõi RTP, Xu thu/chi, số lần jackpot',
            route: AppRoutes.adminXuMiniGameStats,
          ),
          _AdminTile(
            icon: CupertinoIcons.chart_bar_square_fill,
            title: 'Thống kê & Báo cáo',
            subtitle: 'Doanh thu, sản phẩm, khách hàng',
            route: AppRoutes.adminReports,
          ),
        ]),
      ],
    );
  }
}

/// Header nhóm – responsive theo kích thước màn hình
class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  const _SectionHeader({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final isCompact = mq.size.height < 650;

    final gold = Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFFE9C46A)
        : const Color(0xFFB98B15);

    final double fontSize = isCompact ? 14.5 : 16;
    final double topPad = isCompact ? 8 : 12;
    final double bottomPad = isCompact ? 6 : 8;

    return Padding(
      padding: EdgeInsets.only(top: topPad, bottom: bottomPad),
      child: Row(
        children: [
          Icon(icon, size: 20, color: gold),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              color: gold,
              fontWeight: FontWeight.w700,
              fontSize: fontSize,
              letterSpacing: .3,
            ),
          ),
        ],
      ),
    );
  }
}

/// Card nhóm – tự scale radius / shadow theo màn hình
class _AdminCardGroup extends StatelessWidget {
  final List<Widget> children;
  const _AdminCardGroup({required this.children});

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final cs = Theme.of(context).colorScheme;
    final outline = cs.outlineVariant;

    final isCompactHeight = mq.size.height < 650;
    final isWide = mq.size.width >= 700;

    final radius = isCompactHeight ? 16.0 : 20.0;
    final bottomMargin = isCompactHeight ? 14.0 : 18.0;
    final blur = isWide ? 10.0 : 8.0;

    return Container(
      margin: EdgeInsets.only(bottom: bottomMargin),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: outline.withOpacity(
            Theme.of(context).brightness == Brightness.dark ? 0.5 : 0.8,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.black.withOpacity(.25)
                : Colors.black.withOpacity(.04),
            blurRadius: blur,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }
}

/// Tile điều hướng – tự co giãn cho màn nhỏ / lớn
class _AdminTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String route;
  final bool showBadge;

  const _AdminTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.route,
  }) : showBadge = false;

  const _AdminTile.withBadge({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.route,
  }) : showBadge = true;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final cs = Theme.of(context).colorScheme;

    final isCompactHeight = mq.size.height < 650;
    final isWide = mq.size.width >= 700;

    final double iconSize = isCompactHeight ? 22 : 24;
    final EdgeInsets contentPadding = EdgeInsets.symmetric(
      horizontal: 16,
      vertical: isCompactHeight ? 2 : 4,
    );

    final double titleSize = isCompactHeight ? 14.5 : 15.5;
    final double subtitleSize = isCompactHeight ? 12 : 13;

    final visualDensity =
    isCompactHeight ? VisualDensity.compact : VisualDensity.standard;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => Navigator.pushNamed(context, route),
      child: ListTile(
        contentPadding: contentPadding,
        visualDensity: visualDensity,
        leading: Icon(
          icon,
          color: cs.primary,
          size: iconSize,
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: cs.onSurface,
            fontSize: titleSize,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            color: cs.onSurfaceVariant,
            fontSize: subtitleSize,
          ),
        ),
        trailing: showBadge
            ? Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const _OpenTicketsBadge(),
            const SizedBox(width: 8),
            Icon(
              CupertinoIcons.chevron_forward,
              color: cs.onSurfaceVariant,
              size: isCompactHeight ? 16 : 18,
            ),
          ],
        )
            : Icon(
          CupertinoIcons.chevron_forward,
          color: cs.onSurfaceVariant,
          size: isCompactHeight ? 16 : 18,
        ),
      ),
    );
  }
}

/// Badge đếm ticket – dùng màu primaryContainer để nổi bật
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
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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
