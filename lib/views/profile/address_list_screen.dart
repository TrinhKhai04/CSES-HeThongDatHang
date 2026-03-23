import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../controllers/address_controller.dart';
import '../../controllers/auth_controller.dart';
import '../../models/app_address.dart';
import '../../routes/app_routes.dart';

/// =============================================================================
/// 📦 AddressListScreen — Apple-style, Dark/Light + responsive
/// =============================================================================
class AddressListScreen extends StatelessWidget {
  const AddressListScreen({super.key});

  // Gộp địa chỉ thành 1 dòng hiển thị
  String _fmt(AppAddress a) =>
      '${a.line1}, ${a.ward}, ${a.district}, ${a.province}';

  // Giới hạn max-width cho body trên màn to (tablet / web)
  Widget _wrapBody(BuildContext context, Widget child) {
    final w = MediaQuery.of(context).size.width;

    double maxWidth;
    if (w >= 1024) {
      maxWidth = 720;
    } else if (w >= 600) {
      maxWidth = 600;
    } else {
      maxWidth = w; // điện thoại: dùng full width
    }

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = context.read<AuthController>().user?.uid ?? '';
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    if (uid.isEmpty) {
      return Scaffold(
        backgroundColor: cs.surfaceContainerLowest,
        appBar: AppBar(
          backgroundColor: cs.surface,
          foregroundColor: cs.onSurface,
          elevation: 0,
          centerTitle: true,
          title: const Text('Địa chỉ giao hàng'),
        ),
        body: const Center(child: Text('Bạn chưa đăng nhập')),
      );
    }

    final ac = context.read<AddressController>();

    return StreamBuilder<List<AppAddress>>(
      stream: ac.streamAddresses(uid),
      builder: (context, snap) {
        Widget body;
        Widget? fab;

        if (snap.hasError) {
          body = _wrapBody(
            context,
            Padding(
              padding: const EdgeInsets.all(16),
              child: Card(
                color: cs.errorContainer,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    'Không thể tải địa chỉ:\n${snap.error}',
                    style: TextStyle(color: cs.onErrorContainer),
                  ),
                ),
              ),
            ),
          );
        } else if (snap.connectionState == ConnectionState.waiting) {
          body = const Center(child: CupertinoActivityIndicator());
        } else if (!snap.hasData) {
          body = const Center(child: Text('Không có dữ liệu.'));
        } else {
          final list = snap.data!;

          if (list.isEmpty) {
            body = _wrapBody(
              context,
              _EmptyState(
                onAdd: () =>
                    Navigator.pushNamed(context, AppRoutes.addressForm),
              ),
            );
          } else {
            body = _wrapBody(
              context,
              Column(
                children: [
                  const SizedBox(height: 12),
                  _AddressHeaderCard(),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ListView.separated(
                      padding:
                      const EdgeInsets.fromLTRB(16, 4, 16, 120),
                      itemCount: list.length,
                      separatorBuilder: (_, __) =>
                      const SizedBox(height: 10),
                      itemBuilder: (_, i) {
                        final a = list[i];
                        return _AddressCard(
                          address: a,
                          subtitle: _fmt(a),
                          // tap card = chỉnh sửa
                          onEdit: () => _editAddress(context, a),
                          // icon ... = action sheet
                          onTapMenu: () =>
                              _showActions(context, a, uid, ac),
                          // icon sao = đặt mặc định nhanh
                          onToggleDefault: () =>
                              _setDefaultQuick(context, uid, ac, a),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );

            fab = _ApplePillButton(
              label: 'Thêm địa chỉ',
              icon: CupertinoIcons.location_solid,
              onTap: () =>
                  Navigator.pushNamed(context, AppRoutes.addressForm),
            );
          }
        }

        return Scaffold(
          backgroundColor: cs.surfaceContainerLowest,
          appBar: AppBar(
            backgroundColor: cs.surface,
            foregroundColor: cs.onSurface,
            elevation: 0,
            centerTitle: true,
            leading: IconButton(
              tooltip: 'Quay lại',
              icon: Icon(
                Icons.arrow_back_ios_new,
                size: 18,
                color: cs.onSurface,
              ),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(
              'Địa chỉ giao hàng',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: cs.primary,
                letterSpacing: .2,
              ),
            ),
          ),
          body: body,
          floatingActionButtonLocation:
          FloatingActionButtonLocation.centerFloat,
          floatingActionButton: fab,
        );
      },
    );
  }

  Future<void> _setDefaultQuick(
      BuildContext context,
      String uid,
      AddressController ac,
      AppAddress a,
      ) async {
    if (a.isDefault) return; // đang là mặc định rồi => không làm gì

    HapticFeedback.lightImpact();
    await ac.setDefault(uid, a.id);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã đặt làm địa chỉ mặc định')),
      );
    }
  }

  Future<void> _editAddress(BuildContext context, AppAddress a) async {
    Navigator.pushNamed(
      context,
      AppRoutes.addressForm,
      arguments: {'address': a},
    );
  }

  Future<void> _showActions(
      BuildContext context,
      AppAddress a,
      String uid,
      AddressController ac,
      ) async {
    final result = await showCupertinoModalPopup<String>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: const Text('Tác vụ'),
        message: Text('${a.name} · ${a.phone}'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(ctx, 'edit'),
            child: const Text('Chỉnh sửa'),
          ),
          if (!a.isDefault)
            CupertinoActionSheetAction(
              onPressed: () => Navigator.pop(ctx, 'default'),
              child: const Text('Đặt làm mặc định'),
            ),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(ctx, 'delete'),
            child: const Text('Xoá địa chỉ'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Huỷ'),
        ),
      ),
    );

