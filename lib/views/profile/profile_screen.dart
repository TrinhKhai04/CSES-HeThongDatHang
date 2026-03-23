import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../controllers/auth_controller.dart';
import '../../../controllers/address_controller.dart';
import '../../../controllers/xu_controller.dart';
import '../../../models/app_address.dart';
import '../../../routes/app_routes.dart';

/// ============================================================================
/// 🧑‍💼 ProfileScreen — Apple-style, Dark/Light đầy đủ
/// ============================================================================
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key, this.showBack = false});
  final bool showBack;

  /// Giới hạn max-width cho UI trên màn lớn (tablet / web)
  Widget _wrap(BuildContext context, Widget child) {
    final width = MediaQuery.of(context).size.width;
    const maxWidth = 520.0;

    if (width <= maxWidth + 32) {
      // Điện thoại bình thường -> giữ full width với padding 16
      return child;
    }

    // Màn lớn -> gom nội dung vào giữa cho gọn, giống iPad / web
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final user = auth.user;
    final profile = auth.profile ?? {};

    if (user == null) {
      return const Scaffold(body: Center(child: Text('Bạn chưa đăng nhập')));
    }

    final email = (profile['email'] ?? user.email ?? '') as String;
    final name = (profile['name'] ?? '') as String;
    final phone = (profile['phone'] ?? '') as String;

    final bg = _Colors.systemGroupedBackground(context);

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // =================== APP BAR ===================
            if (showBack)
              SliverAppBar(
                pinned: true,
                backgroundColor: bg,
                elevation: 0,
                leading: const BackButton(),
                centerTitle: true,
                title: const Text('Tài khoản'),
              ),

            // =================== HEADER ===================
            SliverToBoxAdapter(
              child: _wrap(
                context,
                _ProfileHeader(
                  name: name,
                  email: email,
                  phone: phone,
                ),
              ),
            ),

            // =================== XU CHECK-IN ===================
            SliverToBoxAdapter(
              child: _wrap(
                context,
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 10, 16, 4),
                  child: _XuCheckinCard(),
                ),
              ),
            ),

            // =================== THÔNG TIN CÁ NHÂN ===================
            SliverToBoxAdapter(
              child: _wrap(
                context,
                _Section(
                  header: 'Thông tin cá nhân',
                  children: [
                    _RowItem(
                      leading: const Icon(CupertinoIcons.person),
                      label: 'Họ & tên',
                      value: name.isEmpty ? 'Chưa cập nhật' : name,
                      onTap: () => _editField(
                        context,
                        title: 'Họ & tên',
                        initial: name,
                        hint: 'Nhập họ và tên',
                        fieldKey: 'name',
                      ),
                    ),
                    _RowItem(
                      leading: const Icon(CupertinoIcons.phone),
                      label: 'Số điện thoại',
                      value: phone.isEmpty ? 'Thêm số điện thoại' : phone,
                      onTap: () => _editField(
                        context,
                        title: 'Số điện thoại',
                        initial: phone,
                        hint: '09xx...',
                        keyboardType: TextInputType.phone,
                        fieldKey: 'phone',
                      ),
                    ),
                    _RowItem(
                      leading: const Icon(CupertinoIcons.house),
                      label: 'Địa chỉ',
                      trailing: const _DefaultAddressPreview(),
                      onTap: () =>
                          Navigator.pushNamed(context, AppRoutes.addresses),
                    ),
                  ],
                ),
              ),
            ),

            // =================== BẢO MẬT & PHIÊN ===================
            SliverToBoxAdapter(
              child: _wrap(
                context,
                _Section(
                  header: 'Bảo mật & phiên',
                  children: [
                    _RowItem(
                      leading: const Icon(CupertinoIcons.lock_shield),
                      label: 'Đổi mật khẩu',
                      onTap: () => Navigator.pushNamed(
                        context,
                        AppRoutes.changePassword,
                      ),
                    ),
                    _RowItem(
                      leading: const Icon(CupertinoIcons.square_arrow_right),
                      label: 'Đăng xuất',
                      isDestructive: true,
                      showChevron: false,
                      onTap: () async {
                        final ok = await _confirm(
                          context,
                          title: 'Đăng xuất?',
                          message:
                          'Bạn có chắc muốn đăng xuất khỏi tài khoản này?',
                          okText: 'Đăng xuất',
                        );
                        if (ok == true) {
                          await context.read<AuthController>().logout();
                          if (context.mounted) {
                            Navigator.pushNamedAndRemoveUntil(
                              context,
                              AppRoutes.login,
                                  (r) => false,
                            );
                          }
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),

            // =================== KHÁC ===================
            SliverToBoxAdapter(
              child: _wrap(
                context,
                _Section(
                  header: 'Khác',
                  children: [
                    _RowItem(
                      leading: const Icon(CupertinoIcons.doc_text_search),
                      label: 'Tra cứu đơn hàng',
                      onTap: () => Navigator.pushNamed(
                        context,
                        AppRoutes.userOrderLookup,
                      ),
                    ),
                    _RowItem(
                      leading: const Icon(CupertinoIcons.doc_text),
                      label: 'Chính sách & điều khoản',
                      onTap: () => Navigator.pushNamed(
                        context,
                        AppRoutes.policyTerms,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            SliverToBoxAdapter(
              child: _wrap(
                context,
                const SizedBox(height: 24),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ============================================================================
/// 🎛 HEADER PROFILE CARD (responsive avatar + padding)
/// ============================================================================
class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.name,
    required this.email,
    required this.phone,
  });

  final String name;
  final String email;
  final String phone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final displayName = name.isEmpty ? 'Tài khoản CSES' : name;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 360;
        final avatarSize = isCompact ? 60.0 : 72.0;
        final titleSize = isCompact ? 20.0 : 22.0;
        final paddingH = isCompact ? 14.0 : 18.0;
        final paddingV = isCompact ? 14.0 : 18.0;

        return Container(
          margin: const EdgeInsets.fromLTRB(16, 16, 16, 10),
          padding: EdgeInsets.fromLTRB(paddingH, paddingV, paddingH, paddingV),
          decoration: BoxDecoration(
            gradient: isDark
                ? const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF020617),
                Color(0xFF020617),
              ],
            )
                : const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFF9FAFB), Color(0xFFE5E7EB)],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isDark
                  ? Colors.white.withOpacity(0.08)
                  : Colors.black.withOpacity(0.04),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.55 : 0.08),
                blurRadius: 26,
                offset: const Offset(0, 18),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _Avatar(
                initial: _initial(displayName, email),
                size: avatarSize,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontSize: titleSize,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4,
                        color:
                        isDark ? Colors.white : const Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 6),

                    // Email
                    if (email.isNotEmpty)
                      Row(
                        children: [
                          const Icon(
                            CupertinoIcons.envelope_fill,
                            size: 14,
                            color: CupertinoColors.systemGrey,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              email,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: _Text.secondary(context).copyWith(
                                fontSize: 13,
                                color: isDark
                                    ? Colors.white70
                                    : const Color(0xFF4B5563),
                              ),
                            ),
                          ),
                        ],
                      ),

                    // Phone
                    if (phone.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(
                            CupertinoIcons.phone_fill,
                            size: 14,
                            color: CupertinoColors.systemGrey2,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              phone,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: _Text.secondary(context).copyWith(
                                fontSize: 13,
                                color: isDark
                                    ? Colors.white70
                                    : const Color(0xFF4B5563),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],

                    const SizedBox(height: 10),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  static String _initial(String? name, String email) {
    final src = ((name ?? '').trim().isEmpty ? email : name!).trim();
    if (src.isEmpty) return 'U';
    return src.characters.first.toUpperCase();
  }
}

// ============================================================================
// 🏠 ĐỊA CHỈ MẶC ĐỊNH
// ============================================================================
class _DefaultAddressPreview extends StatelessWidget {
  const _DefaultAddressPreview();

  @override
  Widget build(BuildContext context) {
    final uid = context.read<AuthController>().user?.uid ?? '';
    if (uid.isEmpty) return const Text('Thêm địa chỉ');

    return StreamBuilder<List<AppAddress>>(
      stream: context.read<AddressController>().streamAddresses(uid),
      builder: (_, snap) {
        if (!snap.hasData) return const SizedBox.shrink();
        final list = snap.data!;
        if (list.isEmpty) return const Text('Thêm địa chỉ');

        final def =
        list.firstWhere((e) => e.isDefault, orElse: () => list.first);
        final preview =
            '${def.line1}, ${def.ward}, ${def.district}, ${def.province}';

        return Text(
          preview,
          textAlign: TextAlign.right,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: _Text.secondary(context),
        );
      },
    );
  }
}

// ============================================================================
// 🔥 XU CHECK-IN CARD
// ============================================================================
class _XuCheckinCard extends StatefulWidget {
  const _XuCheckinCard({super.key});

  @override
  State<_XuCheckinCard> createState() => _XuCheckinCardState();
}

class _XuCheckinCardState extends State<_XuCheckinCard> {
  bool _loaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_loaded) {
      final uid = context.read<AuthController>().user?.uid;
      if (uid != null && uid.isNotEmpty) {
        context.read<XuController>().load(uid);
      }
      _loaded = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Consumer<XuController>(
      builder: (ctx, xu, _) {
        final loading = xu.isLoading;
        final balance = xu.balance;
        final checkedIn = xu.checkedInToday;
        final dailyReward = xu.dailyReward;
        final streak = xu.streak;

        Widget buildTexts() {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Flexible(
                    child: Text(
                      'CSES Xu',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (streak > 0)
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(999),
                            color: Colors.white.withOpacity(0.18),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                'Chuỗi ',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.white,
                                ),
                              ),
                              Text(
                                '$streak ngày',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                              const Text(' 🔥', style: TextStyle(fontSize: 13)),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '$balance xu khả dụng',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                  color: Colors.white.withOpacity(0.9),
                ),
              ),
              const SizedBox(height: 2),
              RichText(
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                text: TextSpan(
                  style: TextStyle(
                    fontSize: 12.5,
                    color: Colors.white.withOpacity(0.9),
                  ),
                  children: [
                    TextSpan(
                      text: checkedIn
                          ? 'Bạn đã điểm danh hôm nay · '
                          : 'Điểm danh hôm nay nhận ',
                    ),
                    TextSpan(
                      text: '+$dailyReward xu',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ],
          );
        }

        final actionButton = SizedBox(
          height: 34,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor:
                isDark ? cs.primary : const Color(0xFF1D4ED8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 8,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
                elevation: 0,
              ),
              onPressed: loading
                  ? null
                  : () async {
                HapticFeedback.lightImpact();
                try {
                  if (!checkedIn) {
                    await xu.checkInToday(context);
                  } else {
                    Navigator.pushNamed(context, AppRoutes.xuRewards);
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(e.toString())),
                  );
                }
              },
              child: loading
                  ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
                  : Text(
                checkedIn ? 'Xem ưu đãi' : 'Điểm danh ngay',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        );

        return LayoutBuilder(
          builder: (context, constraints) {
            final isCompact = constraints.maxWidth < 360;
            final logoSize = isCompact ? 40.0 : 48.0;
            final iconSize = isCompact ? 22.0 : 26.0;
            final radius = isCompact ? 18.0 : 20.0;
            final verticalPadding = isCompact ? 12.0 : 14.0;

            final logo = Container(
              width: logoSize,
              height: logoSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.96),
              ),
              child: Center(
                child: Icon(
                  Icons.monetization_on_rounded,
                  color: const Color(0xFF2563EB),
                  size: iconSize,
                ),
              ),
            );

            return InkWell(
              borderRadius: BorderRadius.circular(radius),
              onTap: () {
                Navigator.pushNamed(context, AppRoutes.xuRewards);
              },
              splashColor: Colors.transparent,
              highlightColor: Colors.transparent,
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: verticalPadding,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(radius),
                  gradient: isDark
                      ? const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF0F172A), Color(0xFF111827)],
                  )
                      : const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF0EA5E9), Color(0xFF2563EB)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color:
                      Colors.black.withOpacity(isDark ? 0.4 : 0.18),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: isCompact
                // Màn nhỏ: logo + text trên, nút xuống dưới
                    ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        logo,
                        const SizedBox(width: 14),
                        Expanded(child: buildTexts()),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: actionButton,
                    ),
                  ],
                )
                // Màn rộng: layout ngang
                    : Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    logo,
                    const SizedBox(width: 14),
                    Expanded(child: buildTexts()),
                    const SizedBox(width: 10),
                    actionButton,
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// ============================================================================
// 🧱 SECTION CONTAINER
// ============================================================================
class _Section extends StatelessWidget {
  const _Section({required this.children, this.header});
  final List<Widget> children;
  final String? header;

  @override
  Widget build(BuildContext context) {
    final bg = _Colors.systemGroupedBackground(context);
    final card = _Colors.secondarySystemBackground(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (header != null)
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 6),
              child: Text(header!, style: _Text.sectionHeader(context)),
            ),
          DecoratedBox(
            decoration: BoxDecoration(
              color: card,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(
                    Theme.of(context).brightness == Brightness.dark
                        ? 0.4
                        : 0.04,
                  ),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Column(children: _withDividers(children, bg)),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _withDividers(List<Widget> tiles, Color color) {
    final result = <Widget>[];
    for (var i = 0; i < tiles.length; i++) {
      result.add(tiles[i]);
      if (i != tiles.length - 1) {
        result.add(
          Divider(height: 1, thickness: 0.5, color: color.withOpacity(.8)),
        );
      }
    }
    return result;
  }
}

// ============================================================================
// 🔹 ROW ITEM
// ============================================================================
class _RowItem extends StatelessWidget {
  const _RowItem({
    required this.label,
    this.value,
    this.leading,
    this.onTap,
    this.isDestructive = false,
    this.showChevron = true,
    this.trailing,
  });

  final String label;
  final String? value;
  final Widget? leading;
  final VoidCallback? onTap;
  final bool isDestructive;
  final bool showChevron;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final color = isDestructive
        ? _Colors.destructive(context)
        : _Colors.primaryText(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap == null
            ? null
            : () {
          HapticFeedback.selectionClick();
          Future.delayed(const Duration(milliseconds: 80), onTap);
        },
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          child: Row(
            children: [
              if (leading != null) ...[
                IconTheme.merge(
                  data: IconThemeData(color: color),
                  child: leading!,
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight:
                    isDestructive ? FontWeight.w600 : FontWeight.w500,
                    color: color,
                  ),
                ),
              ),
              if (trailing != null)
                Flexible(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: trailing!,
                  ),
                )
              else if (value != null)
                Flexible(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      value!,
                      textAlign: TextAlign.right,
                      overflow: TextOverflow.ellipsis,
                      style: _Text.secondary(context),
                    ),
                  ),
                ),
              if (showChevron)
                const Padding(
                  padding: EdgeInsets.only(left: 6),
                  child: Icon(
                    CupertinoIcons.chevron_forward,
                    size: 16,
                    color: CupertinoColors.systemGrey3,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// 👤 AVATAR (responsive size)
// ============================================================================
class _Avatar extends StatelessWidget {
  const _Avatar({required this.initial, this.size = 70});
  final String initial;
  final double size;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final border = isDark ? Colors.white12 : Colors.black12;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: isDark
            ? const LinearGradient(
          colors: [Color(0xFF2C2C2E), Color(0xFF18181B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        )
            : const LinearGradient(
          colors: [Color(0xFFcfd9df), Color(0xFFe2ebf0)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: border, width: 1),
      ),
      child: Center(
        child: Text(
          initial,
          style: TextStyle(
            fontSize: size * 0.4,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// 🎨 MÀU & TEXT STYLE
// ============================================================================
class _Colors {
  static Color systemGroupedBackground(BuildContext c) =>
      CupertinoDynamicColor.resolve(
          CupertinoColors.systemGroupedBackground, c);
  static Color secondarySystemBackground(BuildContext c) =>
      CupertinoDynamicColor.resolve(
          CupertinoColors.secondarySystemBackground, c);
  static Color primaryText(BuildContext c) =>
      CupertinoDynamicColor.resolve(CupertinoColors.label, c);
  static Color tertiary(BuildContext c) =>
      CupertinoDynamicColor.resolve(CupertinoColors.tertiaryLabel, c);
  static Color destructive(BuildContext c) =>
      CupertinoDynamicColor.resolve(CupertinoColors.systemRed, c);
}

class _Text {
  static TextStyle secondary(BuildContext c) =>
      TextStyle(fontSize: 14, color: _Colors.tertiary(c));
  static TextStyle sectionHeader(BuildContext c) => TextStyle(
    fontSize: 13,
    color: _Colors.tertiary(c),
    fontWeight: FontWeight.w600,
    letterSpacing: .2,
  );
}

// ============================================================================
// 📝 HỘP NHẬP & XÁC NHẬN
// ============================================================================
Future<void> _editField(
    BuildContext context, {
      required String title,
      required String initial,
      required String hint,
      required String fieldKey,
      TextInputType? keyboardType,
      int maxLines = 1,
    }) async {
  final ctl = TextEditingController(text: initial);
  final nav = Navigator.of(context);

  await showCupertinoModalPopup(
    context: context,
    builder: (ctx) => CupertinoActionSheet(
      title: Text(title),
      message: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: CupertinoTextField(
          controller: ctl,
          maxLines: maxLines,
          keyboardType: keyboardType,
          placeholder: hint,
          autofocus: true,
        ),
      ),
      actions: [
        CupertinoActionSheetAction(
          onPressed: () async {
            HapticFeedback.lightImpact();
            final v = ctl.text.trim();
            final auth = context.read<AuthController>();
            final uid = auth.user?.uid;
            if (uid != null) {
              await auth.updateProfile(uid, {fieldKey: v});
              await auth.refreshProfile();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('✅ Đã lưu thay đổi')),
              );
            }
            nav.pop();
          },
          child: const Text('Lưu'),
        ),
      ],
      cancelButton: CupertinoActionSheetAction(
        isDefaultAction: true,
        onPressed: () => nav.pop(),
        child: const Text('Hủy'),
      ),
    ),
  );
}

Future<bool?> _confirm(
    BuildContext context, {
      required String title,
      required String message,
      String okText = 'OK',
    }) {
  return showCupertinoDialog<bool>(
    context: context,
    builder: (ctx) => CupertinoAlertDialog(
      title: Text(title),
      content: Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Text(message),
      ),
      actions: [
        CupertinoDialogAction(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Hủy'),
        ),
        CupertinoDialogAction(
          isDestructiveAction: true,
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(okText),
        ),
      ],
    ),
  );
}
