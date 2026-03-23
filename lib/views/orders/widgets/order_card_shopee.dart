// lib/views/orders/widgets/order_card_shopee.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../controllers/order_controller.dart';
import '../../../controllers/cart_controller.dart';
import '../../../models/app_order.dart';
import '../../../routes/app_routes.dart';

/// Card đơn hàng dùng chung cho trang "Đơn đã mua" kiểu Shopee.
class OrderCardShopee extends StatelessWidget {
  final AppOrder order;
  const OrderCardShopee({super.key, required this.order});

  bool get _isPending => order.status == 'pending';

  bool get _isDone =>
      order.status == 'done' ||
          order.status == 'completed' ||
          order.status == 'delivered';

  bool get _isCancelled => order.status == 'cancelled';

  /// Có thể mua lại khi đã giao/hoàn thành hoặc đã huỷ
  bool get _canReorder => _isDone || _isCancelled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final text = theme.textTheme;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      elevation: theme.brightness == Brightness.dark ? 0 : 0.8,
      shadowColor: cs.shadow.withOpacity(0.06),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => _openDetails(context),
        child: Container(
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: cs.outlineVariant.withOpacity(0.6)),
          ),
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header: Mã đơn + trạng thái ──────────────────────────────
              Row(
                children: [
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: cs.primary.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            CupertinoIcons.bag_fill,
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              'Đơn #${order.id.substring(0, 8).toUpperCase()}',
                              style: text.labelMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _StatusChip(status: order.status),
                ],
              ),
              const SizedBox(height: 6),

              // Ngày đặt
              Row(
                children: [
                  Icon(
                    CupertinoIcons.time,
                    size: 14,
                    color: cs.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      _fmtTimestamp(order.createdAt),
                      style: text.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),
              Divider(
                height: 1,
                color: cs.outlineVariant.withOpacity(0.4),
              ),
              const SizedBox(height: 10),

              // ── Tổng tiền (responsive, không overflow) ───────────────────
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Thành tiền',
                        style: text.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        _vnd(order.total),
                        style: text.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _isCancelled
                          ? 'Đơn đã huỷ'
                          : _isDone
                          ? 'Cảm ơn bạn đã mua sắm tại CSES'
                          : 'Đang xử lý đơn hàng…',
                      style: text.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.end,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              // ── Cụm 3 nút action ──────────────────────────
              _buildActionRow(context, cs),
            ],
          ),
        ),
      ),
    );
  }

  void _openDetails(BuildContext context) {
    Navigator.pushNamed(
      context,
      AppRoutes.orderDetail,
      arguments: {
        'orderId': order.id,
        'customerId': order.customerId,
      },
    );
  }

  // ================== CỤM ACTION ROW ==================

  Widget _buildActionRow(BuildContext context, ColorScheme cs) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    // Gom CTA thành list để dễ Wrap / Column
    final List<Widget> ctas = [];
    if (_isPending) {
      ctas.add(_buildCancelButton(context, cs));
    } else {
      if (_isDone && uid != null) {
        ctas.add(_buildReviewButton(context, cs, uid));
      }
      if (_canReorder) {
        if (ctas.isNotEmpty) ctas.add(const SizedBox(width: 6));
        ctas.add(_buildReorderButton(context, cs));
      }
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 360;

        // Màn nhỏ: chia 2 hàng, dùng Wrap cho CTA
        if (isNarrow) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: _buildDetailsTextButton(context, cs),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  alignment: WrapAlignment.end,
                  children: ctas,
                ),
              ),
            ],
          );
        }

        // Màn rộng: Row như cũ, nhưng CTA dùng Wrap tránh overflow
        return Row(
          children: [
            Flexible(
              child: Align(
                alignment: Alignment.centerLeft,
                child: _buildDetailsTextButton(context, cs),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Align(
                alignment: Alignment.centerRight,
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  alignment: WrapAlignment.end,
                  children: ctas,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// Nút "Xem chi tiết"
  Widget _buildDetailsTextButton(BuildContext context, ColorScheme cs) {
    return TextButton.icon(
      icon: const Icon(CupertinoIcons.doc_text_search, size: 18),
      label: const Text(
        'Xem chi tiết',
        overflow: TextOverflow.ellipsis,
      ),
      style: TextButton.styleFrom(
        foregroundColor: cs.onSurface,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
        ),
      ),
      onPressed: () => _openDetails(context),
    );
  }

  // ================== CÁC NÚT ACTION ==================

  Widget _buildCancelButton(BuildContext context, ColorScheme cs) {
    return FilledButton.tonalIcon(
      icon: const Icon(Icons.cancel_outlined, size: 18),
      label: const Text('Huỷ đơn', overflow: TextOverflow.ellipsis),
      style: FilledButton.styleFrom(
        backgroundColor: cs.errorContainer,
        foregroundColor: cs.onErrorContainer,
        minimumSize: const Size(0, 36),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
        ),
      ),
      onPressed: () => _onCancel(context),
    );
  }

  Widget _buildReorderButton(BuildContext context, ColorScheme cs) {
    return FilledButton.tonalIcon(
      icon: const Icon(Icons.shopping_bag_outlined, size: 18),
      label: const Text('Mua lại', overflow: TextOverflow.ellipsis),
      style: FilledButton.styleFrom(
        backgroundColor: cs.surfaceVariant,
        foregroundColor: cs.onSurface,
        minimumSize: const Size(0, 36),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
        ),
      ),
      onPressed: () => _onReorder(context),
    );
  }

  Widget _buildReviewButton(
      BuildContext context, ColorScheme cs, String uid) {
    return StreamBuilder<bool>(
      stream: _watchAllReviewed(orderId: order.id, uid: uid),
      builder: (context, snap) {
        final isLoading =
            snap.connectionState == ConnectionState.waiting && !snap.hasData;
        final allReviewed = snap.data == true;

        // Loading hoặc đã đánh giá hết → luôn hiện "Đã đánh giá"
        if (allReviewed || isLoading) {
          return OutlinedButton.icon(
            icon: const Icon(Icons.check_circle, size: 18),
            label: const Text('Đã đánh giá', overflow: TextOverflow.ellipsis),
            onPressed: null,
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.green,
              side: BorderSide(color: Colors.green.withOpacity(.35)),
              minimumSize: const Size(0, 36),
              padding: const EdgeInsets.symmetric(horizontal: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          );
        }

        // Chỉ khi chắc chắn là chưa đánh giá mới hiện "Đánh giá"
        return FilledButton.icon(
          icon: const Icon(Icons.rate_review_outlined, size: 18),
          label: const Text('Đánh giá', overflow: TextOverflow.ellipsis),
          style: FilledButton.styleFrom(
            backgroundColor: cs.primary,
            foregroundColor: cs.onPrimary,
            minimumSize: const Size(0, 36),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          onPressed: () => _openReviewBottomSheet(context, order),
        );
      },
    );
  }

  /// Xác nhận và huỷ đơn (có loading, không lỗi context)
  Future<void> _onCancel(BuildContext context) async {
    // Lấy context ổn định của root navigator
    final rootNavigator = Navigator.of(context, rootNavigator: true);
    final rootContext = rootNavigator.context;

    final orderController = context.read<OrderController>();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      ScaffoldMessenger.of(rootContext).showSnackBar(
        const SnackBar(content: Text('Bạn cần đăng nhập để huỷ đơn.')),
      );
      return;
    }

    // Hộp thoại xác nhận (dùng rootContext cho chắc)
    final ok = await showCupertinoDialog<bool>(
      context: rootContext,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Huỷ đơn hàng?'),
        content: const Text('Bạn chỉ có thể huỷ khi đơn đang chờ xác nhận.'),
        actions: [
          CupertinoDialogAction(
            child: const Text('Không'),
            onPressed: () => Navigator.pop(ctx, false),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: const Text('Đồng ý'),
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );

    if (ok != true) return;

    // ===== Loading dialog dùng rootContext =====
    showDialog(
      context: rootContext,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CupertinoActivityIndicator(),
      ),
    );

    String? err;
    try {
      await orderController.cancelMyOrder(
        orderId: order.id,
        customerId: uid,
      );
    } catch (e) {
      err = e.toString();
    }

    // Đóng loading
    rootNavigator.pop();

    // SnackBar báo kết quả
    ScaffoldMessenger.of(rootContext).showSnackBar(
      SnackBar(
        content: Text(
          err == null ? 'Đã huỷ đơn thành công.' : 'Huỷ đơn thất bại: $err',
        ),
      ),
    );
  }

  /// Mua lại
  Future<void> _onReorder(BuildContext context) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bạn cần đăng nhập để mua lại.')),
      );
      return;
    }

    String? err;
    int added = 0;

    try {
      debugPrint('🛒 [Reorder] start for order ${order.id}');
      final cart = context.read<CartController>();
      added = await cart.addFromOrder(order.id);
      debugPrint('🛒 [Reorder] done, added=$added');
    } catch (e, st) {
      err = e.toString();
      debugPrint('🛒 [Reorder] error: $e\n$st');
    }

    if (!context.mounted) return;

    if (err != null || added == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            err != null
                ? 'Mua lại thất bại: $err'
                : 'Không có sản phẩm nào để thêm vào giỏ.',
          ),
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Đã thêm $added sản phẩm vào giỏ hàng.')),
    );

    Navigator.pushNamed(context, AppRoutes.cart);
  }

  /// Realtime: đã đánh giá hết các item trong đơn chưa?
  static Stream<bool> _watchAllReviewed({
    required String orderId,
    required String uid,
  }) {
    final orderRef =
    FirebaseFirestore.instance.collection('orders').doc(orderId);
    final itemsCol = orderRef.collection('items');
    final reviewsQ =
    orderRef.collection('reviews').where('userId', isEqualTo: uid);

    // Dùng snapshots cho items để lấy được dữ liệu từ cache trước (đỡ delay)
    return itemsCol.snapshots().asyncExpand((itemsSnap) {
      final itemCount = itemsSnap.size;
      return reviewsQ.snapshots().map((revSnap) {
        if (itemCount == 0) return false;
        return revSnap.size >= itemCount;
      });
    });
  }

  void _openReviewBottomSheet(BuildContext context, AppOrder order) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bạn cần đăng nhập để đánh giá.')),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return _OrderReviewSheet(uid: uid, order: order);
      },
    );
  }
}

