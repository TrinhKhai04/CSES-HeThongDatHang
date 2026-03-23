// lib/views/product/widgets/product_grid_item.dart
// ---------------------------------------------------------------------
// 🛍️ ProductGridItem — Apple-style + Dark/Light theo Theme
// ---------------------------------------------------------------------
// • Ảnh vuông bo góc (Hero), fade-in mượt — ĐÃ bọc Expanded để tự co khi thiếu chỗ
// • ❤️ overlay (tooltip + semantics), ripple đúng borderRadius
// • Tên 2 dòng, brand•category 1 dòng, giá nổi bật (primary)
// • CTA “Thêm” mở chi tiết (tap target shrinkWrap để tiết kiệm chiều cao)
// • LayoutBuilder co chữ/nút khi item thấp (chấm dứt overflow)
// • TextScale clamp 1.0→1.15 (a11y nhẹ, không phá layout)
// • Web/Desktop: hover nâng bóng
// ---------------------------------------------------------------------

import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../controllers/admin_product_controller.dart';
import '../../../controllers/wishlist_controller.dart';
import '../../../models/product.dart';
import '../../../routes/app_routes.dart';

class ProductGridItem extends StatefulWidget {
  final Product model;
  const ProductGridItem({super.key, required this.model});

  @override
  State<ProductGridItem> createState() => _ProductGridItemState();
}

class _ProductGridItemState extends State<ProductGridItem> {
  bool _hover = false;

  static final NumberFormat _fmtVND =
  NumberFormat.currency(locale: 'vi_VN', symbol: '₫', decimalDigits: 0);

