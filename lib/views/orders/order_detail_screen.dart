// lib/views/orders/order_detail_screen.dart
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';

import '../../controllers/order_controller.dart';
import '../../controllers/auth_controller.dart';
import '../../models/app_order.dart';
import '../../models/order_item.dart';

import 'order_route_page.dart';

/// Cho phép mở phần vận chuyển khi trạng thái từ processing trở lên
bool openShippingByStatus(String s) {
  return s == 'processing' ||
      s == 'shipping' ||
      s == 'delivered' ||
      s == 'done' ||
      s == 'completed';
}

class OrderDetailScreen extends StatelessWidget {
  const OrderDetailScreen({super.key});

  String _vnd(num v) =>
      NumberFormat.currency(locale: 'vi_VN', symbol: '₫').format(v);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    // Nền kiểu iOS grouped
    final pageBg = isDark ? const Color(0xFF000000) : const Color(0xFFF2F2F7);

    // Lấy role để biết có cần customerId hay không
    final isAdmin = context.watch<AuthController>().isAdmin;

    // Lấy arguments (có thể chỉ có orderId)
    final args = ModalRoute.of(context)?.settings.arguments;

    String? orderId;
    String? customerId;

    if (args is Map) {
      orderId = args['orderId'] as String?;
      customerId = args['customerId'] as String?;
    }

    // Với user thường: nếu không truyền customerId thì tự lấy uid hiện tại
    if (!isAdmin && (customerId == null || customerId.isEmpty)) {
      final user = context.read<AuthController>().user;
      customerId = user?.uid;
    }

    // Kiểm tra thiếu dữ liệu bắt buộc
    final missingOrderId = (orderId ?? '').isEmpty;
    final missingCustomerForUser = !isAdmin && ((customerId ?? '').isEmpty);

    if (missingOrderId || missingCustomerForUser) {
      return Scaffold(
        backgroundColor: pageBg,
        appBar: AppBar(
          centerTitle: true,
          elevation: 0,
          backgroundColor: pageBg,
          scrolledUnderElevation: 0,
          title: const Text('Chi tiết đơn hàng'),
        ),
        body: const Center(child: Text('❌ Thiếu thông tin đơn hàng')),
      );
    }

    // Từ đây chắc chắn đã đủ dữ liệu
    final String safeOrderId = orderId!;
    final String? safeCustomerId = customerId;

    final oc = context.read<OrderController>();

