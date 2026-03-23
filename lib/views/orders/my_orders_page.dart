// lib/views/orders/my_orders_page.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/auth_controller.dart';
import '../../data/repositories/order_repository.dart';
import '../../models/app_order.dart';
import '../../models/product.dart';
import '../../routes/app_routes.dart';

// Card đơn hàng dùng chung có nút Chi tiết / Huỷ / Đánh giá / Mua lại
import 'widgets/order_card_shopee.dart';

class MyOrdersPage extends StatelessWidget {
  const MyOrdersPage({super.key});

  static const tabDefs = [
    // label, statuses
    ('Chờ xác nhận', ['pending']),
    ('Chờ lấy hàng', ['processing']),
    ('Chờ giao hàng', ['shipping']),
    ('Đã giao', ['delivered', 'done', 'completed']),
    ('Đã huỷ', ['cancelled']),
  ];

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final user = auth.user;

    // ⚠️ Nếu chưa đăng nhập → hiện placeholder, KHÔNG dùng Column full screen
    if (user == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Đơn đã mua'),
        ),
        body: const _NotLoggedInOrdersPlaceholder(),
      );
    }

    final customerId = user.uid;

    // 🔹 Đọc index tab truyền từ routes (nếu có)
    final args = ModalRoute.of(context)?.settings.arguments;
    int initialTabIndex = 0; // mặc định tab đầu "Chờ xác nhận"

    if (args is Map && args['initialTabIndex'] is int) {
      final idx = args['initialTabIndex'] as int;
      if (idx >= 0 && idx < tabDefs.length) {
        initialTabIndex = idx;
      }
    }

    return DefaultTabController(
      length: tabDefs.length,
      initialIndex: initialTabIndex,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Đơn đã mua'),
          bottom: TabBar(
            isScrollable: true,
            labelStyle: const TextStyle(fontWeight: FontWeight.w700),
            tabs: [for (final d in tabDefs) Tab(text: d.$1)],
          ),
        ),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: TabBarView(
          children: [
            for (final d in tabDefs)
              _OrdersTab(customerId: customerId, statuses: d.$2),
          ],
        ),
      ),
    );
  }
}

/// =========================
/// Tab danh sách đơn theo trạng thái
/// =========================
class _OrdersTab extends StatelessWidget {
  final String customerId;
  final List<String> statuses;
  const _OrdersTab({required this.customerId, required this.statuses});

  @override
  Widget build(BuildContext context) {
    final repo = OrderRepository();

    return StreamBuilder<List<AppOrder>>(
      stream: repo.watchByStatuses(customerId: customerId, statuses: statuses),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final orders = snap.data ?? const <AppOrder>[];

        if (orders.isEmpty) {
          return const _EmptyOrdersTab();
        }

        // 👇 SafeArea + ListView: luôn cuộn được trên mọi kích thước
        return SafeArea(
          top: false,
          bottom: true,
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 120),
            itemCount: orders.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) => OrderCardShopee(order: orders[i]),
          ),
        );
      },
    );
  }
}

/// =========================
/// Màn hình trống cho từng tab
/// + gợi ý sản phẩm giống giỏ hàng
/// =========================
class _EmptyOrdersTab extends StatelessWidget {
  const _EmptyOrdersTab();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final text = theme.textTheme;

    // DÙNG ListView cho toàn bộ nội dung → tránh Column overflow
    return SafeArea(
      top: false,
      bottom: true,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 32, 16, 120),
        children: [
          const SizedBox(height: 16),

          // Khối “chưa có đơn”
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.receipt_long_outlined,
                size: 64,
                color: cs.primary,
              ),
              const SizedBox(height: 16),
              Text(
                'Bạn chưa có đơn hàng nào',
                style: text.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Khám phá thêm sản phẩm phù hợp với bạn.',
                style: text.bodyMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: () {
                  Navigator.pushNamedAndRemoveUntil(
                    context,
                    AppRoutes.root,
                        (r) => false,
                    arguments: {'tab': 0}, // sang Home/Products
                  );
                },
                child: const Text('Mua sắm ngay!'),
              ),
            ],
          ),

          const SizedBox(height: 28),

          // Divider + tiêu đề "Có thể bạn cũng thích"
          Row(
            children: [
              Expanded(
                child: Divider(
                  thickness: 0.6,
                  color: cs.outlineVariant,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Có thể bạn cũng thích',
                style: text.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Divider(
                  thickness: 0.6,
                  color: cs.outlineVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Grid sản phẩm giống bên Cart (responsive)
          const _OrdersSuggestGrid(),
        ],
      ),
    );
  }
}

