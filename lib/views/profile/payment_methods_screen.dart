import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/settings_controller.dart';
import '../../routes/app_routes.dart'; // màn Điều khoản

class PaymentMethodsScreen extends StatelessWidget {
  const PaymentMethodsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    // Nền kiểu iOS grouped
    final bg = isDark ? const Color(0xFF000000) : const Color(0xFFF2F2F7);
    final cardBg = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    final borderCol =
    isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E7EB);
    final dividerCol =
    isDark ? const Color(0x332C2C2E) : const Color(0x1A000000);
    final headText =
    isDark ? const Color(0xFF98989F) : const Color(0xFF6B7280);

    final settings = context.watch<SettingsController>();
    final selected = settings.paymentMethod;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: bg,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(
            CupertinoIcons.back,
            color: cs.onSurface,
          ),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: const Text(
          'Phương thức thanh toán',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.2,
          ),
        ),
      ),
      body: SafeArea(
        bottom: true,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          children: [
            // ───── Intro info card ─────
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: borderCol.withOpacity(isDark ? 0.6 : 0.8)),
                boxShadow: isDark
                    ? null
                    : const [
                  BoxShadow(
                    blurRadius: 14,
                    offset: Offset(0, 6),
                    color: Color(0x08000000),
                  ),
                ],
                gradient: isDark
                    ? null
                    : const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFFF9FAFB),
                    Color(0xFFF3F4F6),
                  ],
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: cs.primary.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Icon(
                      CupertinoIcons.info,
                      size: 16,
                      color: cs.primary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Chọn phương thức thanh toán mặc định khi đặt hàng. '
                          'Bạn vẫn có thể đổi lại ở bước thanh toán.',
                      style: TextStyle(
                        fontSize: 13,
                        color: headText,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // === COD ===
            const _SectionLabel(text: 'Thanh toán khi nhận hàng'),
            const SizedBox(height: 4),
            _GroupCard(
              cardBg: cardBg,
              borderCol: borderCol,
              dividerCol: dividerCol,
              children: [
                _PaymentTile(
                  title: 'Thanh toán khi nhận hàng (COD)',
                  subtitle:
                  'Phổ biến, thanh toán trực tiếp cho shipper khi nhận hàng.',
                  icon: CupertinoIcons.money_dollar_circle_fill,
                  iconColor: const Color(0xFF10B981),
                  selected: selected == PaymentMethod.cod,
                  badgeText: 'Khuyên dùng',
                  badgeColor: const Color(0xFFF97316),
                  showDefaultBadge: true,
                  onTap: () async {
                    await context
                        .read<SettingsController>()
                        .setPaymentMethod(PaymentMethod.cod);
                    if (context.mounted) Navigator.pop(context);
                  },
                ),
              ],
            ),

            const SizedBox(height: 20),

            // === Online ===
            const _SectionLabel(text: 'Thanh toán online'),
            const SizedBox(height: 4),
            _GroupCard(
              cardBg: cardBg,
              borderCol: borderCol,
              dividerCol: dividerCol,
              children: [
                _PaymentTile(
                  title: 'Chuyển khoản ngân hàng',
                  subtitle:
                  'Chuyển khoản theo thông tin tài khoản của CSES.',
                  icon: CupertinoIcons.building_2_fill,
                  iconColor: cs.primary,
                  selected: selected == PaymentMethod.bankTransfer,
                  badgeText: 'Demo',
                  badgeColor:
                  cs.secondary.withValues(alpha: isDark ? 0.85 : 1.0),
                  onTap: () async {
                    await context
                        .read<SettingsController>()
                        .setPaymentMethod(PaymentMethod.bankTransfer);
                    if (context.mounted) Navigator.pop(context);
                  },
                ),
                _PaymentTile(
                  title: 'Ví MoMo',
                  subtitle: 'Thanh toán nhanh qua ví MoMo.',
                  icon: CupertinoIcons.qrcode_viewfinder,
                  iconColor: const Color(0xFFE11D48),
                  selected: selected == PaymentMethod.momo,
                  badgeText: 'Demo',
                  badgeColor:
                  cs.secondary.withValues(alpha: isDark ? 0.85 : 1.0),
                  onTap: () async {
                    await context
                        .read<SettingsController>()
                        .setPaymentMethod(PaymentMethod.momo);
                    if (context.mounted) Navigator.pop(context);
                  },
                ),
              ],
            ),

            const SizedBox(height: 22),

            // === Điều khoản ===
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: borderCol.withOpacity(isDark ? 0.7 : 0.9)),
                boxShadow: isDark
                    ? null
                    : const [
                  BoxShadow(
                    color: Color(0x08000000),
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: cs.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(7),
                        ),
                        child: Icon(
                          CupertinoIcons.shield_lefthalf_fill,
                          size: 14,
                          color: cs.primary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Điều khoản & miễn trừ trách nhiệm',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: cs.onSurface,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Các phương thức chuyển khoản / ví điện tử hiện chỉ mang tính '
                        'chất hướng dẫn. CSES không chịu trách nhiệm trong trường hợp '
                        'bạn chuyển sai số tài khoản, sai nội dung hoặc sai số tiền. '
                        'Vui lòng kiểm tra kỹ thông tin trước khi xác nhận.',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.35,
                      color: headText,
                    ),
                  ),
                  const SizedBox(height: 6),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      Navigator.pushNamed(context, AppRoutes.policyTerms);
                    },
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Xem chi tiết Điều khoản & Chính sách thanh toán',
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.3,
                            color: cs.primary,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          CupertinoIcons.chevron_right,
                          size: 12,
                          color: cs.primary,
                        ),
                      ],
                    ),
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

