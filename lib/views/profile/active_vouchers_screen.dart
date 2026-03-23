import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../models/voucher.dart';
import '../../controllers/cart_controller.dart';

class ActiveVouchersScreen extends StatelessWidget {
  const ActiveVouchersScreen({super.key});

  String _fmt(int? millis) {
    if (millis == null) return '';
    final d = DateTime.fromMillisecondsSinceEpoch(millis);
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)}/${d.year} ${two(d.hour)}:${two(d.minute)}';
  }

  String _vnd(num n) {
    final s = n.toStringAsFixed(0);
    final b = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      final r = s.length - i;
      b.write(s[i]);
      if (r > 1 && r % 3 == 1) b.write(',');
    }
    return '₫${b.toString()}';
  }

  @override
  Widget build(BuildContext context) {
    final subtotal = context.watch<CartController>().subtotal;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final media = MediaQuery.of(context);
    final size = media.size;
    final textScale = media.textScaleFactor;

    final isTablet = size.width >= 600;
    final isVeryNarrow = size.width < 340;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Khuyến mãi / Voucher'),
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('vouchers').snapshots(),
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Lỗi tải voucher: ${snap.error}'),
              ),
            );
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final all = snap.data!.docs
              .map((d) => Voucher.fromMap({'id': d.id, ...d.data()}))
              .toList();

          // Chỉ lấy voucher đang hiệu lực
          final activeNow = all.where((v) => v.isActiveNow).toList();
          if (activeNow.isEmpty) {
            return const Center(child: Text('Chưa có voucher hiệu lực.'));
          }

          bool meetMin(Voucher v) =>
              v.minSubtotal == null || subtotal >= v.minSubtotal!;

          final usable = activeNow.where(meetMin).toList();
          final notEnough = activeNow.where((v) => !meetMin(v)).toList();

          // ---------- Widget tile voucher ----------
          Widget buildTile(Voucher v, {required bool enabled}) {
            final typeText = v.isPercent
                ? 'Giảm ${(v.discount * 100).toStringAsFixed(0)}%'
                : 'Giảm ${_vnd(v.discount)}';
            final timeText = [
              if (v.startAt != null) 'Bắt đầu: ${_fmt(v.startAt)}',
              if (v.endAt != null) 'Kết thúc: ${_fmt(v.endAt)}',
            ].join('  →  ');

            final rem = v.remaining; // null = vô hạn
            final remText = rem == null ? 'Vô hạn' : 'Còn $rem lượt';

            final isOutOfStock = rem != null && rem <= 0;
            final canPress = enabled && !isOutOfStock;

            final highlight = canPress;
            final baseBg = highlight
                ? cs.primaryContainer
                .withOpacity(theme.brightness == Brightness.dark ? 0.55 : 1.0)
                : cs.surfaceVariant
                .withOpacity(theme.brightness == Brightness.dark ? 0.6 : 0.7);

            final borderColor = highlight
                ? cs.primary.withOpacity(0.45)
                : cs.outlineVariant.withOpacity(0.55);

            return LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                final isCompact = width < 360 || textScale > 1.15;
                final isWide = width > 420 || isTablet;

                final stripWidth = isCompact
                    ? 64.0
                    : (isWide ? 82.0 : 72.0);
                final radius = isCompact ? 14.0 : 18.0;
                final cardPadding =
                EdgeInsets.all(isCompact ? 10.0 : 14.0);

                final titleColor =
                highlight ? cs.onPrimaryContainer : cs.onSurface;
                final subColor = titleColor.withOpacity(0.75);

                final buttonMinWidth = isCompact ? 72.0 : 90.0;
                final buttonHorizontalPadding =
                isCompact ? 10.0 : 16.0;

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(radius),
                    color: baseBg,
                    border: Border.all(color: borderColor, width: 1),
                    boxShadow: [
                      BoxShadow(
                        color: cs.shadow.withOpacity(0.08),
                        blurRadius: 14,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: cardPadding,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Strip discount bên trái (ticket)
                        Container(
                          width: stripWidth,
                          padding: EdgeInsets.symmetric(
                            horizontal: isCompact ? 6 : 8,
                            vertical: isCompact ? 5 : 8,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(isCompact ? 12 : 14),
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: highlight
                                  ? [
                                cs.primary,
                                cs.primary.withOpacity(0.75),
                              ]
                                  : [
                                cs.outline.withOpacity(0.3),
                                cs.outlineVariant.withOpacity(0.45),
                              ],
                            ),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                v.code,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 11,
                                  letterSpacing: 0.2,
                                  color: Colors.white,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                typeText,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                                maxLines: 2,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),

                        // Nội dung chi tiết
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Expanded(
                                    child: Text(
                                      v.code,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: isCompact ? 13 : 14,
                                        color: titleColor,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: isCompact ? 6 : 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(999),
                                      color: cs.background.withOpacity(0.4),
                                    ),
                                    child: Text(
                                      remText,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: subColor,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              if (timeText.isNotEmpty)
                                Text(
                                  timeText,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: subColor,
                                  ),
                                ),
                              const SizedBox(height: 4),
                              Text(
                                v.minSubtotal == null
                                    ? 'Không yêu cầu đơn tối thiểu'
                                    : 'Đơn tối thiểu ${_vnd(v.minSubtotal!)}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: titleColor,
                                ),
                              ),
                              if (!enabled) ...[
                                const SizedBox(height: 4),
                                Text(
                                  'Chưa đủ điều kiện (tạm tính: ${_vnd(subtotal)})',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: cs.error,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                              if (isOutOfStock) ...[
                                const SizedBox(height: 4),
                                Text(
                                  'Voucher đã hết lượt',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: cs.error,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                              if (v.description?.isNotEmpty == true) ...[
                                const SizedBox(height: 4),
                                Text(
                                  v.description!,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: subColor,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),

                        const SizedBox(width: 8),

                        // Nút áp dụng
                        SizedBox(
                          height: 36,
                          child: FilledButton(
                            onPressed: canPress
                                ? () async {
                              final uid =
                                  FirebaseAuth.instance.currentUser?.uid;
                              await context
                                  .read<CartController>()
                                  .applyVoucherCode(v.code, uid);
                              final err = context
                                  .read<CartController>()
                                  .voucherError;
                              if (context.mounted) {
                                ScaffoldMessenger.of(context)
                                    .showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      err ??
                                          'Đã áp dụng mã: ${v.code}',
                                    ),
                                  ),
                                );
                              }
                            }
                                : null,
                            style: FilledButton.styleFrom(
                              minimumSize:
                              Size(buttonMinWidth, 36),
                              padding: EdgeInsets.symmetric(
                                horizontal: buttonHorizontalPadding,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(999),
                              ),
                            ),
                            child: Text(
                              'Áp dụng',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color:
                                canPress ? cs.onPrimary : cs.onSurface,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          }

          // ---------- Body list ----------
          return ListView(
            padding: EdgeInsets.fromLTRB(
              16,
              isVeryNarrow ? 8 : 12,
              16,
              isTablet ? 24 : 20,
            ),
            children: [
              // Tóm tắt tạm tính
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: cs.surfaceVariant.withOpacity(
                      theme.brightness == Brightness.dark ? 0.6 : 0.9),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Icon(Icons.receipt_long_rounded,
                        size: 20, color: cs.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Tạm tính đơn hiện tại: ${_vnd(subtotal)}',
                        style: TextStyle(
                          fontSize: 13 * (isVeryNarrow ? 0.95 : 1.0),
                          fontWeight: FontWeight.w600,
                          color: cs.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              if (usable.isNotEmpty) ...[
                Row(
                  children: [
                    Icon(Icons.check_circle_rounded,
                        size: 18, color: cs.primary),
                    const SizedBox(width: 6),
                    Text(
                      'Dùng được ngay',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: cs.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ...usable.map((v) => buildTile(v, enabled: true)),
                const SizedBox(height: 16),
              ],
              if (notEnough.isNotEmpty) ...[
                Row(
                  children: [
                    Icon(Icons.info_rounded,
                        size: 18, color: cs.outline),
                    const SizedBox(width: 6),
                    Text(
                      'Chưa đủ điều kiện',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: cs.outline,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ...notEnough.map((v) => buildTile(v, enabled: false)),
              ],
            ],
          );
        },
      ),
    );
  }
}