    if (result == null) return;

    if (result == 'edit') {
      _editAddress(context, a);
    } else if (result == 'default') {
      await _setDefaultQuick(context, uid, ac, a);
    } else if (result == 'delete') {
      final ok = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Xoá địa chỉ?'),
          content:
          const Text('Bạn chắc chắn muốn xoá địa chỉ này?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Huỷ'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Xoá'),
            ),
          ],
        ),
      ) ??
          false;
      if (ok) await ac.deleteAddress(uid, a.id);
    }
  }
}

/// -----------------------------------------------------------------------------
/// 🔹 Card info nhỏ ở đầu danh sách
/// -----------------------------------------------------------------------------
class _AddressHeaderCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: cs.outlineVariant.withOpacity(0.5),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: cs.primary.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                CupertinoIcons.paperplane_fill,
                size: 18,
                color: cs.primary,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Chọn địa chỉ giao hàng mặc định',
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: cs.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Bạn vẫn có thể đổi địa chỉ khác ở bước thanh toán.',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// -----------------------------------------------------------------------------
/// 🧩 Address Card — Apple-style, responsive + star animation
/// -----------------------------------------------------------------------------
class _AddressCard extends StatelessWidget {
  final AppAddress address;
  final String subtitle;
  final VoidCallback onEdit;
  final VoidCallback onTapMenu;
  final VoidCallback onToggleDefault;