    return Scaffold(
      backgroundColor: pageBg,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: pageBg,
        surfaceTintColor: Colors.transparent,
        foregroundColor: theme.appBarTheme.foregroundColor ?? cs.onSurface,
        centerTitle: true,
        title: Text(
          'Chi tiết đơn hàng',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: 0.1,
          ),
        ),
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: isAdmin
            ? FirebaseFirestore.instance
            .collection('orders')
            .doc(safeOrderId)
            .snapshots()
            : FirebaseFirestore.instance
            .collection('users')
            .doc(safeCustomerId!) // user thường: đã check non-null
            .collection('orders')
            .doc(safeOrderId)
            .snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CupertinoActivityIndicator());
          }
          if (!snap.hasData || !snap.data!.exists) {
            return const Center(child: Text('Không tìm thấy đơn hàng.'));
          }

          final order = AppOrder.fromMap(snap.data!.data()!);

          // customerId dùng để load items: ưu tiên từ order, fallback sang safeCustomerId
          final String custForItems = order.customerId.trim().isNotEmpty
              ? order.customerId.trim()
              : (safeCustomerId ?? '');

          return FutureBuilder<List<OrderItem>>(
            future: oc.getItems(safeOrderId, customerId: custForItems),
            builder: (context, itemSnap) {
              if (itemSnap.connectionState == ConnectionState.waiting) {
                return const Center(child: CupertinoActivityIndicator());
              }

              final items = itemSnap.data ?? const <OrderItem>[];
              final createdAtStr = DateFormat('dd/MM/yyyy HH:mm')
                  .format(order.createdAt.toDate());

              final hasCoords = (order.whLat != null &&
                  order.whLng != null &&
                  order.toLat != null &&
                  order.toLng != null);

              // Lấy hình sản phẩm đầu tiên (nếu có)
              String? firstItemImageUrl;
              if (items.isNotEmpty) {
                final opts = items.first.options ?? const {};
                final dynamic img = opts['imageUrl'];
                if (img is String && img.trim().isNotEmpty) {
                  firstItemImageUrl = img.trim();
                }
              }

              // Thông tin người nhận
              final receiverName = (order.toName ?? '').trim();
              final receiverPhone = (order.toPhone ?? '').trim();
              final receiverEmail = (order.toEmail ?? '').trim();
              final shipNote = (order.shippingNote ?? '').trim();

              // phương thức vận chuyển (getter luôn non-null)
              final shipMethodDisplay = order.shippingMethodDisplay.trim();

              // phương thức thanh toán (getter luôn non-null, định nghĩa trong AppOrder)
              final paymentMethodDisplay =
              order.paymentMethodDisplay.trim();

              final fullAddr = order.fullToAddress;

              // 🪙 Xu đã dùng
              final usedXu = order.usedXu;
              final xuDiscount = order.xuDiscount;

              // subtitle cho dòng người nhận: gom SĐT + email
              final contactSubParts = <String>[];
              if (receiverPhone.isNotEmpty) {
                contactSubParts.add(receiverPhone);
              }
              if (receiverEmail.isNotEmpty) {
                contactSubParts.add(receiverEmail);
              }
              final contactSubtitle = contactSubParts.join(' · ');

              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                children: [
                  // ───── Thông tin đơn hàng ─────
                  _Section(
                    title: 'Thông tin đơn hàng',
                    child: Container(
                      decoration: _cardDecoration(cs),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Hàng đầu: Mã đơn + chip trạng thái
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: _InfoRow(
                                  label: 'Mã đơn',
                                  value: order.id,
                                  allowCopy: true,
                                ),
                              ),
                              const SizedBox(width: 8),
                              _StatusChip(status: order.status),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Ngày đặt: $createdAtStr',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: cs.onSurfaceVariant),
                          ),
                          const SizedBox(height: 16),

                          // ───────── Nhóm: Thông tin người nhận ─────────
                          Text(
                            'Thông tin người nhận',
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: cs.onSurface,
                            ),
                          ),
                          const SizedBox(height: 8),

                          // Dòng người nhận
                          _ContactLine(
                            icon: Icons.person_rounded,
                            title: receiverName.isNotEmpty
                                ? receiverName
                                : 'Chưa cập nhật tên',
                            subtitle: contactSubtitle.isNotEmpty
                                ? contactSubtitle
                                : null,
                          ),

                          // Địa chỉ
                          if (fullAddr.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            _ContactLine(
                              icon: Icons.location_on_rounded,
                              title: 'Địa chỉ nhận hàng',
                              subtitle: fullAddr,
                            ),
                          ],

                          const SizedBox(height: 16),
                          Divider(
                            height: 1,
                            color: cs.outlineVariant.withOpacity(0.3),
                          ),
                          const SizedBox(height: 10),

                          // ───────── Nhóm: Giao hàng & thanh toán ─────────
                          Text(
                            'Giao hàng & thanh toán',
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: cs.onSurface,
                            ),
                          ),
                          const SizedBox(height: 8),

                          // Phương thức vận chuyển
                          if (shipMethodDisplay.isNotEmpty) ...[
                            _ContactLine(
                              icon: Icons.local_shipping_rounded,
                              title: 'Phương thức vận chuyển',
                              subtitle: shipMethodDisplay,
                            ),
                            const SizedBox(height: 4),
                          ],

                          // Ghi chú giao hàng
                          if (shipNote.isNotEmpty) ...[
                            _ContactLine(
                              icon: Icons.sticky_note_2_rounded,
                              title: 'Ghi chú giao hàng',
                              subtitle: shipNote,
                            ),
                            const SizedBox(height: 4),
                          ],

                          // Hình thức thanh toán
                          if (paymentMethodDisplay.isNotEmpty) ...[
                            _ContactLine(
                              icon:
                              Icons.account_balance_wallet_rounded,
                              title: 'Hình thức thanh toán',
                              subtitle: paymentMethodDisplay,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Ẩn nếu không đủ điều kiện
                  if (hasCoords)
                    _ShippingGate(
                      order: order,
                      productImageUrl: firstItemImageUrl,
                    ),

                  const SizedBox(height: 16),

                  _Section(
                    title: 'Sản phẩm (${items.length})',
                    child: Container(
                      decoration: _cardDecoration(cs),
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        children: items.isEmpty
                            ? const [
                          Padding(
                            padding: EdgeInsets.all(12),
                            child: Text(
                                'Không có sản phẩm nào.'),
                          )
                        ]
                            : items
                            .map((it) => _OrderItemCard(item: it))
                            .toList(),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ───────── Tổng kết đơn hàng (UI mới) ─────────
                  _Section(
                    title: 'Tổng kết đơn hàng',
                    child: Container(
                      decoration: _cardDecoration(cs),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          _SummaryLine(
                            label: 'Tạm tính',
                            value: order.subtotal,
                            format: _vnd,
                          ),

                          if (order.discount > 0)
                            _SummaryLine(
                              label: 'Giảm giá',
                              value: -order.discount,
                              format: _vnd,
                              valueColor: Colors.green,
                            ),

                          if (xuDiscount > 0)
                            _SummaryLine(
                              label: 'Thanh toán bằng CSES Xu',
                              value: -xuDiscount,
                              format: _vnd,
                              valueColor: Colors.green,
                              caption: '$usedXu Xu',
                            ),

                          _SummaryLine(
                            label: 'Phí vận chuyển',
                            value: order.shipping,
                            format: _vnd,
                          ),

                          const SizedBox(height: 10),
                          Divider(
                            color:
                            cs.outlineVariant.withOpacity(0.4),
                            height: 24,
                          ),
                          const SizedBox(height: 8),

                          _SummaryTotalLine(
                            label: 'Tổng thanh toán',
                            value: order.total,
                            format: _vnd,
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

// ---------- helpers UI ----------

BoxDecoration _cardDecoration(ColorScheme cs) {
  final isDark = cs.brightness == Brightness.dark;
  final Color cardBg =
  isDark ? const Color(0xFF1C1C1E) : Colors.white;

  return BoxDecoration(
    color: cardBg,
    borderRadius: BorderRadius.circular(18),
    border: Border.all(
      color: cs.outlineVariant.withOpacity(isDark ? 0.4 : 0.25),
      width: 0.8,
    ),
    boxShadow: isDark
        ? null
        : [
      BoxShadow(
        color: cs.shadow.withOpacity(0.06),
        blurRadius: 18,
        offset: const Offset(0, 10),
      ),
    ],
  );
}

class _Section extends StatelessWidget {
  final String title;
  final Widget child;
  const _Section({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final Color headText =
    isDark ? const Color(0xFF98989F) : const Color(0xFF6B7280);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding:
          const EdgeInsets.only(left: 4, bottom: 6, top: 4),
          child: Text(
            title,
            style: text.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: 0.1,
              fontSize: 15,
              color: headText,
            ),
          ),
        ),
        child,
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final bool allowCopy;
  const _InfoRow({
    required this.label,
    required this.value,
    this.allowCopy = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: text.bodySmall?.copyWith(
            color: cs.onSurfaceVariant,
            fontWeight: FontWeight.w500,
            fontSize: 11,
          ),
        ),
        const SizedBox(height: 2),
        Row(
          children: [
            Expanded(
              child: Text(
                value,
                style: text.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (allowCopy)
              IconButton(
                tooltip: 'Sao chép',
                icon: const Icon(Icons.copy_rounded, size: 18),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints.tightFor(
                  width: 32,
                  height: 32,
                ),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: value));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content:
                      Text('📋 Đã sao chép mã đơn hàng.'),
                    ),
                  );
                },
              ),
          ],
        ),
      ],
    );
  }
}

/// Dòng thông tin kiểu Apple Store: icon trong ô vuông + title + subtitle
class _ContactLine extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;

  const _ContactLine({
    required this.icon,
    required this.title,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest
                  .withOpacity(0.9),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(
              icon,
              size: 18,
              color: cs.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface,
                  ),
                ),
                if (subtitle != null &&
                    subtitle!.trim().isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: text.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Dòng giá bình thường trong phần tổng kết
class _SummaryLine extends StatelessWidget {
  final String label;
  final double value;
  final String Function(num) format;
  final Color? valueColor;
  final String? caption; // ví dụ: "9800 Xu"

  const _SummaryLine({
    required this.label,
    required this.value,
    required this.format,
    this.valueColor,
    this.caption,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    final Color valCol = valueColor ?? cs.onSurface;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: caption == null
            ? CrossAxisAlignment.center
            : CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: text.bodyMedium?.copyWith(
                    color: cs.onSurface,
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
                if (caption != null && caption!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      caption!,
                      style: text.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Text(
            format(value),
            style: text.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: valCol,
            ),
          ),
        ],
      ),
    );
  }
}

/// Dòng tổng thanh toán – nổi bật hơn
class _SummaryTotalLine extends StatelessWidget {
  final String label;
  final double value;
  final String Function(num) format;

  const _SummaryTotalLine({
    required this.label,
    required this.value,
    required this.format,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: text.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
              fontSize: 15,
              color: cs.onSurface,
            ),
          ),
        ),
        Text(
          format(value),
          style: text.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
            fontSize: 18,
            color: cs.primary,
          ),
        ),
      ],
    );
  }
}

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
        bg = cs.surfaceContainerHigh;
        fg = cs.onSurfaceVariant;
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
        bg = const Color(0x2628A745);
        fg = Colors.greenAccent.shade700;
        break;
      case 'cancelled':
        bg = cs.errorContainer;
        fg = cs.onErrorContainer;
        break;
      default:
        bg = cs.surfaceContainerHighest;
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
        return 'Đang xử lý';
      case 'shipping':
        return 'Đang giao hàng';
      case 'done':
      case 'completed':
      case 'delivered':
        return 'Hoàn tất';
      case 'cancelled':
        return 'Đã hủy';
      default:
        return s;
    }
  }
}

