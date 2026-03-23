// ignore_for_file: unnecessary_const
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../controllers/admin_product_controller.dart';
import '../../../routes/app_routes.dart';
import '../widgets/admin_drawer.dart';

class AdminProductListScreen extends StatefulWidget {
  const AdminProductListScreen({super.key});
  @override
  State<AdminProductListScreen> createState() => _AdminProductListScreenState();
}

class _AdminProductListScreenState extends State<AdminProductListScreen> {
  final _searchCtl = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AdminProductController>().init();
    });
  }

  @override
  void dispose() {
    _searchCtl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<AdminProductController>();
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.background,
      drawer: const AdminDrawer(),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: cs.surface,
        foregroundColor: cs.onSurface,
        centerTitle: true,
        iconTheme: IconThemeData(color: cs.primary),
        title: Text(
          'Sản phẩm',
          style: TextStyle(
            color: cs.primary,
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Làm mới',
            onPressed: c.refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),

      // FAB thêm SP — auto Dark/Light
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: cs.secondaryContainer,
        foregroundColor: cs.onSecondaryContainer,
        icon: const Icon(Icons.add),
        label: const Text('Thêm sản phẩm',
            style: TextStyle(fontWeight: FontWeight.w600)),
        onPressed: () => Navigator.pushNamed(context, AppRoutes.adminProductForm),
      ),

      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
          child: ListView(
            children: [
              _SearchAndFilters(
                searchCtl: _searchCtl,
                onSearch: c.setSearch,
                brands: c.brands,
                categories: c.categories,
                selectedBrandId: c.filterBrandId,
                selectedCategoryId: c.filterCategoryId,
                onBrandChanged: c.setBrandFilter,
                onCategoryChanged: c.setCategoryFilter,
              ),
              const SizedBox(height: 16),

              if (c.loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 60),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (c.products.isEmpty)
                _EmptyState(
                  title: 'Chưa có sản phẩm',
                  subtitle: 'Nhấn "Thêm sản phẩm" để bắt đầu.',
                  onAdd: () =>
                      Navigator.pushNamed(context, AppRoutes.adminProductForm),
                )
              else
                ...List.generate(c.products.length, (i) {
                  final p = c.products[i];
                  final brand = c.brands.firstWhere(
                        (b) => b['id'] == p['brandId'],
                    orElse: () => const {},
                  );
                  final cat = c.categories.firstWhere(
                        (e) => e['id'] == p['categoryId'],
                    orElse: () => const {},
                  );
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: _ProductCard(
                      p: p,
                      brand: brand['name'],
                      category: cat['name'],
                      controller: c,
                    ),
                  );
                }),
            ],
          ),
        ),
      ),
    );
  }
}

// ========================== SEARCH + FILTER ==========================
class _SearchAndFilters extends StatelessWidget {
  const _SearchAndFilters({
    required this.searchCtl,
    required this.onSearch,
    required this.brands,
    required this.categories,
    required this.selectedBrandId,
    required this.selectedCategoryId,
    required this.onBrandChanged,
    required this.onCategoryChanged,
  });

