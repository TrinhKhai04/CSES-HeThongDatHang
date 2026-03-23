import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Màn hình hướng dẫn chuyển khoản ngân hàng cho đơn hàng
/// Nhận arguments:
/// {
///   'orderId': String,
///   'amount': double,
/// }
class PaymentBankTransferScreen extends StatelessWidget {
  const PaymentBankTransferScreen({super.key});

  String _vnd(num value) => '₫${value.toStringAsFixed(0).replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
        (m) => ',',
  )}';

  void _copy(BuildContext context, String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Đã sao chép $label'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final args =
    ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final String orderId = (args?['orderId'] ?? '').toString();
    final double amount = (args?['amount'] as num?)?.toDouble() ?? 0;

    final String contentHint = orderId.isEmpty
        ? 'SDT + Họ tên + Mã đơn (nếu có)'
        : 'SDT + Họ tên + Mã đơn: $orderId';

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text('Chuyển khoản ngân hàng'),
      ),
      backgroundColor: cs.surface,
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ---- Intro nhỏ phía trên ----
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_rounded,
                    size: 20,
                    color: cs.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Vui lòng chuyển khoản theo thông tin bên dưới. '
                          'Sau khi thanh toán xong, đơn hàng sẽ được cửa hàng xác nhận.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // -------- Thông tin tài khoản --------
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: cs.outlineVariant),
                boxShadow: [
                  BoxShadow(
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                    color: Colors.black.withValues(alpha: 0.04),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: cs.primary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.account_balance_rounded,
                          color: cs.primary,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Thông tin tài khoản',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _InfoRow(
                    label: 'Ngân hàng',
                    value: 'BIDV-CN NINH THUAN PGD PHAN RANG',
                  ),
                  const SizedBox(height: 6),
                  _InfoRow(
                    label: 'Số tài khoản',
                    value: '6160 207 058',
                    canCopy: true,
                    onCopy: () => _copy(context, '6160207058', 'số tài khoản'),
                  ),
                  const SizedBox(height: 6),
                  _InfoRow(
                    label: 'Chủ tài khoản',
                    value: 'TRINH QUANG KHAI',
                  ),
                  const SizedBox(height: 14),

                  if (orderId.isNotEmpty) ...[
                    _InfoRow(
                      label: 'Mã đơn',
                      value: orderId,
                      canCopy: true,
                      onCopy: () => _copy(context, orderId, 'mã đơn'),
                    ),
                    const SizedBox(height: 10),
                  ],

                  if (amount > 0) ...[
                    Text(
                      'Số tiền cần chuyển',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: cs.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.payments_rounded,
                            size: 18,
                            color: cs.primary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _vnd(amount),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: cs.primary,
                            ),
                          ),
                          const SizedBox(width: 4),
                          InkWell(
                            onTap: () => _copy(
                                context, amount.toStringAsFixed(0), 'số tiền'),
                            borderRadius: BorderRadius.circular(99),
                            child: Padding(
                              padding:
                              const EdgeInsets.symmetric(horizontal: 4),
                              child: Icon(
                                Icons.copy_rounded,
                                size: 16,
                                color: cs.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],

                  Text(
                    'Nội dung chuyển khoản (gợi ý)',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            contentHint,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: cs.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        InkWell(
                          onTap: () => _copy(context, contentHint, 'nội dung'),
                          borderRadius: BorderRadius.circular(99),
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: Icon(
                              Icons.copy_rounded,
                              size: 16,
                              color: cs.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // -------- QR chuyển khoản --------
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: cs.outlineVariant),
                boxShadow: [
                  BoxShadow(
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                    color: Colors.black.withValues(alpha: 0.04),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    'QR chuyển khoản',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Mở app ngân hàng, chọn quét QR và xác nhận số tiền.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: 180,
                    height: 180,
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Image.asset(
                        'assets/images/bank_qr.png', // 👈 QR của bạn
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Icon(
                          Icons.qr_code_2_rounded,
                          size: 80,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Text(
                  //   'Bạn có thể thay hình này bằng QR VietQR thật\n'
                  //       'của tài khoản ngân hàng ở trên.',
                  //   textAlign: TextAlign.center,
                  //   style: theme.textTheme.bodySmall?.copyWith(
                  //     color: cs.onSurfaceVariant,
                  //   ),
                  // ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // -------- Lưu ý --------
            Text(
              'Lưu ý: Đây là màn hình hướng dẫn. Ứng dụng hiện tại chưa kiểm tra '
                  'tự động trạng thái chuyển khoản, vui lòng chờ shop xác nhận.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
                fontSize: 11,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final bool highlight;
  final bool canCopy;
  final VoidCallback? onCopy;

  const _InfoRow({
    required this.label,
    required this.value,
    this.highlight = false,
    this.canCopy = false,
    this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final styleValue = Theme.of(context).textTheme.bodyMedium?.copyWith(
      fontWeight: highlight ? FontWeight.w700 : FontWeight.w600,
      color: highlight ? cs.primary : cs.onSurface,
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 110,
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
        ),
        Expanded(
          child: Row(
            children: [
              Expanded(
                child: SelectableText(
                  value,
                  style: styleValue,
                ),
              ),
              if (canCopy && onCopy != null)
                InkWell(
                  onTap: onCopy,
                  borderRadius: BorderRadius.circular(99),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(
                      Icons.copy_rounded,
                      size: 16,
                      color: cs.primary,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
