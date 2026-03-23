import 'package:flutter/material.dart';

/// Màn hình hướng dẫn thanh toán qua MoMo (demo)
/// Nhận arguments:
/// {
///   'orderId': String,
///   'amount': double,
/// }
class PaymentMomoScreen extends StatelessWidget {
  const PaymentMomoScreen({super.key});

  String _vnd(num value) => '₫${value.toStringAsFixed(0).replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
        (m) => ',',
  )}';

  static const _momoColor = Color(0xFFE91E63); // hồng MoMo

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final args =
    ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final String orderId = (args?['orderId'] ?? '').toString();
    final double amount = (args?['amount'] as num?)?.toDouble() ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Thanh toán qua MoMo'),
        centerTitle: true,
      ),
      backgroundColor: cs.surface,
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ------- Banner thông báo nhỏ -------
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: cs.primary.withOpacity(0.06),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: cs.outlineVariant),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 20,
                    color: cs.primary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Hiện tại đây là màn hình demo mô phỏng thanh toán MoMo. '
                          'Bạn có thể tích hợp SDK MoMo / deep link thật sau.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ------- Card thanh toán MoMo -------
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: cs.outlineVariant),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Tiêu đề + icon MoMo
                  Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: _momoColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.account_balance_wallet_rounded,
                          color: _momoColor,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Thanh toán MoMo',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  if (orderId.isNotEmpty)
                    Row(
                      children: [
                        Text(
                          'Mã đơn: ',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            orderId,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  if (orderId.isNotEmpty) const SizedBox(height: 6),

                  if (amount > 0)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Số tiền cần thanh toán',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: _momoColor.withOpacity(0.09),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            _vnd(amount),
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: _momoColor,
                            ),
                          ),
                        ),
                      ],
                    ),

                  const SizedBox(height: 18),

                  // ------- Thẻ chứa QR MoMo -------
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                    decoration: BoxDecoration(
                      color: cs.surface,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: cs.outlineVariant),
                      boxShadow: [
                        if (theme.brightness == Brightness.light)
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                      ],
                    ),
                    child: Column(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: AspectRatio(
                            aspectRatio: 3 / 4,
                            child: Image.asset(
                              'assets/images/momo_qr.png', // QR của bạn
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Center(
                                child: Icon(
                                  Icons.qr_code_2_rounded,
                                  size: 80,
                                  color: cs.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Mở ứng dụng MoMo, chọn "Quét mã" và quét QR ở trên.\n'
                              'Kiểm tra lại số tiền và nội dung trước khi xác nhận thanh toán.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ------- Lưu ý nhỏ ở cuối -------
            Text(
              'Lưu ý: Ứng dụng hiện tại chưa kiểm tra tự động trạng thái thanh toán MoMo. '
                  'Sau khi chuyển tiền, vui lòng chờ shop kiểm tra và cập nhật trạng thái đơn hàng.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