class _OrderItemCard extends StatelessWidget {
  final OrderItem item;
  const _OrderItemCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final opts = item.options ?? const {};
    final imageUrl = (opts['imageUrl'] ?? '') as String;
    final variant =
    (opts['variantName'] ?? '${opts['size'] ?? ''} ${opts['color'] ?? ''}')
        .toString()
        .trim();
    final name = (opts['name'] ?? 'Sản phẩm') as String;
    final total = item.qty * item.price;
    final format =
    NumberFormat.currency(locale: 'vi_VN', symbol: '₫');

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: cs.outlineVariant.withOpacity(0.35),
        ),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: imageUrl.isNotEmpty
                ? Image.network(
              imageUrl,
              width: 60,
              height: 60,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _imgPh(cs),
            )
                : _imgPh(cs),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (variant.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      variant,
                      style: TextStyle(
                        color: cs.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                  ),
                const SizedBox(height: 4),
                Text(
                  'SL: ${item.qty} × ${format.format(item.price)}',
                  style: TextStyle(
                    color: cs.onSurfaceVariant,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            format.format(total),
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }

  Widget _imgPh(ColorScheme cs) => Container(
    width: 60,
    height: 60,
    alignment: Alignment.center,
    color: cs.surfaceContainerHighest,
    child: Icon(
      Icons.image_outlined,
      color: cs.onSurfaceVariant,
    ),
  );
}

/// ───────────────────── Widget: quyết định ẨN/HIỆN mục vận chuyển ─────────────────────
class _ShippingGate extends StatelessWidget {
  final AppOrder order;
  final String? productImageUrl;
  const _ShippingGate({
    required this.order,
    this.productImageUrl,
  });

  @override
  Widget build(BuildContext context) {
    // kiểm tra có ít nhất 1 track chưa
    final trackOnce = FirebaseFirestore.instance
        .collection('orders')
        .doc(order.id)
        .collection('tracks')
        .limit(1)
        .snapshots();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: trackOnce,
      builder: (context, snap) {
        final hasTrack = (snap.data?.docs.isNotEmpty ?? false);
        final canOpen = openShippingByStatus(order.status) || hasTrack;

        if (!canOpen) return const SizedBox.shrink(); // Ẩn hẳn

        // Đủ điều kiện → hiển thị Section + Card
        return _Section(
          title: 'Thông tin vận chuyển',
          child: ShippingInfoCard(
            order: order,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => OrderRoutePage(
                    order: order,
                    productImageUrl: productImageUrl,
                  ),
                  fullscreenDialog: true,
                ),
              );
            },
          ),
        );
      },
    );
  }
}

