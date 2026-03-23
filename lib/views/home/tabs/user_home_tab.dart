// 📁 lib/views/home/tabs/user_home_tab.dart
// ============================================================================
// 🏠 USER HOME TAB — Apple-style, Responsive cho nhiều kích thước màn hình
// ============================================================================

import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../controllers/auth_controller.dart';
import '../../../controllers/product_controller.dart';
import '../../../controllers/admin_product_controller.dart';
import '../../../controllers/xu_controller.dart';
import '../../../routes/app_routes.dart';
import '../../product/widgets/product_grid_item.dart';

class UserHomeTab extends StatefulWidget {
  const UserHomeTab({super.key});

  @override
  State<UserHomeTab> createState() => _UserHomeTabState();
}

class _UserHomeTabState extends State<UserHomeTab> {
  bool _refsLoaded = false;

  // Banner
  final PageController _pageController = PageController(viewportFraction: 0.9);
  int _currentPage = 0;
  int _bannerCount = 0;
  Timer? _autoSlideTimer;

  @override
  void initState() {
    super.initState();
    // Tải refs (brand/category) cho filter/search
    Future.microtask(() async {
      await context.read<AdminProductController>().refreshRefs();
      if (mounted) setState(() => _refsLoaded = true);
    });
  }

  @override
  void dispose() {
    _stopAutoSlide();
    _pageController.dispose();
    super.dispose();
  }

