// lib/views/orders/orders_screen.dart
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../controllers/order_controller.dart';
import '../../models/app_order.dart';
import '../../models/product.dart';
import '../../routes/app_routes.dart';

/// ============================================================================
/// 🧾 OrdersScreen — Danh sách đơn của user (Apple-style, chuẩn Dark/Light)
/// + Có TabBar theo trạng thái giống Shopee
/// + Mỗi tab nếu rỗng sẽ hiện empty-state như giỏ hàng
/// ============================================================================
class OrdersScreen extends StatelessWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(
          centerTitle: true,
          title: Text(
            'Đơn đã mua',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        body: const Center(child: Text('Bạn chưa đăng nhập')),
      );
    }

    return DefaultTabController(
      length: 5,
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(
          backgroundColor: theme.appBarTheme.backgroundColor ?? cs.surface,
          foregroundColor: theme.appBarTheme.foregroundColor ?? cs.onSurface,
          elevation: theme.appBarTheme.elevation ?? 0,
          centerTitle: true,
          title: Text(
            'Đơn đã mua',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'Chờ xác nhận'),
              Tab(text: 'Chờ lấy hàng'),
              Tab(text: 'Chờ giao hàng'),
              Tab(text: 'Hoàn thành'),
              Tab(text: 'Đã huỷ'),
            ],
          ),
        ),

        /// Lắng nghe tất cả đơn của user
        body: StreamBuilder<List<AppOrder>>(
          stream:
          context.read<OrderController>().watchAllOrders(customerId: uid),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(
                  child: CupertinoActivityIndicator(radius: 14));
            }
            if (snap.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Lỗi: ${_prettyError(snap.error)}',
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }

            final orders = snap.data ?? const <AppOrder>[];

            // Nhóm theo trạng thái
            List<AppOrder> byStatus(bool Function(AppOrder) pred) =>
                orders.where(pred).toList();

            final pending = byStatus((o) => o.status == 'pending');
            final processing = byStatus((o) => o.status == 'processing');
            final shipping = byStatus((o) => o.status == 'shipping');
            final done = byStatus((o) =>
            o.status == 'done' ||
                o.status == 'completed' ||
                o.status == 'delivered');
            final cancelled = byStatus((o) => o.status == 'cancelled');

            return TabBarView(
              children: [
                _buildOrderList(
                  context,
                  pending,
                  statusLabel: 'Chờ xác nhận',
                ),
                _buildOrderList(
                  context,
                  processing,
                  statusLabel: 'Chờ lấy hàng',
                ),
                _buildOrderList(
                  context,
                  shipping,
                  statusLabel: 'Chờ giao hàng',
                ),
                _buildOrderList(
                  context,
                  done,
                  statusLabel: 'Hoàn thành',
                ),
                _buildOrderList(
                  context,
                  cancelled,
                  statusLabel: 'Đã huỷ',
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  /// Gói gọn hiển thị lỗi
  static String _prettyError(Object? err) {
    if (err == null) return 'Đã xảy ra lỗi không xác định';
    if (err is FirebaseException && (err.message?.isNotEmpty ?? false)) {
      return err.message!;
    }
    if (err is StateError) return err.message;
    if (err is AsyncError) return err.error.toString();
    return err.toString();
  }

  /// Xây list cho 1 tab + empty-state
  Widget _buildOrderList(
      BuildContext context,
      List<AppOrder> orders, {
        required String statusLabel,
      }) {
    if (orders.isEmpty) {
      return _OrdersEmptyTab(statusLabel: statusLabel);
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: orders.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, i) => _AppleOrderCard(order: orders[i]),
    );
  }
}

/// ============================================================================
/// 🧩 Thẻ đơn hàng + Nút Đánh giá (Realtime)
/// ============================================================================
class _AppleOrderCard extends StatelessWidget {
  final AppOrder order;
  const _AppleOrderCard({required this.order});

  bool get _isPending => order.status == 'pending';

  /// Đơn đã hoàn tất (đủ điều kiện đánh giá)
  bool get _isDone =>
      order.status == 'done' ||
          order.status == 'completed' ||
          order.status == 'delivered';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final text = theme.textTheme;
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ---------- Header ----------
          Row(
            children: [
              Expanded(
                child: Text(
                  'Đơn #${order.id.substring(0, 6).toUpperCase()}',
                  style:
                  text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              _StatusChip(status: order.status),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            _fmtTimestamp(order.createdAt),
            style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 10),

          // ---------- Tổng tiền ----------
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Tổng cộng',
                style:
                text.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
              ),
              Text(
                _vnd(order.total),
                style: text.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: cs.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // ---------- Actions ----------
          Row(
            children: [
              // 🔍 Chi tiết
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.receipt_long_outlined, size: 18),
                  label: const Text('Chi tiết'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: cs.onSurface,
                    side: BorderSide(color: cs.outlineVariant),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () {
                    Navigator.pushNamed(
                      context,
                      AppRoutes.orderDetail,
                      arguments: {
                        'orderId': order.id,
                        'customerId': order.customerId,
                      },
                    );
                  },
                ),
              ),
              const SizedBox(width: 12),

              // ❌ Huỷ (chỉ khi pending)
              if (_isPending)
                Expanded(
                  child: FilledButton.tonalIcon(
                    icon: const Icon(Icons.cancel_outlined, size: 18),
                    label: const Text('Huỷ đơn'),
                    style: FilledButton.styleFrom(
                      backgroundColor: cs.errorContainer,
                      foregroundColor: cs.onErrorContainer,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () => _onCancel(context),
                  ),
                ),

              // ⭐ Đánh giá / Đã đánh giá (realtime)
              if (_isDone && uid != null) ...[
                if (_isPending) const SizedBox() else const SizedBox(width: 12),
                Expanded(
                  child: StreamBuilder<bool>(
                    stream:
                    _watchAllReviewed(orderId: order.id, uid: uid),
                    builder: (context, snap) {
                      final allReviewed = snap.data == true;

                      if (allReviewed) {
                        return OutlinedButton.icon(
                          icon: const Icon(Icons.check_circle, size: 18),
                          label: const Text('Đã đánh giá'),
                          onPressed: null,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.green,
                            side: BorderSide(
                              color: Colors.green.withOpacity(.35),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        );
                      }

                      return FilledButton.icon(
                        icon: const Icon(Icons.rate_review_outlined),
                        label: const Text('Đánh giá'),
                        style: FilledButton.styleFrom(
                          backgroundColor: cs.primary,
                          foregroundColor: cs.onPrimary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () =>
                            _openReviewBottomSheet(context, order),
                      );
                    },
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  /// Xác nhận huỷ đơn
  Future<void> _onCancel(BuildContext context) async {
    final ok = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Huỷ đơn hàng?'),
        content:
        const Text('Bạn chỉ có thể huỷ khi đơn đang chờ xác nhận.'),
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

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CupertinoActivityIndicator()),
    );

    String? errorMsg;
    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      await context.read<OrderController>().cancelMyOrder(
        orderId: order.id,
        customerId: uid,
      );
    } catch (e) {
      errorMsg = e.toString();
    } finally {
      if (context.mounted) Navigator.pop(context); // đóng loading
    }

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          errorMsg == null
              ? 'Đã huỷ đơn thành công.'
              : 'Huỷ đơn thất bại: $errorMsg',
        ),
      ),
    );
  }

  /// 📡 Realtime: đã đánh giá hết item trong đơn chưa?
  Stream<bool> _watchAllReviewed({
    required String orderId,
    required String uid,
  }) {
    final orderRef =
    FirebaseFirestore.instance.collection('orders').doc(orderId);
    final itemsCol = orderRef.collection('items');
    final reviewsQ =
    orderRef.collection('reviews').where('userId', isEqualTo: uid);

    return Stream.fromFuture(itemsCol.get().then((s) => s.size))
        .asyncExpand((itemCount) {
      return reviewsQ.snapshots().map(
            (rev) => itemCount > 0 && rev.size >= itemCount,
      );
    });
  }

  /// Mở sheet viết đánh giá
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
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _OrderReviewSheet(uid: uid, order: order),
    );
  }
}

/// ============================================================================
/// 🪟 Bottom sheet: Danh sách item trong đơn + nút “Viết đánh giá”
/// ============================================================================
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
        .map((s) => s.docs.map((d) {
      final m = d.data();
      return _OrderItem(
        productId: '${m['productId'] ?? d.id}',
        name: '${m['name'] ?? ''}',
        imageUrl: m['imageUrl']?.toString(),
        qty: (m['qty'] ?? m['quantity'] ?? 1) as int,
      );
    }).toList());
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

    // 1) Lưu review trong products/{productId}/reviews
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

    // 2) Marker trong đơn
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

  Future<Map<String, dynamic>?> _openAppleReviewComposer(
      BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: cs.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => const _AppleReviewComposer(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.8,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, controller) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 4,
                width: 44,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: cs.outlineVariant,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              Text(
                'Đánh giá đơn #${order.id.substring(0, 6).toUpperCase()}',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
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
                        color: cs.outlineVariant.withOpacity(.35),
                      ),
                      itemBuilder: (_, i) {
                        final it = items[i];

                        return StreamBuilder<bool>(
                          stream: _reviewStatusStream(it.productId),
                          builder: (context, doneSnap) {
                            final reviewed = doneSnap.data == true;

                            return Padding(
                              padding:
                              const EdgeInsets.symmetric(vertical: 6),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  if (it.imageUrl != null &&
                                      it.imageUrl!.isNotEmpty)
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
                                      child: Image.network(
                                        it.imageUrl!,
                                        width: 48,
                                        height: 48,
                                        fit: BoxFit.cover,
                                      ),
                                    )
                                  else
                                    Container(
                                      width: 48,
                                      height: 48,
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        color: cs.surfaceContainerHighest,
                                        borderRadius:
                                        BorderRadius.circular(10),
                                      ),
                                      child: const Icon(
                                          Icons.inventory_2_outlined),
                                    ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          it.name,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
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
                                  reviewed
                                      ? Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.green
                                          .withOpacity(.12),
                                      borderRadius:
                                      BorderRadius.circular(999),
                                      border: Border.all(
                                        color: Colors.green
                                            .withOpacity(.25),
                                      ),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
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
                                            fontWeight: FontWeight.w600,
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
                                        horizontal: 14,
                                        vertical: 10,
                                      ),
                                      foregroundColor:
                                      const Color(0xFF0A84FF),
                                      backgroundColor:
                                      const Color(0xFF0A84FF)
                                          .withOpacity(.08),
                                      shape: RoundedRectangleBorder(
                                        borderRadius:
                                        BorderRadius.circular(999),
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
                                        res['rating'] as int,
                                        comment: res['comment']
                                        as String,
                                      );

                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                            content: Text(
                                                'Đã đánh giá ${it.name}'),
                                          ),
                                        );
                                      }
                                    },
                                    child: const Text(
                                      'Viết đánh giá',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
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

/// ============================================================================
/// ✍️ Composer viết đánh giá — Apple Store style (bottom sheet)
/// ============================================================================
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
    final cs = Theme.of(context).colorScheme;
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 42,
                height: 5,
                decoration: BoxDecoration(
                  color: cs.outlineVariant,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Viết đánh giá',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (i) {
                  final filled = i < _rating;
                  return IconButton(
                    splashRadius: 22,
                    onPressed: _submitting
                        ? null
                        : () => setState(() => _rating = i + 1),
                    icon: Icon(
                      filled
                          ? CupertinoIcons.star_fill
                          : CupertinoIcons.star,
                      color: filled ? Colors.amber : cs.outlineVariant,
                      size: 28,
                    ),
                  );
                }),
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: cs.outlineVariant),
                ),
                padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                    _submitting ? null : () => Navigator.pop(context),
                    child: const Text('Hủy'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    onPressed: _submitting || _ctl.text.trim().isEmpty
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
                      child:
                      CupertinoActivityIndicator(radius: 9),
                    )
                        : const Text('Gửi'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// ============================================================================
/// 🏷️ Chip trạng thái đơn (pastel, auto Dark/Light)
/// ============================================================================
class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    Color bg;
    Color fg;
    switch (status) {
      case 'pending':
        bg = cs.tertiaryContainer;
        fg = cs.onTertiaryContainer;
        break;
      case 'processing':
        bg = cs.secondaryContainer;
        fg = cs.onSecondaryContainer;
        break;
      case 'shipping':
        bg = cs.primaryContainer;
        fg = cs.onPrimaryContainer;
        break;
      case 'done':
      case 'completed':
      case 'delivered':
        bg = Colors.green.withOpacity(.15);
        fg = Colors.green.shade700;
        break;
      case 'cancelled':
        bg = cs.errorContainer;
        fg = cs.onErrorContainer;
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
      child: Text(
        _viLabel(status),
        style: TextStyle(
          color: fg,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
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

/// ============================================================================
/// 🫥 Empty-state cho từng tab (giống giỏ hàng Shopee)
/// ============================================================================
class _OrdersEmptyTab extends StatelessWidget {
  final String statusLabel;
  const _OrdersEmptyTab({required this.statusLabel});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final title = statusLabel.isEmpty
        ? '"Hổng" có đơn nào hết'
        : '"Hổng" có đơn ở mục $statusLabel';

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
      child: Column(
        children: [
          Icon(
            Icons.shopping_bag_outlined,
            size: 72,
            color: cs.primary,
          ),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Lướt CSES, đặt hàng ngay đi!',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: () {
              Navigator.pushNamedAndRemoveUntil(
                context,
                AppRoutes.root,
                    (r) => false,
                arguments: {'tab': 0},
              );
            },
            child: const Text('Mua sắm ngay!'),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              const Expanded(
                child: Divider(thickness: 0.6),
              ),
              const SizedBox(width: 12),
              Text(
                'Có thể bạn cũng thích',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Divider(thickness: 0.6),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const _OrderSuggestionsStrip(),
        ],
      ),
    );
  }
}

/// Dải sản phẩm gợi ý (scroll ngang)
class _OrderSuggestionsStrip extends StatelessWidget {
  const _OrderSuggestionsStrip();

  Future<List<Product>> _loadSuggestions() async {
    final snap = await FirebaseFirestore.instance
        .collection('products')
        .where('status', isEqualTo: 'active')
        .orderBy('createdAt', descending: true)
        .limit(10)
        .get();

    return snap.docs
        .map((d) => Product.fromMap(d.data()..['id'] = d.id))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return SizedBox(
      height: 230,
      child: FutureBuilder<List<Product>>(
        future: _loadSuggestions(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CupertinoActivityIndicator(radius: 12),
            );
          }

          final products = snap.data ?? const <Product>[];
          if (products.isEmpty) {
            return Center(
              child: Text(
                'Đang cập nhật sản phẩm…',
                style: TextStyle(color: cs.onSurfaceVariant),
              ),
            );
          }

          return ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: products.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, i) {
              final p = products[i];
              return SizedBox(
                width: 170,
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () {
                    Navigator.pushNamed(
                      context,
                      AppRoutes.productDetail,
                      arguments: p.id,
                    );
                  },
                  child: Ink(
                    decoration: BoxDecoration(
                      color: cs.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: cs.outlineVariant),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AspectRatio(
                          aspectRatio: 1,
                          child: ClipRRect(
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(14),
                            ),
                            child: p.imageUrl != null &&
                                p.imageUrl!.startsWith('http')
                                ? Image.network(
                              p.imageUrl!,
                              fit: BoxFit.cover,
                            )
                                : Container(
                              color: cs.surfaceContainerHighest,
                              child: Icon(
                                Icons.image_outlined,
                                size: 40,
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                p.name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _vnd(p.price),
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: cs.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

/// ------------ Helpers định dạng ngày & tiền ------------
String _fmtTimestamp(Timestamp? ts) {
  if (ts == null) return '';
  final d = ts.toDate();
  return DateFormat('dd/MM/yyyy HH:mm').format(d);
}

String _vnd(num n) {
  final f = NumberFormat.currency(locale: 'vi_VN', symbol: '₫');
  return f.format(n);
}