  final TextEditingController searchCtl;
  final void Function(String) onSearch;
  final List<Map<String, dynamic>> brands;
  final List<Map<String, dynamic>> categories;
  final String? selectedBrandId;
  final String? selectedCategoryId;
  final void Function(String?) onBrandChanged;
  final void Function(String?) onCategoryChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      children: [
        // Search
        TextField(
          controller: searchCtl,
          onChanged: onSearch,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: 'Tìm theo tên hoặc SKU...',
            prefixIcon: Icon(Icons.search, color: cs.primary),
            filled: true,
            fillColor: cs.surface,
            contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: cs.outlineVariant),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: cs.outlineVariant),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: cs.primary),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Filters
        Padding(
          padding: const EdgeInsets.only(bottom: 2),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final w = (constraints.maxWidth - 10) / 2;
              InputDecoration deco(String label) => InputDecoration(
                labelText: label,
                contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                filled: true,
                fillColor: cs.surface,
                border: const OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                  borderSide: BorderSide.none,
                ),
              );

              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  // Brand
                  SizedBox(
                    width: w,
                    child: DropdownButtonHideUnderline(
                      child: DropdownButtonFormField<String?>(
                        value: selectedBrandId,
                        isExpanded: true,
                        isDense: true,
                        alignment: Alignment.centerLeft,
                        decoration: deco('Thương hiệu'),
                        items: [
                          const DropdownMenuItem<String?>(
                              value: null, child: Text('Tất cả')),
                          ...brands.map(
                                (b) => DropdownMenuItem<String?>(
                              value: b['id'],
                              child: Text(
                                b['name'] ?? '',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ],
                        onChanged: onBrandChanged,
                      ),
                    ),
                  ),

                  // Category
                  SizedBox(
                    width: w,
                    child: DropdownButtonHideUnderline(
                      child: DropdownButtonFormField<String?>(
                        value: selectedCategoryId,
                        isExpanded: true,
                        isDense: true,
                        alignment: Alignment.centerLeft,
                        decoration: deco('Danh mục'),
                        items: [
                          const DropdownMenuItem<String?>(
                              value: null, child: Text('Tất cả')),
                          ...categories.map(
                                (e) => DropdownMenuItem<String?>(
                              value: e['id'],
                              child: Text(
                                e['name'] ?? '',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ],
                        onChanged: onCategoryChanged,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

// ========================== PRODUCT CARD ==========================
class _ProductCard extends StatelessWidget {
  const _ProductCard({
    required this.p,
    required this.brand,
    required this.category,
    required this.controller,
  });

  final Map<String, dynamic> p;
  final String? brand;
  final String? category;
  final AdminProductController controller;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cs.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.black.withOpacity(0.30)
                : Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(
              p['imageUrl'] ?? '',
              width: 70,
              height: 70,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                width: 70,
                height: 70,
                color: cs.surfaceVariant.withOpacity(.5),
                child: Icon(Icons.image_not_supported,
                    color: cs.onSurfaceVariant),
              ),
            ),
          ),
          const SizedBox(width: 14),

          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        p['name'] ?? '',
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                            color: cs.onSurface),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _StatusChip(status: (p['status'] ?? 'active') as String),
                  ],
                ),
                const SizedBox(height: 4),
                Text('SKU: ${p['sku'] ?? '-'}',
                    style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13)),
                Text('${brand ?? '—'} • ${category ?? '—'}',
                    style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13)),
                const SizedBox(height: 6),
                Text(
                  _vnCurrency((p['price'] ?? 0) as num),
                  style: TextStyle(
                    color: cs.secondary,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),

          // Actions
          Column(
            children: [
              IconButton(
                tooltip: 'Sửa',
                icon: Icon(Icons.edit_outlined, color: cs.primary),
                onPressed: () => Navigator.pushNamed(
                  context,
                  AppRoutes.adminProductForm,
                  arguments: p['id'],
                ),
              ),
              IconButton(
                tooltip: 'Xoá',
                icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                onPressed: () async {
                  final ok = await _confirm(
                    context,
                    title: 'Xoá sản phẩm?',
                    message: 'Bạn có chắc muốn xoá "${p['name'] ?? ''}"?',
                  );
                  if (ok == true) {
                    await controller.deleteProduct(p['id']);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('🗑️ Đã xoá sản phẩm')),
                      );
                    }
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _vnCurrency(num v) =>
      'đ${v.toStringAsFixed(0).replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ',')}';

  static Future<bool?> _confirm(BuildContext context,
      {required String title, required String message}) {
    return showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Text(message),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Huỷ')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Xoá', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
  }
}

// ========================== STATUS CHIP ==========================
class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final active = status == 'active';
    final color = active ? const Color(0xFF34C759) : const Color(0xFFFFB020);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        active ? 'Đang bán' : 'Tạm ẩn',
        style:
        TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }
}

// ========================== EMPTY STATE ==========================
class _EmptyState extends StatelessWidget {
  const _EmptyState(
      {required this.title, required this.subtitle, required this.onAdd});

  final String title;
  final String subtitle;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 80),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cs.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.black.withOpacity(0.30)
                : Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          )
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.inventory_2_outlined, size: 50, color: cs.primary),
          const SizedBox(height: 10),
          Text(title,
              style:
              TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: cs.onSurface)),
          const SizedBox(height: 4),
          Text(subtitle, style: TextStyle(color: cs.onSurfaceVariant)),
          const SizedBox(height: 14),
          ElevatedButton.icon(
            onPressed: onAdd,
            icon: Icon(Icons.add, color: cs.onSecondaryContainer),
            label: Text('Thêm sản phẩm',
                style: TextStyle(color: cs.onSecondaryContainer)),
            style: ElevatedButton.styleFrom(
              backgroundColor: cs.secondaryContainer,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              padding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              elevation: 0,
            ),
          ),
        ],
      ),
    );
  }
}