/// Chip trạng thái (pastel, auto Dark/Light)
class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    Color bg;
    Color fg;
    IconData? icon;
    switch (status) {
      case 'pending':
        bg = cs.tertiaryContainer;
        fg = cs.onTertiaryContainer;
        icon = CupertinoIcons.time;
        break;
      case 'processing':
        bg = cs.secondaryContainer;
        fg = cs.onSecondaryContainer;
        icon = CupertinoIcons.cube_box;
        break;
      case 'shipping':
        bg = cs.primaryContainer;
        fg = cs.onPrimaryContainer;
        icon = CupertinoIcons.car_detailed;
        break;
      case 'done':
      case 'completed':
      case 'delivered':
        bg = Colors.green.withOpacity(.12);
        fg = Colors.green.shade700;
        icon = CupertinoIcons.check_mark_circled_solid;
        break;
      case 'cancelled':
        bg = cs.errorContainer;
        fg = cs.onErrorContainer;
        icon = CupertinoIcons.xmark_circle_fill;
        break;
      default:
        bg = cs.surfaceVariant;
        fg = cs.onSurfaceVariant;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: fg),
            const SizedBox(width: 4),
          ],
          Text(
            _viLabel(status),
            style: TextStyle(
              color: fg,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  static String _viLabel(String s) {
    switch (s) {
      case 'pending':
        return 'Chờ xác nhận';
      case 'processing':
        return 'Chờ lấy hàng';
      case 'shipping':
        return 'Chờ giao hàng';
      case 'done':
      case 'completed':
      case 'delivered':
        return 'Hoàn thành';
      case 'cancelled':
        return 'Đã huỷ';
      default:
        return s;
    }
  }
}

// ================== Bottom sheet review & composer ==================

class _OrderReviewSheet extends StatelessWidget {
  final String uid;
  final AppOrder order;
  const _OrderReviewSheet({required this.uid, required this.order});

  Stream<List<_OrderItem>> _watchItems() {
    return FirebaseFirestore.instance
        .collection('orders')
        .doc(order.id)
        .collection('items')
        .snapshots()
        .map(
          (s) => s.docs.map((d) {
        final m = d.data();
        return _OrderItem(
          productId: '${m['productId'] ?? d.id}',
          name: '${m['name'] ?? ''}',
          imageUrl: m['imageUrl']?.toString(),
          qty: (m['qty'] ?? m['quantity'] ?? 1) as int,
        );
      }).toList(),
    );
  }

  Stream<bool> _reviewStatusStream(String productId) {
    return FirebaseFirestore.instance
        .collection('orders')
        .doc(order.id)
        .collection('reviews')
        .doc(productId)
        .snapshots()
        .map((d) => d.exists);
  }

  Future<void> _saveReview({
    required _OrderItem item,
    required int rating,
    required String comment,
  }) async {
    final batch = FirebaseFirestore.instance.batch();
    final now = FieldValue.serverTimestamp();

    // 1) Review thực tế của sản phẩm
    final prodReviewRef = FirebaseFirestore.instance
        .collection('products')
        .doc(item.productId)
        .collection('reviews')
        .doc('${uid}_${order.id}');
    batch.set(
      prodReviewRef,
      {
        'productId': item.productId,
        'orderId': order.id,
        'userId': uid,
        'userName':
        FirebaseAuth.instance.currentUser?.displayName ?? 'Người dùng',
        'rating': rating,
        'comment': comment,
        'createdAt': now,
      },
      SetOptions(merge: true),
    );

    // 2) Marker trong order
    final orderMarkerRef = FirebaseFirestore.instance
        .collection('orders')
        .doc(order.id)
        .collection('reviews')
        .doc(item.productId);
    batch.set(
      orderMarkerRef,
      {'productId': item.productId, 'userId': uid, 'createdAt': now},
      SetOptions(merge: true),
    );

    await batch.commit();
  }

  Future<bool> _checkAllReviewedAndRewardCoins(BuildContext context) async {
    final fs = FirebaseFirestore.instance;
    final orderRef = fs.collection('orders').doc(order.id);

    final itemsSnap = await orderRef.collection('items').get();
    final itemCount = itemsSnap.size;
    if (itemCount == 0) return false;

    final reviewsSnap = await orderRef
        .collection('reviews')
        .where('userId', isEqualTo: uid)
        .get();
    final reviewCount = reviewsSnap.size;
    if (reviewCount < itemCount) return false;

    await context.read<OrderController>().rewardCoinsForOrder(
      orderId: order.id,
      customerId: uid,
    );

    return true;
  }

  /// Sheet nhỏ “Viết đánh giá” – card nổi, tự đẩy lên theo bàn phím
  Future<Map<String, dynamic>?> _openAppleReviewComposer(
      BuildContext context) {
    return showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(.45),
      builder: (ctx) {
        // dùng ctx (context của bottom sheet) để lấy viewInsets
        return SafeArea(
          top: false,
          child: AnimatedPadding(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
            ),
            child: Align(
              alignment: Alignment.bottomCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: const _AppleReviewComposer(),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      minChildSize: 0.55,
      maxChildSize: 0.95,
      builder: (context, controller) {
        return Container(
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // thanh kéo
                    Center(
                      child: Container(
                        height: 4,
                        width: 44,
                        margin: const EdgeInsets.only(bottom: 14),
                        decoration: BoxDecoration(
                          color: cs.outlineVariant.withOpacity(.9),
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                    ),
                    Text(
                      'Đánh giá đơn #${order.id.substring(0, 6).toUpperCase()}',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: .2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Chạm “Viết đánh giá” cho từng sản phẩm để chia sẻ cảm nhận và nhận thưởng Xu.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Divider(
                      height: 1,
                      color: cs.outlineVariant.withOpacity(.5),
                    ),
                    const SizedBox(height: 6),
                    Expanded(
                      child: StreamBuilder<List<_OrderItem>>(
                        stream: _watchItems(),
                        builder: (context, snap) {
                          if (!snap.hasData) {
                            return const Center(
                              child: CupertinoActivityIndicator(radius: 12),
                            );
                          }
                          final items = snap.data!;
                          if (items.isEmpty) {
                            return const Center(
                              child: Text('Đơn hàng không có sản phẩm.'),
                            );
                          }

                          return ListView.separated(
                            controller: controller,
                            itemCount: items.length,
                            separatorBuilder: (_, __) => Divider(
                              height: 1,
                              color: cs.outlineVariant.withOpacity(.25),
                            ),
                            itemBuilder: (_, i) {
                              final it = items[i];

                              return StreamBuilder<bool>(
                                stream: _reviewStatusStream(it.productId),
                                builder: (context, doneSnap) {
                                  final reviewed = doneSnap.data == true;

                                  return Padding(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 8),
                                    child: Row(
                                      crossAxisAlignment:
                                      CrossAxisAlignment.center,
                                      children: [
                                        // ảnh
                                        if (it.imageUrl != null &&
                                            it.imageUrl!.isNotEmpty)
                                          ClipRRect(
                                            borderRadius:
                                            BorderRadius.circular(12),
                                            child: Image.network(
                                              it.imageUrl!,
                                              width: 52,
                                              height: 52,
                                              fit: BoxFit.cover,
                                            ),
                                          )
                                        else
                                          Container(
                                            width: 52,
                                            height: 52,
                                            alignment: Alignment.center,
                                            decoration: BoxDecoration(
                                              color: cs
                                                  .surfaceContainerHighest,
                                              borderRadius:
                                              BorderRadius.circular(12),
                                            ),
                                            child: Icon(
                                              Icons.inventory_2_outlined,
                                              color: cs.onSurfaceVariant,
                                            ),
                                          ),
                                        const SizedBox(width: 12),
                                        // tên + SL
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                it.name,
                                                maxLines: 2,
                                                overflow:
                                                TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                'SL: ${it.qty}',
                                                style: TextStyle(
                                                  color: cs.onSurfaceVariant,
                                                  fontSize: 13,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        // nút / chip
                                        reviewed
                                            ? Container(
                                          padding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.green
                                                .withOpacity(.10),
                                            borderRadius:
                                            BorderRadius.circular(
                                                999),
                                            border: Border.all(
                                              color: Colors.green
                                                  .withOpacity(.25),
                                            ),
                                          ),
                                          child: const Row(
                                            mainAxisSize:
                                            MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.check_circle,
                                                size: 16,
                                                color: Colors.green,
                                              ),
                                              SizedBox(width: 6),
                                              Text(
                                                'Đã đánh giá',
                                                style: TextStyle(
                                                  fontWeight:
                                                  FontWeight.w600,
                                                  color: Colors.green,
                                                ),
                                              ),
                                            ],
                                          ),
                                        )
                                            : TextButton(
                                          style: TextButton.styleFrom(
                                            padding: const EdgeInsets
                                                .symmetric(
                                              horizontal: 16,
                                              vertical: 10,
                                            ),
                                            foregroundColor:
                                            const Color(
                                                0xFF0A84FF),
                                            backgroundColor:
                                            const Color(0xFF0A84FF)
                                                .withOpacity(.06),
                                            shape:
                                            RoundedRectangleBorder(
                                              borderRadius:
                                              BorderRadius.circular(
                                                  999),
                                            ),
                                          ),
                                          onPressed: () async {
                                            final res =
                                            await _openAppleReviewComposer(
                                                context);
                                            if (res == null) return;

                                            await _saveReview(
                                              item: it,
                                              rating:
                                              res['rating'] as int? ??
                                                  5,
                                              comment:
                                              res['comment']
                                              as String? ??
                                                  '',
                                            );

                                            if (!context.mounted) {
                                              return;
                                            }

                                            ScaffoldMessenger.of(
                                                context)
                                                .showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  'Đã đánh giá ${it.name}',
                                                ),
                                              ),
                                            );

                                            try {
                                              final rewarded =
                                              await _checkAllReviewedAndRewardCoins(
                                                  context);
                                              if (rewarded &&
                                                  context.mounted) {
                                                ScaffoldMessenger.of(
                                                    context)
                                                    .showSnackBar(
                                                  const SnackBar(
                                                    content: Text(
                                                        '🎉 Bạn đã đánh giá tất cả sản phẩm. CSES Xu thưởng đã được cộng vào ví.'),
                                                  ),
                                                );
                                              }
                                            } catch (_) {}
                                          },
                                          child: const Text(
                                            'Viết đánh giá',
                                            style: TextStyle(
                                              fontWeight:
                                              FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _OrderItem {
  final String productId;
  final String name;
  final String? imageUrl;
  final int qty;
  _OrderItem({
    required this.productId,
    required this.name,
    this.imageUrl,
    required this.qty,
  });
}

/// Card nhỏ “Viết đánh giá” – giống screenshot, responsive
class _AppleReviewComposer extends StatefulWidget {
  const _AppleReviewComposer();

  @override
  State<_AppleReviewComposer> createState() => _AppleReviewComposerState();
}

class _AppleReviewComposerState extends State<_AppleReviewComposer> {
  int _rating = 5;
  final _ctl = TextEditingController();
  bool _submitting = false;
  static const int _maxLen = 300;

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final canSubmit =
        !_submitting && _ctl.text.trim().isNotEmpty && _rating > 0;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: cs.surface.withOpacity(0.98),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: cs.outlineVariant.withOpacity(.45),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.18),
            blurRadius: 26,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // thanh kéo nhỏ
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: cs.outlineVariant.withOpacity(.9),
              borderRadius: BorderRadius.circular(999),
            ),
          ),

          // Tiêu đề
          Text(
            'Viết đánh giá',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: .1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Chia sẻ cảm nhận để CSES phục vụ bạn tốt hơn.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: cs.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 14),

          // Hàng sao
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (i) {
              final filled = i < _rating;
              return IconButton(
                splashRadius: 22,
                onPressed:
                _submitting ? null : () => setState(() => _rating = i + 1),
                icon: Icon(
                  filled ? CupertinoIcons.star_fill : CupertinoIcons.star,
                  color: filled ? const Color(0xFFFFC93A) : cs.outlineVariant,
                  size: 28,
                ),
              );
            }),
          ),

          const SizedBox(height: 8),

          // Ô nhập nội dung
          Container(
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: cs.outlineVariant.withOpacity(.9)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: TextField(
              controller: _ctl,
              maxLines: 5,
              minLines: 3,
              maxLength: _maxLen,
              decoration: const InputDecoration(
                counterText: '',
                border: InputBorder.none,
                hintText: 'Chia sẻ cảm nhận của bạn…',
              ),
              enabled: !_submitting,
              onChanged: (_) => setState(() {}),
            ),
          ),

          const SizedBox(height: 10),

          // Hàng đếm ký tự + nút
          Row(
            children: [
              Text(
                '${_ctl.text.length}/$_maxLen',
                style: TextStyle(
                  color: cs.onSurfaceVariant,
                  fontSize: 13,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed:
                _submitting ? null : () => Navigator.pop(context, null),
                child: const Text('Hủy'),
              ),
              const SizedBox(width: 8),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: canSubmit
                      ? const Color(0xFF0A84FF)
                      : cs.surfaceVariant,
                  foregroundColor:
                  canSubmit ? Colors.white : cs.onSurfaceVariant,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 11,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: !canSubmit
                    ? null
                    : () {
                  setState(() => _submitting = true);
                  Navigator.pop<Map<String, dynamic>>(context, {
                    'rating': _rating,
                    'comment': _ctl.text.trim(),
                  });
                },
                child: _submitting
                    ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CupertinoActivityIndicator(radius: 9),
                )
                    : const Text('Gửi đánh giá'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---- Helpers ----
String _fmtTimestamp(Timestamp? ts) {
  if (ts == null) return '';
  final d = ts.toDate();
  return DateFormat('dd/MM/yyyy HH:mm').format(d);
}

String _vnd(num n) {
  final f = NumberFormat.currency(locale: 'vi_VN', symbol: '₫');
  return f.format(n);
}
