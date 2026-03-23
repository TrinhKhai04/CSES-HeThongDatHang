import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../routes/app_routes.dart';

/// =====================
/// Responsive helper
/// =====================
class _R {
  static double w(BuildContext c) => MediaQuery.sizeOf(c).width;

  static bool isPhone(BuildContext c) => w(c) < 600;
  static bool isTablet(BuildContext c) => w(c) >= 600 && w(c) < 1024;
  static bool isDesktop(BuildContext c) => w(c) >= 1024;

  static T pick<T>({
    required BuildContext c,
    required T phone,
    required T tablet,
    required T desktop,
  }) {
    if (isDesktop(c)) return desktop;
    if (isTablet(c)) return tablet;
    return phone;
  }
}

/// =====================
/// PRODUCT OVERLAY
/// =====================
class ProductOverlay extends StatelessWidget {
  final String productId;
  final String? voucherCode;

  const ProductOverlay({
    super.key,
    required this.productId,
    this.voucherCode,
  });

  String formatPrice(num price) {
    return NumberFormat.currency(
      locale: 'vi_VN',
      symbol: '₫',
      decimalDigits: 0,
    ).format(price);
  }

  void _openDetail(BuildContext context) {
    Navigator.pushNamed(
      context,
      AppRoutes.productDetail,
      arguments: productId,
    );
  }

  @override
  Widget build(BuildContext context) {
    final code = (voucherCode ?? '').trim();

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('products')
          .doc(productId)
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData || !snap.data!.exists) {
          return const SizedBox.shrink();
        }

        final d = snap.data!.data() as Map<String, dynamic>;
        if (d['status'] != 'active') return const SizedBox.shrink();

        final name = d['name'] ?? '';
        final price = d['price'] ?? 0;
        final imageUrl = d['imageUrl'] ?? '';
        final soldCount = d['soldCount'] ?? 0;