  const _AddressCard({
    required this.address,
    required this.subtitle,
    required this.onEdit,
    required this.onTapMenu,
    required this.onToggleDefault,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final borderColor = address.isDefault
        ? cs.primary.withOpacity(0.65)
        : cs.outlineVariant.withOpacity(isDark ? 0.6 : 0.8);

    final cardColor = address.isDefault
        ? cs.primary.withOpacity(isDark ? 0.18 : 0.06)
        : cs.surface;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 340;
        final isWide = constraints.maxWidth > 480;

        final double titleSize =
        isCompact ? 14.5 : (isWide ? 16.0 : 15.0);
        final double subtitleSize =
        isCompact ? 13.0 : (isWide ? 14.0 : 13.5);
        final double paddingV =
        isCompact ? 10.0 : (isWide ? 14.0 : 12.0);
        final double paddingH =
        isCompact ? 10.0 : (isWide ? 14.0 : 12.0);
        final double railHeight =
        isCompact ? 40.0 : (isWide ? 48.0 : 44.0);
        final double railGap = isCompact ? 6.0 : 8.0;
        final double badgePaddingH = isCompact ? 6.0 : 8.0;
        final double badgePaddingV = isCompact ? 2.5 : 3.0;

        return Card(
          elevation: isDark ? 0 : 1,
          margin: EdgeInsets.zero,
          color: cardColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: borderColor,
              width: address.isDefault ? 1.1 : 0.7,
            ),
          ),
          child: InkWell(
            // tap cả card = chỉnh sửa
            onTap: onEdit,
            // 👇 SỬA LẠI: truyền BorderRadius trực tiếp, không dùng RoundedRectangleBorder().borderRadius
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding:
              EdgeInsets.fromLTRB(paddingH, paddingV, 4, paddingV),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Thanh màu + icon tạo điểm nhấn
                  Column(
                    children: [
                      Container(
                        width: 3,
                        height: railHeight,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(999),
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: address.isDefault
                                ? [
                              cs.primary,
                              cs.primary.withOpacity(0.5),
                            ]
                                : [
                              cs.outlineVariant.withOpacity(.6),
                              cs.outlineVariant.withOpacity(.2),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(height: railGap),
                      Icon(
                        CupertinoIcons.location,
                        size: 18,
                        color: cs.onSurfaceVariant,
                      ),
                    ],
                  ),
                  const SizedBox(width: 12),

                  // Nội dung chính
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${address.name} · ${address.phone}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: cs.onSurface,
                                  fontSize: titleSize,
                                ),
                              ),
                            ),
                            if (address.isDefault)
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: badgePaddingH,
                                  vertical: badgePaddingV,
                                ),
                                decoration: BoxDecoration(
                                  color: cs.primaryContainer
                                      .withOpacity(.9),
                                  borderRadius:
                                  BorderRadius.circular(999),
                                  border: Border.all(
                                    color:
                                    cs.primary.withOpacity(.4),
                                  ),
                                ),
                                child: Text(
                                  'Mặc định',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: cs.onPrimaryContainer,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: cs.onSurfaceVariant,
                            height: 1.35,
                            fontSize: subtitleSize,
                          ),
                        ),
                        if (address.isDefault) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Địa chỉ mặc định',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: cs.primary.withOpacity(0.9),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  // Ngôi sao + nút “…” mở ActionSheet
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedScale(
                        scale: address.isDefault ? 1.15 : 1.0,
                        duration:
                        const Duration(milliseconds: 160),
                        curve: Curves.easeOutBack,
                        child: IconButton(
                          tooltip: address.isDefault
                              ? 'Địa chỉ mặc định'
                              : 'Đặt làm mặc định',
                          splashRadius: 20,
                          icon: Icon(
                            address.isDefault
                                ? CupertinoIcons.star_fill
                                : CupertinoIcons.star,
                            size: 18,
                            color: address.isDefault
                                ? cs.primary
                                : cs.onSurfaceVariant
                                .withOpacity(0.7),
                          ),
                          onPressed: () {
                            if (!address.isDefault) {
                              onToggleDefault();
                            }
                          },
                        ),
                      ),
                      IconButton(
                        tooltip: 'Tác vụ',
                        splashRadius: 20,
                        icon: Icon(
                          CupertinoIcons.ellipsis_vertical,
                          size: 18,
                          color: cs.onSurfaceVariant,
                        ),
                        onPressed: onTapMenu,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}


/// -----------------------------------------------------------------------------
/// ⌘ Nút pill xanh Apple tái sử dụng
/// -----------------------------------------------------------------------------
class _ApplePillButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _ApplePillButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            cs.primary,
            cs.primary.withOpacity(0.85),
          ],
        ),
        boxShadow: [
          BoxShadow(
            blurRadius: 18,
            offset: const Offset(0, 8),
            color: cs.primary.withOpacity(0.35),
          ),
        ],
      ),
      child: CupertinoButton(
        padding:
        const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        onPressed: onTap,
        minSize: 0,
        borderRadius: BorderRadius.circular(28),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: cs.onPrimary),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: cs.onPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// -----------------------------------------------------------------------------
/// 🌤️ Empty state gọn gàng (Dark/Light, auto fit width)
/// -----------------------------------------------------------------------------
class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Container(
          padding:
          const EdgeInsets.fromLTRB(20, 20, 20, 18),
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: cs.outlineVariant.withOpacity(
                theme.brightness == Brightness.dark ? 0.6 : 0.4,
              ),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: cs.primary.withOpacity(.08),
                ),
                child: Icon(
                  CupertinoIcons.map_pin_ellipse,
                  size: 32,
                  color: cs.primary,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Chưa có địa chỉ',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: cs.onSurface,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Thêm địa chỉ để giao hàng nhanh chóng và chính xác hơn.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: cs.onSurfaceVariant,
                  fontSize: 13.5,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),
              _ApplePillButton(
                label: 'Thêm địa chỉ',
                icon: CupertinoIcons.location_solid,
                onTap: onAdd,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