  // ------------------------ Auto-slide helpers ------------------------
  void _startAutoSlide() {
    if (_autoSlideTimer != null || _bannerCount <= 1) return;
    _autoSlideTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!_pageController.hasClients || _bannerCount <= 1) return;
      _currentPage = (_currentPage + 1) % _bannerCount;
      _pageController.animateToPage(
        _currentPage,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOut,
      );
      setState(() {});
    });
  }

  void _stopAutoSlide() {
    _autoSlideTimer?.cancel();
    _autoSlideTimer = null;
  }

  @override
  Widget build(BuildContext context) {
    final products = context.watch<ProductController>();
    final auth = context.watch<AuthController>();
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    String name = (auth.profile?['name'] ?? auth.user?.email ?? 'bạn') as String;
    if (name.contains(' ')) {
      name = name.split(' ').last;
    }

    // ==================== Responsive metrics ====================
    final media = MediaQuery.of(context);
    final size = media.size;
    final textScale = media.textScaleFactor;

    final isTablet = size.width >= 600; // iPad / tablet
    final isWidePhone = size.width >= 430 && size.width < 600;
    final isVeryNarrow = size.width < 340; // màn nhỏ / gập
    final isShort = size.height < 720; // màn thấp
    final isVeryShort = size.height < 640;

    // CrossAxisCount: tablet nhiều cột hơn
    final int crossAxisCount =
    isTablet ? (size.width >= 900 ? 4 : 3) : 2; // điện thoại giữ 2 cột

    // childAspectRatio: co giãn theo chiều cao + textScale
    double gridItemRatio;
    if (isTablet) {
      gridItemRatio = 0.82;
    } else if (isVeryShort || textScale > 1.15 || isVeryNarrow) {
      gridItemRatio = 0.52; // cao hơn → nội dung có chỗ
    } else if (isShort || textScale > 1.05) {
      gridItemRatio = 0.58;
    } else if (isWidePhone) {
      gridItemRatio = 0.68;
    } else {
      gridItemRatio = 0.64;
    }

    // Banner: giới hạn theo chiều cao
    final double rawBannerHeight =
        size.width * (isTablet ? 0.30 : 0.46); // tablet thấp hơn
    final double bannerHeight =
    rawBannerHeight.clamp(160.0, size.height * 0.33);

    // Chừa chỗ cho BottomNavigationBar + safe area
    final bottomInset = media.padding.bottom;
    final baseBottomOffset =
    isTablet ? 40.0 : (isVeryShort ? 56.0 : (isShort ? 72.0 : 80.0));
    final extraBottom = bottomInset + baseBottomOffset;

    return RefreshIndicator(
      onRefresh: () => context.read<ProductController>().fetch(keyword: ''),
      color: cs.primary,
      child: ListView(
        padding: EdgeInsets.fromLTRB(16, 12, 16, extraBottom),
        children: [
          // ================== 1) BANNER (Firestore realtime) ==================
          SizedBox(
            height: bannerHeight,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final outerRadius = constraints.maxWidth * 0.06;

                return Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(outerRadius + 6),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.10),
                        blurRadius: 18,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(outerRadius + 6),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            cs.surfaceVariant.withOpacity(0.40),
                            cs.surface.withOpacity(0.10),
                          ],
                        ),
                      ),
                      child: StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('banners')
                            .where('active', isEqualTo: true)
                            .snapshots(),
                        builder: (context, snap) {
                          if (snap.hasError) {
                            return Center(
                              child: Text(
                                'Lỗi tải banner: ${snap.error}',
                                style: TextStyle(color: cs.error),
                                textAlign: TextAlign.center,
                              ),
                            );
                          }
                          if (!snap.hasData) {
                            return const Center(
                                child: CupertinoActivityIndicator());
                          }

                          final docs = snap.data!.docs;
                          final banners = docs
                              .map((d) => d.data() as Map<String, dynamic>)
                              .where((b) =>
                          (b['imageUrl'] ?? '').toString().isNotEmpty)
                              .toList();

                          final newCount = banners.length;
                          if (newCount != _bannerCount) {
                            _bannerCount = newCount;
                            _currentPage = 0;
                            if (_pageController.hasClients) {
                              _pageController.jumpToPage(0);
                            }
                            _stopAutoSlide();
                            if (_bannerCount > 1) _startAutoSlide();
                          }

                          if (_bannerCount == 0) {
                            return _buildEmptyBanner(theme);
                          }

                          return Stack(
                            alignment: Alignment.bottomCenter,
                            children: [
                              Semantics(
                                label: 'Bộ sưu tập banner',
                                child: PageView.builder(
                                  controller: _pageController,
                                  itemCount: _bannerCount,
                                  onPageChanged: (i) =>
                                      setState(() => _currentPage = i),
                                  itemBuilder: (_, i) {
                                    final b = banners[i];
                                    final child = _buildAppleBannerItem(
                                      context,
                                      b['imageUrl'] as String,
                                      (b['title'] ?? '') as String,
                                    );

                                    return AnimatedBuilder(
                                      animation: _pageController,
                                      builder: (ctx, widget) {
                                        double scale = 1;
                                        if (_pageController.hasClients &&
                                            _pageController.position
                                                .hasContentDimensions) {
                                          final page = _pageController.page ??
                                              _currentPage.toDouble();
                                          final diff = (page - i).abs();
                                          scale =
                                              (1 - diff * 0.06).clamp(0.92, 1.0);
                                        }
                                        return Transform.scale(
                                          scale: scale,
                                          child: widget,
                                        );
                                      },
                                      child: child,
                                    );
                                  },
                                ),
                              ),

                              // Dots glassmorphism
                              if (_bannerCount > 1)
                                Positioned(
                                  bottom: 10,
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(999),
                                    child: BackdropFilter(
                                      filter: ImageFilter.blur(
                                          sigmaX: 12, sigmaY: 12),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withOpacity(0.25),
                                          borderRadius:
                                          BorderRadius.circular(999),
                                          border: Border.all(
                                            color: Colors.white
                                                .withOpacity(0.35),
                                            width: 0.8,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children:
                                          List.generate(_bannerCount, (i) {
                                            final active = (i == _currentPage);
                                            return AnimatedContainer(
                                              duration: const Duration(
                                                  milliseconds: 240),
                                              margin:
                                              const EdgeInsets.symmetric(
                                                  horizontal: 3),
                                              width: active ? 16 : 6,
                                              height: 6,
                                              decoration: BoxDecoration(
                                                color: active
                                                    ? Colors.white
                                                    : Colors.white
                                                    .withOpacity(0.45),
                                                borderRadius:
                                                BorderRadius.circular(4),
                                              ),
                                            );
                                          }),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 12),

          // ================== 1b) CSES XU STRIP ==================
          const _XuHomeStrip(),

          const SizedBox(height: 16),

          // ================== 2) DANH MỤC NHANH ==================
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: const [],
            ),
          ),
          SizedBox(
            height: isVeryNarrow ? 34 : 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _CatChip(
                    text: 'Tất cả',
                    onTap: () => products.fetch(keyword: '')),
                _CatChip(
                    text: 'Apple Watch',
                    onTap: () =>
                        products.fetch(keyword: 'Apple Watch')),
                _CatChip(
                    text: 'Mac',
                    onTap: () => products.fetch(keyword: 'MacBook')),
                _CatChip(
                    text: 'iPad',
                    onTap: () => products.fetch(keyword: 'iPad')),
                _CatChip(
                    text: 'AirPods',
                    onTap: () => products.fetch(keyword: 'AirPods')),
                _CatChip(
                    text: 'AirTag',
                    onTap: () => products.fetch(keyword: 'AirTag')),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // ================== 3) LƯỚI SẢN PHẨM ==================
          if (products.loading)
            const SizedBox(
                height: 240,
                child: Center(child: CircularProgressIndicator()))
          else if (products.products.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 60),
              child: Center(
                child: Text(
                  'Không có sản phẩm phù hợp',
                  style: theme.textTheme.titleMedium,
                ),
              ),
            )
          else
            GridView.builder(
              itemCount: products.products.length,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: gridItemRatio,
              ),
              itemBuilder: (_, i) =>
                  ProductGridItem(model: products.products[i]),
            ),
        ],
      ),
    );
  }

  // -------------------- Banner Item --------------------
  Widget _buildAppleBannerItem(
      BuildContext context, String imageUrl, String title) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              imageUrl,
              fit: BoxFit.cover,
              gaplessPlayback: true,
              frameBuilder: (_, child, frame, __) => AnimatedOpacity(
                opacity: frame == null ? 0 : 1,
                duration: const Duration(milliseconds: 250),
                child: child,
              ),
              errorBuilder: (_, __, ___) => Container(
                color: theme.colorScheme.surface,
                alignment: Alignment.center,
                child: Icon(
                  Icons.broken_image_outlined,
                  color: theme.colorScheme.onSurface.withOpacity(0.5),
                ),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.center,
                  colors: [
                    Colors.black.withOpacity(0.45),
                    Colors.transparent
                  ],
                ),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                border: Border.all(
                  color: Colors.white.withOpacity(0.15),
                  width: 0.6,
                ),
              ),
            ),
            if (title.isNotEmpty)
              Positioned(
                left: 16,
                bottom: 18,
                right: 16,
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
        ),
      ),
    );
  }

  // -------------------- Banner trống --------------------
  Widget _buildEmptyBanner(ThemeData theme) => Container(
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
        color: theme.brightness == Brightness.dark
            ? const Color(0xFF2C2C2E)
            : Colors.black12,
      ),
    ),
    child: Text(
      'Chưa có banner nào',
      style: TextStyle(
        color: theme.colorScheme.onSurface.withOpacity(0.6),
      ),
    ),
  );
}

