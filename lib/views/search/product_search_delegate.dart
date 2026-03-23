// 📁 lib/views/search/product_search_delegate.dart
// ============================================================================
// 🔍 ProductSearchDelegate — Tìm kiếm sản phẩm theo phong cách Apple Store
// ----------------------------------------------------------------------------
// - AppBar sáng / tối theo theme (Material 3 + Cupertino vibe)
// - TextField dạng capsule (bo tròn, nền surfaceVariant)
// - Gợi ý tìm kiếm dạng capsule buttons với gradient nền
// - Kết quả hiển thị dạng lưới sản phẩm responsive:
//      + < 600   : 2 cột (mobile)
//      + 600-1024: 3 cột (tablet / màn ngang)
//      + ≥ 1024  : 4 cột (desktop / web)
// ============================================================================

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/repositories/product_repository.dart';
import '../../models/product.dart';
import '../product/widgets/product_grid_item.dart';
import '../../controllers/admin_product_controller.dart';

class ProductSearchDelegate extends SearchDelegate<String?> {
  ProductSearchDelegate()
      : super(
    searchFieldLabel: 'Tìm laptop / phụ kiện…',
    keyboardType: TextInputType.text,
    textInputAction: TextInputAction.search,
  );

  // --------------------------------------------------------------------------
  // ⚙️ Nút action bên phải ô tìm (clear query)
  // --------------------------------------------------------------------------
  @override
  List<Widget>? buildActions(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return [
      if (query.isNotEmpty)
        IconButton(
          tooltip: 'Xoá nội dung',
          icon: Icon(
            CupertinoIcons.xmark_circle_fill,
            color: cs.outlineVariant,
          ),
          onPressed: () {
            query = '';
            showSuggestions(context);
          },
        ),
    ];
  }

  // --------------------------------------------------------------------------
  // ◀️ Nút back bên trái (đóng search)
  // --------------------------------------------------------------------------
  @override
  Widget? buildLeading(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return IconButton(
      tooltip: 'Đóng',
      icon: Icon(
        CupertinoIcons.back,
        color: cs.primary,
      ),
      onPressed: () => close(context, null),
    );
  }

  // --------------------------------------------------------------------------
  // 📦 Khi người dùng nhấn “Tìm” → hiển thị kết quả
  // --------------------------------------------------------------------------
  @override
  Widget buildResults(BuildContext context) {
    return _SearchResultGrid(keyword: query);
  }

  // --------------------------------------------------------------------------
  // 💡 Khi người dùng đang gõ → hiển thị gợi ý
  // --------------------------------------------------------------------------
  @override
  Widget buildSuggestions(BuildContext context) {
    if (query.trim().isEmpty) {
      return _SuggestionView(
        onTap: (kw) {
          query = kw;
          showResults(context);
        },
      );
    }
    return _SearchResultGrid(keyword: query);
  }

  // --------------------------------------------------------------------------
  // 🎨 Theme AppBar kiểu Apple Store (support dark / light)
  // --------------------------------------------------------------------------
  @override
  ThemeData appBarTheme(BuildContext context) {
    final base = Theme.of(context);
    final cs = base.colorScheme;
    final isDark = cs.brightness == Brightness.dark;

    return base.copyWith(
      scaffoldBackgroundColor: cs.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: cs.surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        iconTheme: IconThemeData(color: cs.primary),
        titleTextStyle: base.textTheme.titleLarge?.copyWith(
          color: cs.onSurface,
          fontWeight: FontWeight.w600,
          fontSize: 18,
        ),
      ),
      inputDecorationTheme: base.inputDecorationTheme.copyWith(
        filled: true,
        fillColor:
        isDark ? cs.surfaceVariant.withOpacity(0.95) : cs.surfaceVariant,
        hintStyle: TextStyle(
          color: cs.outline,
          fontSize: 16,
        ),
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: BorderSide.none,
        ),
      ),
      textTheme: base.textTheme.copyWith(
        titleLarge: base.textTheme.titleLarge?.copyWith(
          color: cs.onSurface,
          fontWeight: FontWeight.w600,
          fontSize: 18,
        ),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: cs.primary,
        selectionColor: cs.primary.withOpacity(0.2),
        selectionHandleColor: cs.primary,
      ),
    );
  }
}

// ============================================================================
// 💡 VIEW: GỢI Ý TÌM KIẾM (Hiển thị khi chưa nhập gì)
// ============================================================================