  @override
  Widget build(BuildContext context) {
    final model = widget.model;

    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final admin = context.read<AdminProductController>();
    final String? brandId = _maybeBrandId(model);
    final String? categoryId = _maybeCategoryId(model);
    final String? legacyCategory = _maybeLegacyCategory(model);
    final String? brandName = _nameById(admin.brands, brandId);
    final String? categoryName =
        _nameById(admin.categories, categoryId) ?? legacyCategory;

    // Ảnh
    final String? img = model.imageUrl;
    final bool isHttp =
        img != null && (img.startsWith('http://') || img.startsWith('https://'));
    final bool isLocal = img != null &&
        (img.startsWith('file://') || img.startsWith('/') || img.startsWith('content://'));

    Widget image = _imgPlaceholder(theme);
    if (img != null && img.isNotEmpty) {
      if (isHttp) {
        image = _networkImage(img, theme);
      } else if (isLocal) {
        final path = img.startsWith('file://') ? Uri.parse(img).toFilePath() : img;
        final f = File(path);
        image = f.existsSync() ? _fileImage(f, theme) : _imgPlaceholder(theme);
      }
    }

    // Giá
    final num priceNum = (model.price is num) ? (model.price as num) : 0;
    final String priceText = _fmtVND.format(priceNum);

    // 🔹 Số lượng đã bán
    final int soldCount = _maybeSoldCount(model);
    final String? soldLabel =
    soldCount > 0 ? _formatSoldLabel(soldCount) : null;

    // Điều hướng
    void _goDetail() =>
        Navigator.pushNamed(context, AppRoutes.productDetail, arguments: model.id);

    // Clamp text scale
    final media = MediaQuery.of(context);
    final double clampedScale = media.textScaler.scale(1.0).clamp(1.0, 1.15);

    return MediaQuery(
      data: media.copyWith(textScaler: TextScaler.linear(clampedScale)),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: LayoutBuilder(
          builder: (context, box) {
            final bool tight = box.maxHeight < 250;
            final double nameSize = tight ? 13.5 : 14.5;
            final double metaSize = tight ? 11.5 : 12.5;
            final double priceSize = tight ? 14.0 : 15.0;
            final double btnHeight = tight ? 28.0 : 32.0;
            final double gapSmall = tight ? 3.0 : 6.0;
            final double gapTiny = tight ? 2.0 : 4.0;

            return AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? const Color(0xFF2C2C2E) : Colors.transparent,
                ),
                boxShadow: [
                  if (!isDark)
                    BoxShadow(
                      color: Colors.black.withOpacity((_hover && kIsWeb) ? 0.12 : 0.06),
                      blurRadius: (_hover && kIsWeb) ? 16 : 12,
                      offset: const Offset(0, 4),
                    ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: _goDetail,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ===== ẢNH + ❤️ (bọc Expanded để co lại khi thiếu chỗ) =====
                      Expanded(
                        child: AspectRatio(
                          aspectRatio: 1,
                          child: Stack(
                            children: [
                              Positioned.fill(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(14),
                                  child: Hero(tag: 'product:${model.id}', child: image),
                                ),
                              ),
                              Positioned(
                                top: 8,
                                right: 8,
                                child: Consumer<WishlistController>(
                                  builder: (_, wish, __) {
                                    final bool isFav = wish.isFav(model.id);
                                    final overlay = isDark
                                        ? Colors.white.withOpacity(.16)
                                        : Colors.black.withOpacity(.35);
                                    return Semantics(
                                      button: true,
                                      label: isFav ? 'Bỏ yêu thích' : 'Thêm vào yêu thích',
                                      child: Tooltip(
                                        message: isFav ? 'Bỏ yêu thích' : 'Thêm vào yêu thích',
                                        child: InkWell(
                                          borderRadius: BorderRadius.circular(24),
                                          onTap: () async {
                                            try {
                                              await wish.toggle(model.id);
                                            } catch (e) {
                                              if (context.mounted) {
                                                ScaffoldMessenger.of(context)
                                                    .showSnackBar(SnackBar(content: Text('$e')));
                                              }
                                            }
                                          },
                                          child: Container(
                                            padding: const EdgeInsets.all(6),
                                            decoration: BoxDecoration(
                                              color: overlay,
                                              borderRadius: BorderRadius.circular(24),
                                            ),
                                            child: Icon(
                                              isFav ? Icons.favorite : Icons.favorite_border,
                                              color: isFav ? Colors.redAccent : Colors.white,
                                              size: 20,
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      SizedBox(height: gapSmall),

                      // Tên (2 dòng)
                      Text(
                        model.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          height: 1.2,
                          fontSize: nameSize,
                          color: cs.onSurface,
                        ),
                      ),

                      // Brand • Category
                      if ((brandName?.isNotEmpty ?? false) ||
                          (categoryName?.isNotEmpty ?? false)) ...[
                        SizedBox(height: gapTiny),
                        Text(
                          '${brandName ?? ''}'
                              '${(brandName?.isNotEmpty == true && categoryName?.isNotEmpty == true) ? " • " : ""}'
                              '${categoryName ?? ""}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontSize: metaSize,
                            color: cs.onSurface.withOpacity(.6),
                          ),
                        ),
                      ],

                      SizedBox(height: gapTiny),

                      // Giá
                      DefaultTextStyle.merge(
                        style: const TextStyle(decoration: TextDecoration.none),
                        child: Text(
                          priceText,
                          semanticsLabel: 'Giá $priceText',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: cs.primary,
                            fontWeight: FontWeight.w800,
                            fontSize: priceSize,
                            height: 1.2,
                          ),
                        ),
                      ),

                      // 🔹 Đã bán X
                      if (soldLabel != null) ...[
                        SizedBox(height: gapTiny),
                        Text(
                          soldLabel,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontSize: metaSize,
                            color: cs.onSurface.withOpacity(.55),
                          ),
                        ),
                      ],

                      SizedBox(height: gapSmall),

                      // CTA “Thêm” — auto-compact khi khung hẹp để tránh overflow
                      LayoutBuilder(
                        builder: (context, c) {
                          final bool compact = c.maxWidth < 120; // SỬA: ngưỡng co
                          return SizedBox(
                            height: btnHeight,
                            width: double.infinity,
                            child: compact
                            // Chế độ icon-only khi quá hẹp (SỬA)
                                ? FilledButton.tonal(
                              onPressed: _goDetail,
                              style: FilledButton.styleFrom(
                                padding: EdgeInsets.zero, // SỬA
                                minimumSize: Size(0, btnHeight), // SỬA: minWidth=0
                                tapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                visualDensity: const VisualDensity(
                                  horizontal: -4,
                                  vertical: -4,
                                ),
                              ),
                              child: const Icon(
                                  Icons.add_shopping_cart_rounded,
                                  size: 18),
                            )
                            // Đủ rộng thì hiện icon + label (SỬA)
                                : FilledButton.tonalIcon(
                              onPressed: _goDetail,
                              icon: const Icon(Icons.shopping_cart_outlined, size: 18),
                              label: const Text('Thêm',
                                  overflow: TextOverflow.ellipsis),
                              style: FilledButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10), // SỬA
                                minimumSize:
                                Size(0, btnHeight), // SỬA
                                tapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                visualDensity: const VisualDensity(
                                  horizontal: -2,
                                  vertical: -2,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // ===== Helpers =====

  static Widget _imgPlaceholder(ThemeData theme) => Container(
    color: theme.brightness == Brightness.dark
        ? const Color(0xFF2C2C2E)
        : Colors.grey.shade200,
    alignment: Alignment.center,
    child: Icon(
      Icons.image_outlined,
      color: theme.colorScheme.onSurface.withOpacity(0.5),
    ),
  );

  static Widget _networkImage(String url, ThemeData theme) => Image.network(
    url,
    fit: BoxFit.cover,
    gaplessPlayback: true,
    frameBuilder: (context, child, frame, _) => AnimatedOpacity(
      opacity: frame == null ? 0 : 1,
      duration: const Duration(milliseconds: 250),
      child: child,
    ),
    errorBuilder: (_, __, ___) => _imgPlaceholder(theme),
  );

  static Widget _fileImage(File f, ThemeData theme) => Image.file(
    f,
    fit: BoxFit.cover,
    errorBuilder: (_, __, ___) => _imgPlaceholder(theme),
  );

  static String? _nameById(List<Map<String, dynamic>> list, String? id) {
    if (id == null) return null;
    final idx = list.indexWhere((e) => e['id'] == id);
    if (idx < 0) return null;
    final s = (list[idx]['name'] as String?)?.trim();
    return (s == null || s.isEmpty) ? null : s;
  }

  static String? _maybeBrandId(Product m) {
    try {
      final v = (m as dynamic).brandId;
      return (v is String && v.isNotEmpty) ? v : null;
    } catch (_) {
      return null;
    }
  }

  static String? _maybeCategoryId(Product m) {
    try {
      final v = (m as dynamic).categoryId;
      return (v is String && v.isNotEmpty) ? v : null;
    } catch (_) {
      return null;
    }
  }

  static String? _maybeLegacyCategory(Product m) {
    try {
      final v = (m as dynamic).category; // schema cũ dạng text
      return (v is String && v.isNotEmpty) ? v : null;
    } catch (_) {
      return null;
    }
  }

  // 🔹 Lấy soldCount an toàn từ model (hỗ trợ cả schema cũ chưa có field)
  static int _maybeSoldCount(Product m) {
    try {
      final v = (m as dynamic).soldCount;
      if (v is int) return v;
      if (v is num) return v.toInt();
      return 0;
    } catch (_) {
      return 0;
    }
  }

  // 🔹 Format label "Đã bán ..."
  static String _formatSoldLabel(int sold) {
    if (sold >= 1000000) {
      final v = (sold / 1000000).toStringAsFixed(1);
      return 'Đã bán ${v}m+';
    } else if (sold >= 1000) {
      final v = (sold / 1000).toStringAsFixed(1);
      return 'Đã bán ${v}k+';
    } else {
      return 'Đã bán $sold';
    }
  }
}