/// Grid “Có thể bạn cũng thích” — responsive theo màn hình
class _OrdersSuggestGrid extends StatelessWidget {
  const _OrdersSuggestGrid();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final query = FirebaseFirestore.instance
        .collection('products')
        .limit(10)
        .withConverter<Product>(
      fromFirestore: (snap, _) {
        final data = snap.data() ?? <String, dynamic>{};
        data['id'] = snap.id;
        return Product.fromMap(data);
      },
      toFirestore: (p, _) => p.toMap(),
    );

    return StreamBuilder<QuerySnapshot<Product>>(
      stream: query.snapshots(),
      builder: (context, snap) {
        if (snap.hasError) {
          return Center(
            child: Text(
              'Lỗi tải gợi ý:\n${snap.error}',
              textAlign: TextAlign.center,
              style: TextStyle(color: cs.error),
            ),
          );
        }

        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(strokeWidth: 1.5),
          );
        }

        if (!snap.hasData || snap.data!.docs.isEmpty) {
          return Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Center(
              child: Text(
                'Hiện chưa có gợi ý.',
                style: TextStyle(color: cs.onSurfaceVariant),
              ),
            ),
          );
        }

        final products = snap.data!.docs.map((d) => d.data()).toList();

        // 🔹 Dùng LayoutBuilder để auto thay đổi số cột & chiều cao item
        return LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;

            int crossAxisCount;
            if (width >= 900) {
              crossAxisCount = 4;
            } else if (width >= 600) {
              crossAxisCount = 3;
            } else {
              crossAxisCount = 2;
            }

            // 👉 Chiều cao item: ảnh vuông + phần text đủ rộng cho nhiều dòng / text scale
            final itemWidth =
                (width - (crossAxisCount - 1) * 12) / crossAxisCount;

            // Lấy text scale cụ thể của thiết bị để tăng chiều cao nếu user bật font lớn
            final textScale = MediaQuery.of(context).textScaleFactor;
            // Base: ảnh (itemWidth) + ~110px phần text
            final extraForText = 110.0 * textScale.clamp(1.0, 1.4);
            final mainAxisExtent = itemWidth + extraForText;

            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: products.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                mainAxisExtent: mainAxisExtent,
              ),
              itemBuilder: (context, i) {
                final p = products[i];
                return _OrderSuggestCard(product: p);
              },
            );
          },
        );
      },
    );
  }
}

class _OrderSuggestCard extends StatelessWidget {
  final Product product;
  const _OrderSuggestCard({required this.product});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () {
        Navigator.pushNamed(
          context,
          AppRoutes.productDetail,
          arguments: product.id,
        );
      },
      child: Ink(
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: cs.outlineVariant.withOpacity(.6)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(18),
                ),
                child: (product.imageUrl != null &&
                    product.imageUrl!.startsWith('http'))
                    ? Image.network(
                  product.imageUrl!,
                  fit: BoxFit.cover,
                )
                    : Container(
                  color: cs.surfaceVariant,
                  child: Icon(
                    Icons.image_outlined,
                    color: cs.onSurfaceVariant,
                    size: 32,
                  ),
                ),
              ),
            ),
            Padding(
              padding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _vnd(product.price),
                    style: TextStyle(
                      color: cs.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  if (product.sku != null && product.sku!.isNotEmpty)
                    Text(
                      product.sku!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: cs.onSurfaceVariant,
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

/// Khi chưa đăng nhập mà mở tab "Đơn đã mua"
class _NotLoggedInOrdersPlaceholder extends StatelessWidget {
  const _NotLoggedInOrdersPlaceholder();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    // 👉 Dùng SingleChildScrollView + Column mainAxisSize.min để auto hợp mọi kích thước
    return SafeArea(
      top: false,
      bottom: true,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.lock_outline,
                size: 64,
                color: cs.primary,
              ),
              const SizedBox(height: 16),
              Text(
                'Đăng nhập để xem đơn hàng',
                style: text.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Hãy đăng nhập để theo dõi lịch sử mua sắm và trạng thái đơn hàng của bạn.',
                style: text.bodyMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () {
                  Navigator.pushNamed(context, AppRoutes.login);
                },
                child: const Text('Đăng nhập ngay'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ------------ Helpers định dạng tiền ------------
String _vnd(num value) => '₫${value.toStringAsFixed(0).replaceAllMapped(
  RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (m) => '.',
)}';