class _SuggestionView extends StatelessWidget {
  final ValueChanged<String> onTap;
  const _SuggestionView({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;

    final suggestions = [
      'Apple',
      'iPhone',
      'Samsung',
      'AirPods',
      'Apple Watch',
    ];

    final chipBg =
    isDark ? cs.surfaceVariant.withOpacity(0.7) : cs.surfaceVariant;

    final chipBorder = Border.all(
      color: cs.outline.withOpacity(0.25),
      width: 1,
    );

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            cs.surface,
            cs.surface,
            cs.surfaceVariant.withOpacity(isDark ? 0.35 : 0.18),
          ],
        ),
      ),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          // Header
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(
                CupertinoIcons.sparkles,
                size: 20,
                color: cs.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'Gợi ý tìm kiếm',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: cs.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Chọn nhanh thương hiệu phổ biến để bắt đầu.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: cs.outline,
            ),
          ),
          const SizedBox(height: 14),

          // 🍎 Nút gợi ý dạng capsule
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: suggestions.map((s) {
              return GestureDetector(
                onTap: () => onTap(s),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 18, vertical: 9),
                  decoration: BoxDecoration(
                    color: chipBg,
                    borderRadius: BorderRadius.circular(999),
                    border: chipBorder,
                    boxShadow: [
                      if (!isDark)
                        BoxShadow(
                          blurRadius: 10,
                          spreadRadius: 1,
                          offset: const Offset(0, 4),
                          color: Colors.black.withOpacity(0.045),
                        ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        CupertinoIcons.search,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        s,
                        style: TextStyle(
                          color: cs.onSurface,
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 36),

          // 📜 Gợi ý phụ
          Center(
            child: Text(
              'Hãy nhập tên sản phẩm, thương hiệu\nhoặc danh mục để tìm nhanh.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: cs.outline,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// 📦 VIEW: KẾT QUẢ TÌM KIẾM (responsive grid)
// ============================================================================

class _SearchResultGrid extends StatefulWidget {
  final String keyword;
  const _SearchResultGrid({required this.keyword});

  @override
  State<_SearchResultGrid> createState() => _SearchResultGridState();
}

class _SearchResultGridState extends State<_SearchResultGrid> {
  late Future<List<Product>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load(widget.keyword);
  }

  @override
  void didUpdateWidget(covariant _SearchResultGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.keyword != widget.keyword) {
      _future = _load(widget.keyword);
    }
  }

  // 🧩 Tải dữ liệu sản phẩm theo từ khóa
  Future<List<Product>> _load(String keyword) async {
    final rows = await ProductRepository().getAll(keyword: keyword);
    return rows.map(Product.fromMap).toList();
  }

  @override
  Widget build(BuildContext context) {
    // Đảm bảo brand/category đã load sẵn
    context.read<AdminProductController>().refreshRefs();

    final cs = Theme.of(context).colorScheme;

    return FutureBuilder<List<Product>>(
      future: _future,
      builder: (_, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CupertinoActivityIndicator());
        }

        final data = snap.data ?? [];
        if (data.isEmpty) {
          return Center(
            child: Text(
              'Không tìm thấy sản phẩm',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: cs.outline,
              ),
            ),
          );
        }

        return LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final height = constraints.maxHeight;
            final isPortrait = height >= width;

            int crossAxisCount;
            double ratio;

            if (width >= 1024) {
              // Desktop / web
              crossAxisCount = 4;
              ratio = isPortrait ? 0.80 : 0.90;
            } else if (width >= 600) {
              // Tablet / màn ngang lớn
              crossAxisCount = 3;
              ratio = isPortrait ? 0.72 : 0.80;
            } else {
              // Mobile
              crossAxisCount = 2;
              ratio = isPortrait ? 0.66 : 0.78;
            }

            return Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    cs.surface,
                    cs.surface,
                    cs.surfaceVariant.withOpacity(
                        cs.brightness == Brightness.dark ? 0.35 : 0.18),
                  ],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Summary card cho kết quả
                  Padding(
                    padding:
                    const EdgeInsets.fromLTRB(16, 14, 16, 8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: cs.surfaceVariant
                            .withOpacity(cs.brightness == Brightness.dark
                            ? 0.65
                            : 0.9),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            CupertinoIcons.search,
                            size: 18,
                            color: cs.primary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Kết quả cho “${widget.keyword.trim()}”',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: cs.onSurface,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: cs.primary
                                  .withOpacity(cs.brightness ==
                                  Brightness.dark
                                  ? 0.24
                                  : 0.12),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              '${data.length} sản phẩm',
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(
                                color: cs.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Expanded(
                    child: GridView.builder(
                      padding:
                      const EdgeInsets.fromLTRB(16, 8, 16, 8),
                      itemCount: data.length,
                      gridDelegate:
                      SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: ratio,
                      ),
                      itemBuilder: (_, i) =>
                          ProductGridItem(model: data[i]),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