        return Align(
          alignment: Alignment.bottomCenter,
          child: SafeArea(
            top: false,
            minimum: const EdgeInsets.only(bottom: 12),
            child: LayoutBuilder(
              builder: (context, c) {
                final maxW = c.maxWidth;

                // 🔒 Giới hạn chiều rộng card
                final cardWidth = _R.pick<double>(
                  c: context,
                  phone: maxW,
                  tablet: 640,
                  desktop: 820,
                );

                final isNarrow = cardWidth < 480;
                final isWide = cardWidth >= 640;

                return Center(
                  child: SizedBox(
                    width: cardWidth,
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.0, end: 1.0),
                      duration: const Duration(milliseconds: 260),
                      curve: Curves.easeOutCubic,
                      builder: (context, t, child) {
                        return Transform.translate(
                          offset: Offset(0, (1 - t) * 36),
                          child: Opacity(opacity: t, child: child),
                        );
                      },
                      child: _GlassCard(
                        blur: kIsWeb ? 8 : 14,
                        padding: const EdgeInsets.all(14),
                        child: isNarrow || !isWide
                            ? _NarrowLayout(
                          imageUrl: imageUrl,
                          name: name,
                          priceText: formatPrice(price),
                          soldCount: soldCount,
                          voucherCode: code,
                          onOpen: () => _openDetail(context),
                          onBuy: () => _openDetail(context),
                        )
                            : _WideLayout(
                          imageUrl: imageUrl,
                          name: name,
                          priceText: formatPrice(price),
                          soldCount: soldCount,
                          voucherCode: code,
                          onOpen: () => _openDetail(context),
                          onBuy: () => _openDetail(context),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}

/// =====================
/// GLASS CARD
/// =====================
class _GlassCard extends StatelessWidget {
  final double blur;
  final EdgeInsets padding;
  final Widget child;

  const _GlassCard({
    required this.blur,
    required this.padding,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(
      _R.pick<double>(c: context, phone: 22, tablet: 24, desktop: 26),
    );

    return ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: radius,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withOpacity(0.18),
                Colors.white.withOpacity(0.08),
                Colors.black.withOpacity(0.10),
              ],
            ),
            border: Border.all(color: Colors.white.withOpacity(0.14)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.45),
                blurRadius: 30,
                offset: const Offset(0, 18),
              ),
            ],
          ),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// =====================
/// WIDE LAYOUT
/// =====================
class _WideLayout extends StatelessWidget {
  final String imageUrl;
  final String name;
  final String priceText;
  final int soldCount;
  final String voucherCode;
  final VoidCallback onOpen;
  final VoidCallback onBuy;

  const _WideLayout({
    required this.imageUrl,
    required this.name,
    required this.priceText,
    required this.soldCount,
    required this.voucherCode,
    required this.onOpen,
    required this.onBuy,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _Thumb(imageUrl: imageUrl),
        const SizedBox(width: 12),
        Expanded(
          child: InkWell(
            onTap: onOpen,
            borderRadius: BorderRadius.circular(14),
            child: _Info(
              name: name,
              priceText: priceText,
              soldCount: soldCount,
              voucherCode: voucherCode,
            ),
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(width: 170, child: _BuyButton(onPressed: onBuy)),
      ],
    );
  }
}

/// =====================
/// NARROW LAYOUT
/// =====================
class _NarrowLayout extends StatelessWidget {
  final String imageUrl;
  final String name;
  final String priceText;
  final int soldCount;
  final String voucherCode;
  final VoidCallback onOpen;
  final VoidCallback onBuy;

  const _NarrowLayout({
    required this.imageUrl,
    required this.name,
    required this.priceText,
    required this.soldCount,
    required this.voucherCode,
    required this.onOpen,
    required this.onBuy,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: onOpen,
          borderRadius: BorderRadius.circular(14),
          child: Row(
            children: [
              _Thumb(imageUrl: imageUrl),
              const SizedBox(width: 12),
              Expanded(
                child: _Info(
                  name: name,
                  priceText: priceText,
                  soldCount: soldCount,
                  voucherCode: voucherCode,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: _BuyButton(onPressed: onBuy, isFullWidth: true),
        ),
      ],
    );
  }
}

/// =====================
/// THUMB
/// =====================
class _Thumb extends StatelessWidget {
  final String imageUrl;
  const _Thumb({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    final size = _R.pick<double>(
      c: context,
      phone: 56,
      tablet: 64,
      desktop: 72,
    );

    final radius = BorderRadius.circular(16);

    return ClipRRect(
      borderRadius: radius,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: radius,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.28),
              blurRadius: 14,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: imageUrl.isEmpty
            ? const Icon(Icons.image_outlined, color: Colors.white70)
            : Image.network(imageUrl, fit: BoxFit.cover),
      ),
    );
  }
}

/// =====================
/// INFO
/// =====================
class _Info extends StatelessWidget {
  final String name;
  final String priceText;
  final int soldCount;
  final String voucherCode;

  const _Info({
    required this.name,
    required this.priceText,
    required this.soldCount,
    required this.voucherCode,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 15,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          priceText,
          style: const TextStyle(
            color: Color(0xFFFFC56B),
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Đã bán $soldCount',
          style: TextStyle(color: Colors.white.withOpacity(0.75), fontSize: 12),
        ),
        if (voucherCode.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              'Voucher: $voucherCode',
              style: const TextStyle(
                color: Color(0xFFFFE0B2),
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
      ],
    );
  }
}

/// =====================
/// BUY BUTTON
/// =====================
class _BuyButton extends StatelessWidget {
  final VoidCallback onPressed;
  final bool isFullWidth;

  const _BuyButton({
    required this.onPressed,
    this.isFullWidth = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          gradient: const LinearGradient(
            colors: [
              Color(0xFFFFB74D),
              Color(0xFFFFA726),
              Color(0xFFFF8F00),
            ],
          ),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.shopping_cart_outlined, color: Colors.black, size: 18),
            SizedBox(width: 8),
            Text(
              'Mua ngay',
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