/// ───────────────────── 🧭 Card: Thông tin vận chuyển (tap → mở map) ─────────────────────
class ShippingInfoCard extends StatelessWidget {
  final AppOrder order;
  final VoidCallback onTap;
  const ShippingInfoCard({
    super.key,
    required this.order,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    String statusVi(String s) {
      switch (s) {
        case 'delivered':
        case 'done':
        case 'completed':
          return 'Đã giao';
        case 'shipping':
          return 'Đang giao hàng';
        case 'processing':
          return 'Đang xử lý';
        default:
          return 'Chờ xác nhận';
      }
    }

    final eta = order.routeDurationMin;
    final etaText = (eta != null && eta > 0)
        ? 'Dự kiến ~ ${eta.round()} phút'
        : 'Nhấn để xem bản đồ';

    // hiển thị phương thức vận chuyển
    final methodName = (order.shippingMethodName ?? '').trim();
    final methodSubtitle = (order.shippingMethodSubtitle ?? '').trim();

    final titleText =
    methodName.isNotEmpty ? methodName : 'Thông tin vận chuyển';

    final subParts = <String>[
      statusVi(order.status),
      etaText,
    ];
    if (methodSubtitle.isNotEmpty) {
      subParts.add(methodSubtitle);
    }
    final subText = subParts.join(' · ');

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        decoration: _cardDecoration(cs),
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: cs.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.local_shipping_rounded,
                color: cs.onPrimaryContainer,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titleText,
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subText,
                    style: TextStyle(
                      color: cs.onSurfaceVariant,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded),
          ],
        ),
      ),
    );
  }
}
