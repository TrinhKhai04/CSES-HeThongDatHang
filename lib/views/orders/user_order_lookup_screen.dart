import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../routes/app_routes.dart';

const _kBlue = Color(0xFF007AFF);

/// ============================================================================
/// 🔍 Tra cứu đơn hàng (User)
///  - Khách nhập MÃ ĐƠN CSES-XXXX-XXXX để xem lại đơn của mình
/// ============================================================================
class UserOrderLookupScreen extends StatefulWidget {
  const UserOrderLookupScreen({super.key});

  @override
  State<UserOrderLookupScreen> createState() => _UserOrderLookupScreenState();
}

class _UserOrderLookupScreenState extends State<UserOrderLookupScreen> {
  final _codeCtl = TextEditingController();

  bool _isSearching = false;
  bool _hasSearched = false;
  String? _errorText;

  DocumentSnapshot<Map<String, dynamic>>? _result;

  @override
  void dispose() {
    _codeCtl.dispose();
    super.dispose();
  }

  // ======================= FIRESTORE SEARCH =======================

  String _normalizeCode(String raw) {
    var s = raw.trim().toUpperCase();
    if (s.isEmpty) return '';
    s = s.replaceAll(' ', '');
    if (!s.startsWith('CSES')) {
      // nếu user chỉ nhập phần sau, VD 0412-XXXX => thêm prefix
      if (s.length >= 5) {
        s = 'CSES-$s';
      }
    }
    if (!s.startsWith('CSES-')) {
      s = s.replaceFirst('CSES', 'CSES-');
    }
    return s;
  }