// ============================================================================
// ⭐ Thanh CSES Xu — giữ nguyên, đã responsive theo width
// ============================================================================
class _XuHomeStrip extends StatelessWidget {
  const _XuHomeStrip();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Consumer<XuController>(
      builder: (ctx, xu, _) {
        final loading = xu.isLoading;
        final balance = xu.balance;
        final dailyReward = xu.dailyReward;
        final checkedIn = xu.checkedInToday;
        final streak = xu.streak;

        if (!loading && balance == 0 && streak == 0 && !checkedIn) {
          final uid = ctx.read<AuthController>().user?.uid;
          if (uid != null && uid.isNotEmpty) {
            Future.microtask(() => xu.load(uid));
          }
        }

        final subtitle =
        loading ? 'Đang tải số dư CSES Xu...' : '$balance xu khả dụng';

        final subline = loading
            ? ''
            : checkedIn
            ? 'Bạn đã điểm danh hôm nay • +$dailyReward xu'
            : 'Điểm danh hôm nay để nhận +$dailyReward xu';

        final ctaText =
        loading ? 'Đang tải' : (checkedIn ? 'Xem ưu đãi' : 'Nhận xu');

        final bgColorsChecked = [
          cs.primary.withOpacity(isDark ? 0.95 : 0.92),
          cs.primary.withOpacity(isDark ? 0.70 : 0.80),
        ];

        final bgColorsNotChecked = [
          cs.primary.withOpacity(isDark ? 0.85 : 0.88),
          cs.primary.withOpacity(isDark ? 0.55 : 0.70),
        ];

        return LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;

            final scale = (width / 390.0).clamp(0.85, 1.15);
            double s(double v) => v * scale;
            double fs(double v) => (v * scale).clamp(v * 0.85, v * 1.15);

            final isCompact = width < 340;

            return ClipRRect(
                borderRadius: BorderRadius.circular(s(20)),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(s(20)),
                      onTap: () {
                        Navigator.pushNamed(context, AppRoutes.xuRewards);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 260),
                        curve: Curves.easeInOut,
                        padding: EdgeInsets.symmetric(
                          horizontal: s(14),
                          vertical: s(10),
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(s(20)),
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors:
                            checkedIn ? bgColorsChecked : bgColorsNotChecked,
                          ),
                          border: Border.all(
                            color: Colors.white
                                .withOpacity(isDark ? 0.20 : 0.70),
                            width: 0.7,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: cs.primary
                                  .withOpacity(isDark ? 0.35 : 0.30),
                              blurRadius: s(16),
                              offset: Offset(0, s(8)),
                            ),
                          ],
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // Icon xu tròn
                            Container(
                              width: s(40),
                              height: s(40),
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Colors.white,
                                    Color(0xFFE6F0FF),
                                  ],
                                ),
                              ),
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  Text(
                                    'S',
                                    style: TextStyle(
                                      fontSize: fs(18),
                                      fontWeight: FontWeight.w800,
                                      color: cs.primary,
                                      letterSpacing: -0.5,
                                    ),
                                  ),
                                  if (!loading && !checkedIn)
                                    Positioned(
                                      right: s(4),
                                      top: s(6),
                                      child: Container(
                                        width: s(7),
                                        height: s(7),
                                        decoration: BoxDecoration(
                                          color: cs.primary,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),

                            SizedBox(width: s(12)),

                            // Nội dung + CTA
                            Expanded(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment:
                                    CrossAxisAlignment.center,
                                    children: [
                                      Expanded(
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              'CSES Xu',
                                              style: TextStyle(
                                                fontSize: fs(15),
                                                fontWeight: FontWeight.w700,
                                                color: Colors.white,
                                                letterSpacing: -0.1,
                                              ),
                                            ),
                                            if (!loading && streak > 0)
                                              SizedBox(width: s(6)),
                                            if (!loading && streak > 0)
                                              Flexible(
                                                child: Container(
                                                  padding:
                                                  EdgeInsets.symmetric(
                                                    horizontal: s(8),
                                                    vertical: s(2),
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: Colors.white
                                                        .withOpacity(0.16),
                                                    borderRadius:
                                                    BorderRadius.circular(
                                                        999),
                                                  ),
                                                  child: Text(
                                                    'Chuỗi $streak ngày 🔥',
                                                    style: TextStyle(
                                                      fontSize: fs(11),
                                                      fontWeight:
                                                      FontWeight.w600,
                                                      color: Colors.white,
                                                    ),
                                                    maxLines: 1,
                                                    overflow:
                                                    TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                      SizedBox(width: s(8)),
                                      AnimatedContainer(
                                        duration: const Duration(
                                            milliseconds: 200),
                                        padding: EdgeInsets.symmetric(
                                          horizontal: s(10),
                                          vertical: s(6),
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.white
                                              .withOpacity(0.22),
                                          borderRadius:
                                          BorderRadius.circular(999),
                                          border: Border.all(
                                            color: Colors.white
                                                .withOpacity(0.4),
                                            width: 0.6,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            AnimatedSwitcher(
                                              duration: const Duration(
                                                  milliseconds: 180),
                                              child: Text(
                                                ctaText,
                                                key: ValueKey(ctaText),
                                                style: TextStyle(
                                                  fontSize: fs(12),
                                                  fontWeight:
                                                  FontWeight.w600,
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ),
                                            SizedBox(width: s(4)),
                                            Icon(
                                              CupertinoIcons.chevron_right,
                                              size: s(13),
                                              color: Colors.white
                                                  .withOpacity(0.95),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),

                                  SizedBox(height: s(4)),

                                  AnimatedSwitcher(
                                    duration: const Duration(
                                        milliseconds: 200),
                                    child: Text(
                                      subtitle,
                                      key: ValueKey(subtitle),
                                      style: TextStyle(
                                        fontSize: fs(13),
                                        color: Colors.white
                                            .withOpacity(0.96),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),

                                  if (subline.isNotEmpty && !isCompact) ...[
                                    SizedBox(height: s(2)),
                                    AnimatedSwitcher(
                                      duration: const Duration(
                                          milliseconds: 220),
                                      child: Text(
                                        subline,
                                        key: ValueKey(subline),
                                        style: TextStyle(
                                          fontSize: fs(11.5),
                                          color:
                                          Colors.white.withOpacity(0.9),
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ));
            },
        );
      },
    );

  }
}

// ============================================================================
// 🎯 Danh mục Chip
// ============================================================================
class _CatChip extends StatelessWidget {
  final String text;
  final VoidCallback onTap;
  const _CatChip({required this.text, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final chipTheme = ChipTheme.of(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ActionChip(
        label: Text(
          text,
          style: chipTheme.labelStyle?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        onPressed: onTap,
        shape: chipTheme.shape ??
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(999),
            ),
        backgroundColor: chipTheme.backgroundColor ??
            (isDark
                ? const Color(0xFF1C1C1E)
                : const Color(0xFFF5F5F7)),
        side: chipTheme.side ??
            BorderSide(
              color: isDark
                  ? const Color(0x332C2C2E)
                  : const Color(0xFFE6E8EC),
            ),
        elevation: 0,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}