// ================= Section label =================

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel({required this.text});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final headText =
    isDark ? const Color(0xFF98989F) : const Color(0xFF6B7280);

    return Padding(
      padding: const EdgeInsets.only(left: 2, bottom: 4, top: 6),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.1,
          color: headText,
        ),
      ),
    );
  }
}

// ================= Group card =================

class _GroupCard extends StatelessWidget {
  final List<Widget> children;
  final Color cardBg;
  final Color borderCol;
  final Color dividerCol;

  const _GroupCard({
    required this.children,
    required this.cardBg,
    required this.borderCol,
    required this.dividerCol,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderCol.withOpacity(isDark ? 0.7 : 0.9)),
        boxShadow: isDark
            ? null
            : const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: _withDividers(children, dividerCol),
      ),
    );
  }

  List<Widget> _withDividers(List<Widget> tiles, Color dividerCol) {
    final out = <Widget>[];
    for (int i = 0; i < tiles.length; i++) {
      out.add(tiles[i]);
      if (i != tiles.length - 1) {
        out.add(Divider(
          height: 1,
          thickness: 0.5,
          indent: 56, // thụt vào để không cắt icon
          color: dividerCol,
        ));
      }
    }
    return out;
  }
}

// ================= Tile =================

class _PaymentTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconColor;
  final bool selected;
  final String? badgeText;
  final Color? badgeColor;
  final bool showDefaultBadge;
  final VoidCallback onTap;

  const _PaymentTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    required this.selected,
    required this.onTap,
    this.badgeText,
    this.badgeColor,
    this.showDefaultBadge = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        highlightColor: cs.primary.withValues(alpha: 0.06),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: selected
                ? cs.primary.withValues(alpha: 0.04)
                : Colors.transparent,
            border: Border.all(
              color: selected
                  ? cs.primary.withValues(alpha: 0.40)
                  : Colors.transparent,
              width: 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // icon
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(11),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      iconColor.withValues(alpha: 0.18),
                      iconColor.withValues(alpha: 0.06),
                    ],
                  ),
                ),
                child: Icon(
                  icon,
                  size: 20,
                  color: iconColor,
                ),
              ),
              const SizedBox(width: 12),
              // nội dung + badge
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            style: TextStyle(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w600,
                              letterSpacing: -0.2,
                              color: cs.onSurface,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        if (showDefaultBadge && selected)
                          _pill(
                            text: 'Mặc định',
                            bg: cs.primary.withValues(alpha: 0.12),
                            fg: cs.primary,
                          ),
                        if (badgeText != null && badgeColor != null) ...[
                          const SizedBox(width: 4),
                          _pill(
                            text: badgeText!,
                            bg: badgeColor!.withValues(alpha: 0.10),
                            fg: badgeColor!,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.3,
                        color: cs.onSurface.withValues(alpha: 0.65),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // radio / check
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                transitionBuilder: (child, anim) => ScaleTransition(
                  scale: anim,
                  child: child,
                ),
                child: Icon(
                  selected
                      ? CupertinoIcons.checkmark_circle_fill
                      : CupertinoIcons.circle,
                  key: ValueKey(selected),
                  size: 22,
                  color: selected
                      ? cs.primary
                      : cs.onSurface.withValues(alpha: 0.28),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pill({
    required String text,
    required Color bg,
    required Color fg,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: fg,
        ),
      ),
    );
  }
}