  Future<void> _performSearch() async {
    final raw = _codeCtl.text.trim();
    if (raw.isEmpty) {
      setState(() {
        _hasSearched = false;
        _result = null;
        _errorText = null;
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _hasSearched = true;
      _errorText = null;
      _result = null;
    });

    try {
      final col = FirebaseFirestore.instance.collection('orders');

      // 1️⃣ Thử tìm theo documentId (mã dài acd-4770-89b2-...)
      final byId = await col.doc(raw).get();
      if (byId.exists) {
        setState(() {
          _result = byId;
        });
        return; // tìm được rồi thì dừng
      }

      // 2️⃣ Không có docId -> thử tìm theo orderCode (CSES-XXXX-XXXX)
      final code = _normalizeCode(raw);
      if (code.isNotEmpty) {
        final snap =
        await col.where('orderCode', isEqualTo: code).limit(1).get();

        if (snap.docs.isNotEmpty) {
          setState(() {
            _result = snap.docs.first;
          });
          return;
        }
      }

      // 3️⃣ Không tìm thấy gì
      setState(() {
        _result = null;
      });
    } catch (e) {
      setState(() {
        _errorText = 'Lỗi tra cứu: $e';
        _result = null;
      });
    } finally {
      if (mounted) {
        setState(() => _isSearching = false);
      }
    }
  }

  // ======================= UI =======================

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: isDark ? Colors.black : Colors.white,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        iconTheme: IconThemeData(
          color: isDark ? Colors.white : Colors.black,
        ),
        title: const Text(
          'Tra cứu đơn hàng',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: _kBlue,
          ),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: isDark
              ? const LinearGradient(
            colors: [Colors.black, Color(0xFF111111)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          )
              : const LinearGradient(
            colors: [Color(0xFFF7F9FF), Colors.white],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth > 700;
            final bottomPadding = MediaQuery.of(context).padding.bottom;

            return Stack(
              children: [
                Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 700),
                    child: Column(
                      children: [
                        const SizedBox(height: 8),
                        // Ô nhập mã đơn
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(24),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.06),
                                  blurRadius: 18,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                              border: Border.all(
                                color: cs.outlineVariant.withOpacity(0.3),
                              ),
                            ),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            child: Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _codeCtl,
                                    textInputAction: TextInputAction.search,
                                    onSubmitted: (_) => _performSearch(),
                                    decoration: const InputDecoration(
                                      isDense: true,
                                      contentPadding: EdgeInsets.symmetric(
                                        horizontal: 0,
                                        vertical: 8,
                                      ),
                                      prefixIcon: Icon(
                                        Icons.search,
                                        color: Colors.black54,
                                        size: 20,
                                      ),
                                      hintText:
                                      'Nhập mã đơn CSES-XXXX-XXXX để tra cứu',
                                      hintStyle: TextStyle(
                                        fontSize: 13,
                                        color: Colors.black38,
                                      ),
                                      border: InputBorder.none,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _kBlue,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 22,
                                      vertical: 10,
                                    ),
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                  ),
                                  onPressed:
                                  _isSearching ? null : _performSearch,
                                  child: _isSearching
                                      ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor:
                                      AlwaysStoppedAnimation<Color>(
                                        Colors.white,
                                      ),
                                    ),
                                  )
                                      : const Text(
                                    'Tìm',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Text(
                            'Bạn có thể lấy mã đơn trong mục "Đơn đã mua" hoặc email/SMS xác nhận đơn hàng.',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark
                                  ? Colors.white70
                                  : cs.onSurfaceVariant.withOpacity(0.9),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 200),
                            child: _buildResultBody(cs),
                          ),
                        ),
                        if (_errorText != null)
                          Container(
                            width: double.infinity,
                            color: cs.errorContainer,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            child: Text(
                              _errorText!,
                              style: TextStyle(
                                color: cs.onErrorContainer,
                                fontSize: 12,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),

                // Nút hướng dẫn
                Positioned(
                  left: isWide
                      ? (constraints.maxWidth - 700) / 2 + 20
                      : 20,
                  bottom: 16 + bottomPadding,
                  child: FloatingActionButton.small(
                    heroTag: 'user_lookup_help',
                    onPressed: _showHelpSheet,
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    elevation: 6,
                    child: const Icon(Icons.help_outline),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildResultBody(ColorScheme cs) {
    if (!_hasSearched) {
      return Center(
        key: const ValueKey('empty_prompt'),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.95),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    const Icon(
                      CupertinoIcons.search_circle,
                      size: 42,
                      color: _kBlue,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Nhập mã đơn để tra cứu',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Ví dụ: CSES-04AB-1C2D3E. Bạn có thể sao chép mã này từ màn "Đơn đã mua".',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
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

    if (_isSearching) {
      return const Center(
        key: ValueKey('loading'),
        child: CircularProgressIndicator(),
      );
    }

    if (_result == null) {
      return Center(
        key: const ValueKey('empty_result'),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                CupertinoIcons.exclamationmark_circle,
                size: 40,
                color: cs.error,
              ),
              const SizedBox(height: 6),
              const Text(
                'Không tìm thấy đơn hàng với mã bạn nhập.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Vui lòng kiểm tra lại mã đơn hoặc copy trực tiếp từ mục "Đơn đã mua".',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: cs.onSurfaceVariant,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      key: const ValueKey('result'),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
      children: [
        _UserOrderLookupCard(doc: _result!),
      ],
    );
  }

  void _showHelpSheet() {
    final cs = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: cs.outlineVariant,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const Text(
                  'Lấy mã đơn ở đâu?',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  '• Vào tab "Đơn đã mua" → chọn đơn → bấm icon copy mã.',
                  style: TextStyle(fontSize: 13),
                ),
                const Text(
                  '• Hoặc xem trong email/SMS xác nhận đơn hàng.',
                  style: TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Sau đó dán mã vào ô "Nhập mã đơn CSES-XXXX-XXXX" ở trên để tra cứu.',
                  style: TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Đã hiểu'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// ============================================================================
/// 🧾 Card hiển thị đơn (User)
/// ============================================================================
class _UserOrderLookupCard extends StatelessWidget {
  final DocumentSnapshot<Map<String, dynamic>> doc;

  const _UserOrderLookupCard({required this.doc});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final data = doc.data() ?? {};
    final orderId = doc.id;
    final orderCode = (data['orderCode'] ?? '').toString();
    final total = _toDouble(data['total']);
    final status = (data['status'] ?? 'pending').toString();
    final createdAt = data['createdAt'];
    final createdText = _fmtTimeAny(createdAt);

    final rawShipping = data['shippingAddress'];
    Map<String, dynamic> shipping = {};
    if (rawShipping is Map) {
      shipping = Map<String, dynamic>.from(rawShipping);
    }
    final name = (shipping['name'] ?? '').toString().trim();
    final phone = (shipping['phone'] ?? '').toString().trim();

    final statusColor = _statusColor(status);

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: cs.outlineVariant.withOpacity(0.4)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: InkWell(
          onTap: () {
            Navigator.pushNamed(
              context,
              AppRoutes.orderDetail, // route chi tiết đơn của user
              arguments: {
                'orderId': orderId,
                'orderCode': orderCode,
              },
            );
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      _kBlue.withOpacity(0.04),
                      _kBlue.withOpacity(0.12),
                    ],
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: _kBlue.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: const Icon(
                        CupertinoIcons.cube_box_fill,
                        size: 15,
                        color: _kBlue,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Đơn $orderCode',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        _viStatusLabel(status),
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              Padding(
                padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (createdText.isNotEmpty)
                      Row(
                        children: [
                          Icon(
                            CupertinoIcons.time,
                            size: 14,
                            color: cs.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            createdText,
                            style: TextStyle(
                              fontSize: 12,
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    if (name.isNotEmpty || phone.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            CupertinoIcons.person,
                            size: 14,
                            color: cs.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              [
                                if (name.isNotEmpty) name,
                                if (phone.isNotEmpty) phone,
                              ].join(' • '),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 10),
                    Divider(color: cs.outlineVariant.withOpacity(0.6)),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Text(
                          'Thành tiền',
                          style: TextStyle(
                            fontSize: 12,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          _vnd(total),
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: cs.onSurface,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: () {
                          Navigator.pushNamed(
                            context,
                            AppRoutes.orderDetail,
                            arguments: {
                              'orderId': orderId,
                              'orderCode': orderCode,
                            },
                          );
                        },
                        icon: const Icon(
                          CupertinoIcons.doc_text_search,
                          size: 16,
                          color: _kBlue,
                        ),
                        label: const Text(
                          'Xem chi tiết đơn',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: _kBlue,
                            decoration: TextDecoration.underline,
                            decorationThickness: 1,
                          ),
                        ),
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
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
  }
}

// ===================== Helpers =====================

double _toDouble(dynamic x) =>
    x is num ? x.toDouble() : double.tryParse('$x') ?? 0.0;

String _fmtTimeAny(dynamic raw) {
  if (raw == null) return '';
  DateTime? dt;
  if (raw is Timestamp) dt = raw.toDate();
  if (raw is DateTime) dt = raw;
  if (dt == null) return '';
  return DateFormat('HH:mm · dd/MM/yyyy').format(dt);
}

String _vnd(num value) {
  final s = value.toStringAsFixed(0);
  final buffer = StringBuffer();
  for (int i = 0; i < s.length; i++) {
    final rev = s.length - i;
    buffer.write(s[i]);
    if (rev > 1 && rev % 3 == 1) buffer.write(',');
  }
  return '₫${buffer.toString()}';
}

String _viStatusLabel(String s) {
  switch (s) {
    case 'pending':
      return 'Đang xử lý';
    case 'processing':
      return 'Đang xử lý';
    case 'shipping':
      return 'Đang giao';
    case 'delivered':
    case 'done':
    case 'completed':
      return 'Hoàn tất';
    case 'cancelled':
      return 'Đã hủy';
    default:
      return s;
  }
}

Color _statusColor(String s) {
  switch (s) {
    case 'done':
    case 'delivered':
    case 'completed':
      return const Color(0xFF34C759); // xanh
    case 'cancelled':
      return const Color(0xFFFF3B30); // đỏ
    case 'pending':
    case 'processing':
      return const Color(0xFFFF9500); // cam
    case 'shipping':
      return const Color(0xFF007AFF); // xanh dương
    default:
      return Colors.grey;
  }
}
