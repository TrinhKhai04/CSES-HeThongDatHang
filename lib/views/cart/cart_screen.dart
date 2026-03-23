// lib/views/cart/cart_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../controllers/cart_controller.dart';
import '../../routes/app_routes.dart';
import '../../data/repositories/voucher_repository.dart';
import '../../models/voucher.dart';
import '../../models/product.dart'; // 👈 để dùng model Product

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});
  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  final _couponCtl = TextEditingController();

  // Cache tồn kho
  final Map<String, int?> _variantStockCache = {};
  final Map<String, int?> _productStockCache = {};

  @override
  void dispose() {
    _couponCtl.dispose();
    super.dispose();
  }

  // parse số an toàn cho mọi kiểu
  int? _asIntOrNull(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v);
    return null;
  }

  // helper đọc stock từ 1 path
  Future<int?> _readStockAtPath(String path) async {
    final doc = await FirebaseFirestore.instance.doc(path).get();
    if (!doc.exists || doc.data() == null) return null;
    final raw = (doc.data()! as Map)['stock'];
    final parsed = _asIntOrNull(raw);
    return parsed ?? 0; // doc có nhưng không có field stock -> 0
  }

  // đọc stock (ưu tiên variant, fallback subcollection và product)
  Future<int?> _getStock({required String productId, String? variantId}) async {
    // 1) Có variantId -> thử 2 path: phẳng + subcollection
    if (variantId != null && variantId.isNotEmpty) {
      if (_variantStockCache.containsKey(variantId)) {
        return _variantStockCache[variantId];
      }
      int? s = await _readStockAtPath('variants/$variantId'); // phẳng
      s ??=
      await _readStockAtPath('products/$productId/variants/$variantId');
      _variantStockCache[variantId] = s;
      if (s != null) return s;
      // fallthrough -> thử product
    }

    // 2) Fallback: stock ở cấp product
    if (_productStockCache.containsKey(productId)) {
      return _productStockCache[productId];
    }
    final pdoc =
    await FirebaseFirestore.instance.doc('products/$productId').get();
    if (pdoc.exists && pdoc.data() != null) {
      final parsed = _asIntOrNull((pdoc.data()! as Map)['stock']);
      final s = parsed ?? 0; // doc có mà thiếu field -> 0
      _productStockCache[productId] = s;
      return s;
    }
    _productStockCache[productId] = null;
    return null; // thật sự không quản lý tồn
  }

  // =============================== UI ==================================
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Consumer<CartController>(
      builder: (context, cart, _) {
        final hasItems = cart.items.isNotEmpty;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Giỏ hàng'),
            centerTitle: true,
            elevation: 0.4,
            scrolledUnderElevation: 2,
          ),

          body: hasItems
              ? ListView.separated(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 130),
            itemCount: cart.items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) {
              final it = cart.items[i];
              final p = it.product;
              final price = it.unitPrice;
              final key = it.key;
              final isChecked = cart.selectedKeys.contains(key);
              final variantId = it.options?['variantId'] as String?;
              final sku = (variantId ?? p.id);

              final thumb = (p.imageUrl != null &&
                  p.imageUrl!.startsWith('http'))
                  ? Image.network(
                p.imageUrl!,
                fit: BoxFit.cover,
              )
                  : const Icon(Icons.image_outlined);

              return FutureBuilder<int?>(
                future:
                _getStock(productId: p.id, variantId: variantId),
                builder: (context, snap) {
                  final knowsStock =
                      snap.connectionState == ConnectionState.done;
                  final stock = snap.data; // int? (null = not managed)

                  // kẹp lại qty nếu > stock
                  if (knowsStock &&
                      stock != null &&
                      it.qty > stock) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (!mounted) return;
                      context.read<CartController>().setQtyClamped(
                        key,
                        it.qty,
                        stock: stock,
                      );
                    });
                  }

                  // Quy tắc bật nút "+"
                  final bool canPlus = knowsStock
                      ? (stock == null || it.qty < stock)
                      : false;

                  final bool outOfStock =
                      knowsStock && stock != null && stock == 0;

                  return Container(
                    decoration: BoxDecoration(
                      color: cs.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color:
                          cs.outlineVariant.withOpacity(0.7)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.03),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Checkbox chọn / bỏ chọn sản phẩm
                        Checkbox.adaptive(
                          value: isChecked,
                          onChanged: outOfStock
                              ? null
                              : (v) {
                            cart.toggleItemSelected(
                              key,
                              selected: v,
                            );
                          },
                          // ✅ thu nhỏ tap target để card gọn lại
                          materialTapTargetSize:
                          MaterialTapTargetSize.shrinkWrap,
                          visualDensity:
                          VisualDensity.compact,
                        ),
                        const SizedBox(width: 4),

                        // Thumbnail
                        ClipRRect(
                          borderRadius:
                          BorderRadius.circular(12),
                          child: SizedBox(
                            height: 70,
                            width: 70,
                            child: thumb,
                          ),
                        ),
                        const SizedBox(width: 10),

                        // Thông tin sản phẩm
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                            CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment:
                                CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Text(
                                      p.name,
                                      maxLines: 2,
                                      overflow:
                                      TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontWeight:
                                        FontWeight.w700,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      'SKU: $sku',
                                      maxLines: 1,
                                      overflow: TextOverflow
                                          .ellipsis,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: cs
                                            .onSurfaceVariant,
                                      ),
                                    ),
                                  ),
                                  if (outOfStock) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding:
                                      const EdgeInsets
                                          .symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color:
                                        cs.errorContainer,
                                        borderRadius:
                                        BorderRadius
                                            .circular(
                                          999,
                                        ),
                                      ),
                                      child: Text(
                                        'Hết hàng',
                                        style: TextStyle(
                                          color:
                                          cs.onErrorContainer,
                                          fontSize: 11,
                                          fontWeight:
                                          FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 8),

                              Row(
                                children: [
                                  // Giá
                                  Expanded(
                                    child: Text(
                                      _vnd(price),
                                      maxLines: 1,
                                      overflow: TextOverflow
                                          .ellipsis,
                                      style: const TextStyle(
                                        color:
                                        Color(0xFFCC9933),
                                        fontWeight:
                                        FontWeight.bold,
                                        fontSize: 15,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),

                                  // Stepper số lượng
                                  _QtyStepper(
                                    qty: it.qty,
                                    onMinus: it.qty > 1
                                        ? () => context
                                        .read<
                                        CartController>()
                                        .decrement(key)
                                        : null,
                                    onPlus: canPlus
                                        ? () {
                                      if (stock != null) {
                                        final ok = context
                                            .read<
                                            CartController>()
                                            .incrementClamped(
                                          key,
                                          stock:
                                          stock,
                                        );
                                        if (!ok) {
                                          ScaffoldMessenger
                                              .of(
                                              context)
                                              .showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                  'Chỉ còn $stock sản phẩm.'),
                                            ),
                                          );
                                        }
                                      } else {
                                        context
                                            .read<
                                            CartController>()
                                            .increment(
                                            key);
                                      }
                                    }
                                        : null,
                                  ),
                                ],
                              ),

                              if (knowsStock &&
                                  stock != null)
                                Padding(
                                  padding:
                                  const EdgeInsets.only(
                                      top: 3),
                                  child: Text(
                                    stock == 0
                                        ? 'Tạm thời hết hàng.'
                                        : 'Còn: $stock sản phẩm',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: stock == 0
                                          ? cs.error
                                          : cs.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),

                        // Nút xóa
                        SizedBox(
                          // ✅ giới hạn kích thước icon để tránh vượt bề ngang
                          width: 32,
                          height: 32,
                          child: IconButton(
                            tooltip: 'Xóa khỏi giỏ hàng',
                            padding: EdgeInsets.zero,
                            constraints:
                            const BoxConstraints.tightFor(
                                width: 32, height: 32),
                            iconSize: 20,
                            icon: const Icon(
                                Icons.close_rounded),
                            onPressed: () async {
                              final confirm =
                              await showDialog<bool>(
                                context: context,
                                builder: (_) => AlertDialog(
                                  title: const Text(
                                      'Xác nhận xóa'),
                                  content: Text(
                                      'Bạn có chắc muốn xóa "${p.name}" khỏi giỏ?'),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(
                                              context, false),
                                      child: const Text('Hủy'),
                                    ),
                                    FilledButton(
                                      onPressed: () =>
                                          Navigator.pop(
                                              context, true),
                                      child: const Text('Xóa'),
                                    ),
                                  ],
                                ),
                              );
                              if (confirm == true) {
                                context
                                    .read<CartController>()
                                    .remove(key);
                                ScaffoldMessenger.of(context)
                                    .showSnackBar(
                                  SnackBar(
                                    content: Text(
                                        'Đã xóa "${p.name}"'),
                                  ),
                                );
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          )
              : const _EmptyCart(), // 👈 giỏ trống: show gợi ý

          // ====================== BOTTOM BAR ======================
          bottomNavigationBar: hasItems
              ? SafeArea(
            child: Container(
              padding:
              const EdgeInsets.fromLTRB(16, 10, 16, 16),
              decoration: BoxDecoration(
                color: cs.surface,
                boxShadow: [
                  BoxShadow(
                    color:
                    Colors.black.withOpacity(.06),
                    blurRadius: 18,
                    offset: const Offset(0, -6),
                  )
                ],
                borderRadius:
                const BorderRadius.vertical(
                  top: Radius.circular(18),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    crossAxisAlignment:
                    CrossAxisAlignment.center,
                    children: [
                      // Chọn / bỏ chọn tất cả
                      Checkbox.adaptive(
                        value: cart.isAllSelected,
                        onChanged: (v) {
                          cart.toggleSelectAll(
                              selected: v);
                        },
                        // ✅ thu nhỏ để tránh chiếm quá nhiều ngang
                        materialTapTargetSize:
                        MaterialTapTargetSize.shrinkWrap,
                        visualDensity:
                        VisualDensity.compact,
                      ),
                      const Text('Tất cả'),
                      const Spacer(),
                      Column(
                        crossAxisAlignment:
                        CrossAxisAlignment.end,
                        children: [
                          Text(
                            'Tạm tính',
                            style: TextStyle(
                              fontWeight:
                              FontWeight.w600,
                              color:
                              cs.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _vnd(cart.selectedSubtotal -
                                cart.discountAmount),
                            style: TextStyle(
                              fontWeight:
                              FontWeight.w900,
                              fontSize: 18,
                              color: cs.primary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Chưa bao gồm phí vận chuyển (tính ở bước tiếp theo)',
                          style: TextStyle(
                            fontSize: 11,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ),
                      if (cart.selectedCount > 0)
                        Container(
                          padding:
                          const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4),
                          decoration: BoxDecoration(
                            color: cs.primary
                                .withOpacity(.08),
                            borderRadius:
                            BorderRadius.circular(
                                999),
                          ),
                          child: Text(
                            'Đã chọn ${cart.selectedCount}',
                            style: TextStyle(
                              fontSize: 11,
                              color: cs.primary,
                              fontWeight:
                              FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator
                                .pushNamedAndRemoveUntil(
                              context,
                              AppRoutes.root,
                                  (r) => false,
                              arguments: {'tab': 0},
                            );
                          },
                          icon: const Icon(
                              Icons.storefront_outlined),
                          label: const Text(
                              'Tiếp tục mua sắm'),
                          style:
                          OutlinedButton.styleFrom(
                            padding: const EdgeInsets
                                .symmetric(
                                vertical: 10),
                            shape:
                            RoundedRectangleBorder(
                              borderRadius:
                              BorderRadius.circular(
                                  999),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton.icon(
                          icon: const Icon(
                              Icons.payment),
                          label: Text(
                            'Thanh toán (${cart.selectedCount})',
                          ),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets
                                .symmetric(
                                vertical: 12),
                            shape:
                            RoundedRectangleBorder(
                              borderRadius:
                              BorderRadius.circular(
                                  999),
                            ),
                          ),
                          onPressed: !cart.hasSelection
                              ? null
                              : () {
                            final uid =
                                FirebaseAuth
                                    .instance
                                    .currentUser
                                    ?.uid;
                            if (uid == null) {
                              ScaffoldMessenger
                                  .of(context)
                                  .showSnackBar(
                                const SnackBar(
                                  content: Text(
                                      'Bạn chưa đăng nhập'),
                                ),
                              );
                              return;
                            }
                            Navigator.pushNamed(
                              context,
                              AppRoutes.checkout,
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          )
              : null,
        );
      },
    );
  }
}

// ========================== WIDGET STEPPER ==========================
class _QtyStepper extends StatelessWidget {
  final int qty;
  final VoidCallback? onMinus;
  final VoidCallback? onPlus;
  const _QtyStepper({
    required this.qty,
    required this.onMinus,
    required this.onPlus,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding:
      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _RoundedIconBtn(
            icon: Icons.remove_rounded,
            onTap: onMinus,
            enabled: onMinus != null,
          ),
          const SizedBox(width: 8),
          Text(
            '$qty',
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
          const SizedBox(width: 8),
          _RoundedIconBtn(
            icon: Icons.add_rounded,
            onTap: onPlus,
            enabled: onPlus != null,
          ),
        ],
      ),
    );
  }
}

class _RoundedIconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final bool enabled;

  const _RoundedIconBtn({
    required this.icon,
    required this.onTap,
    required this.enabled,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        width: 24,
        height: 24,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: enabled
              ? cs.surfaceVariant
              : cs.surfaceVariant.withOpacity(0.4),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Icon(
          icon,
          size: 16,
          color: enabled
              ? cs.onSurface
              : cs.onSurface.withOpacity(0.4),
        ),
      ),
    );
  }
}

// ======================= GIỎ TRỐNG + GỢI Ý ==========================
class _EmptyCart extends StatelessWidget {
  const _EmptyCart();

  // lấy sản phẩm gợi ý từ Firestore
  static Future<List<Product>> _loadRecommendations(
      String? uid) async {
    try {
      final q = FirebaseFirestore.instance
          .collection('products')
          .where('status', isEqualTo: 'active')
          .orderBy('createdAt', descending: true)
          .limit(10);

      final snap = await q.get();

      return snap.docs
          .map((d) =>
          Product.fromMap(d.data()..['id'] = d.id))
          .toList();
    } catch (e) {
      debugPrint('⚠️ loadRecommendations error: $e');

      // fallback: nếu thiếu index hoặc lỗi khác, vẫn cố lấy vài sản phẩm
      final snap = await FirebaseFirestore.instance
          .collection('products')
          .limit(10)
          .get();

      return snap.docs
          .map((d) =>
          Product.fromMap(d.data()..['id'] = d.id))
          .toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return FutureBuilder<List<Product>>(
      future: _EmptyCart._loadRecommendations(uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState ==
            ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator());
        }

        final products =
            snapshot.data ?? const <Product>[];

        return EmptyCartWithRecommendations(
          products: products,
          onShopNow: () {
            Navigator.pushNamedAndRemoveUntil(
              context,
              AppRoutes.root,
                  (r) => false,
              arguments: {'tab': 0},
            );
          },
        );
      },
    );
  }
}

class EmptyCartWithRecommendations extends StatelessWidget {
  final List<Product> products;
  final VoidCallback onShopNow;

  const EmptyCartWithRecommendations({
    super.key,
    required this.products,
    required this.onShopNow,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return SingleChildScrollView(
      padding:
      const EdgeInsets.fromLTRB(16, 24, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 40),
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: cs.primary.withOpacity(.08),
            ),
            child: Icon(Icons.shopping_cart_outlined,
                size: 46, color: cs.primary),
          ),
          const SizedBox(height: 16),
          Text(
            '"Hổng" có gì trong giỏ hết',
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w600),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            'Lướt CSES, lựa hàng ngay đi!',
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: cs.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: onShopNow,
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: cs.primary),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              padding: const EdgeInsets.symmetric(
                  horizontal: 24, vertical: 10),
            ),
            child: Text(
              'Mua sắm ngay!',
              style: TextStyle(
                color: cs.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 32),

          // Title "Có thể bạn cũng thích"
          Row(
            children: [
              Expanded(
                child: Divider(color: cs.outlineVariant),
              ),
              const SizedBox(width: 8),
              Text(
                'Có thể bạn cũng thích',
                style: theme.textTheme.titleMedium
                    ?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Divider(color: cs.outlineVariant),
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (products.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                'Hiện chưa có sản phẩm gợi ý.',
                style: TextStyle(
                  fontSize: 13,
                  color: cs.onSurfaceVariant,
                ),
              ),
            )
          else
            GridView.builder(
              physics:
              const NeverScrollableScrollPhysics(),
              shrinkWrap: true,
              itemCount: products.length,
              gridDelegate:
              const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.62,
              ),
              itemBuilder: (context, index) {
                final p = products[index];
                return _RecommendedProductCard(
                    product: p);
              },
            ),
        ],
      ),
    );
  }
}

class _RecommendedProductCard extends StatelessWidget {
  final Product product;

  const _RecommendedProductCard({required this.product});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () {
        // 👉 mở màn chi tiết, ProductDetailScreen đang nhận arguments là String productId
        Navigator.pushNamed(
          context,
          AppRoutes.productDetail,
          arguments: product.id,
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: cs.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment:
          CrossAxisAlignment.start,
          children: [
            // Ảnh sản phẩm
            AspectRatio(
              aspectRatio: 1,
              child: ClipRRect(
                borderRadius:
                const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
                child: product.imageUrl != null &&
                    product.imageUrl!.isNotEmpty
                    ? Image.network(
                  product.imageUrl!,
                  fit: BoxFit.cover,
                )
                    : Container(
                  color: cs.surfaceVariant,
                  child: Icon(
                    Icons
                        .image_not_supported_outlined,
                    color:
                    cs.onSurfaceVariant,
                  ),
                ),
              ),
            ),

            // Thông tin
            Padding(
              padding:
              const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 6),
              child: Column(
                crossAxisAlignment:
                CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    maxLines: 2,
                    overflow:
                    TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 13),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _vnd(product.price),
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  if (product.brandId != null &&
                      product.brandId!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      product.brandId!,
                      style: TextStyle(
                        fontSize: 11,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ===================== Voucher helper classes ======================
class VoucherSuggestion {
  final Voucher voucher;
  final double saved;
  VoucherSuggestion(
      {required this.voucher, required this.saved});
}

class VoucherReject {
  final Voucher voucher;
  final String reason;
  VoucherReject(
      {required this.voucher, required this.reason});
}

class VoucherSuggestionSheet extends StatelessWidget {
  final double subtotal;
  final List<VoucherSuggestion> matches;
  final List<VoucherReject> rejects;
  final ValueChanged<String> onApply;

  const VoucherSuggestionSheet({
    super.key,
    required this.subtotal,
    required this.matches,
    required this.rejects,
    required this.onApply,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text('Tạm tính: ${_vnd(subtotal)}',
                style: const TextStyle(
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            ...matches.map(
                  (m) => ListTile(
                title: Text(m.voucher.code),
                subtitle:
                Text('Tiết kiệm ${_vnd(m.saved)}'),
                trailing: ElevatedButton(
                  onPressed: () => onApply(m.voucher.code),
                  child: const Text('Áp dụng'),
                ),
              ),
            ),
            if (matches.isEmpty)
              const Text(
                  'Chưa có mã phù hợp cho giỏ hàng hiện tại.'),
          ],
        ),
      ),
    );
  }
}

String _vnd(num value) => '₫${value.toStringAsFixed(0).replaceAllMapped(
  RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (m) => ',',
)}';
