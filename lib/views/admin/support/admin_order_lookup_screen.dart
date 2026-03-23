import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../routes/app_routes.dart';

const _kBlue = Color(0xFF007AFF);

/// ============================================================================
/// 🔍 Tra cứu đơn hàng (Admin) – có filter trạng thái + responsive
/// ============================================================================

class AdminOrderLookupScreen extends StatefulWidget {
  const AdminOrderLookupScreen({super.key});

  @override
  State<AdminOrderLookupScreen> createState() =>
      _AdminOrderLookupScreenState();
}

class _AdminOrderLookupScreenState extends State<AdminOrderLookupScreen> {
  final TextEditingController _searchController = TextEditingController();

  bool _isSearching = false;
  String _lastQuery = '';
  String? _errorText;

  /// Kết quả sau khi áp filter
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _results = [];

  /// Tất cả docs match theo nội dung search (chưa lọc status)
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _allMatches = [];

  /// Filter trạng thái: all / pending / shipping / done / cancelled
  String _statusFilter = 'all';

  static const _statusChips = [
    {'id': 'all', 'label': 'Tất cả'},
    {'id': 'pending', 'label': 'Đang xử lý'},
    {'id': 'shipping', 'label': 'Đang giao'},
    {'id': 'done', 'label': 'Hoàn tất'},
    {'id': 'cancelled', 'label': 'Đã hủy'},
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ======================= FIRESTORE SEARCH =======================

  Future<void> _performSearch() async {
    final raw = _searchController.text.trim();
    if (raw.isEmpty) {
      setState(() {
        _lastQuery = '';
        _results = [];
        _allMatches = [];
        _errorText = null;
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _lastQuery = raw;
      _errorText = null;
    });

    try {
      // Lấy khoảng 200 đơn mới nhất
      final qs = await FirebaseFirestore.instance
          .collection('orders')
          .orderBy('createdAt', descending: true)
          .limit(200)
          .get();

      final docs = qs.docs;
      final matching = docs.where((doc) => _matchesQuery(doc, raw)).toList();

      setState(() {
        _allMatches = matching;
        _results = _applyStatusFilter(matching, _statusFilter);
      });
    } catch (e) {
      setState(() {
        _errorText = 'Lỗi tra cứu: $e';
        _results = [];
        _allMatches = [];
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSearching = false;
        });
      }
    }
  }

  bool _matchesQuery(
      QueryDocumentSnapshot<Map<String, dynamic>> doc, String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return false;

    final data = doc.data();
    final orderId = doc.id.toLowerCase();
    final orderCode = (data['orderCode'] ?? '').toString().toLowerCase();
    final customerId = (data['customerId'] ?? '').toString().toLowerCase();
    final email = (data['email'] ?? data['customerEmail'] ?? '')
        .toString()
        .toLowerCase();

    // shippingAddress có thể là Map hoặc String
    final rawShipping = data['shippingAddress'];
    Map<String, dynamic> shipping = {};
    if (rawShipping is Map) {
      shipping = Map<String, dynamic>.from(rawShipping);
    }

    final name =
    (shipping['name'] ?? data['toName'] ?? '').toString().toLowerCase();
    final phone =
    (shipping['phone'] ?? data['toPhone'] ?? '').toString().toLowerCase();

    final plainQuery = q.replaceAll('cses-', '').replaceAll('cses', '').trim();

    return orderId.contains(plainQuery) ||
        orderCode.contains(q) ||
        customerId.contains(q) ||
        email.contains(q) ||
        phone.contains(q) ||
        name.contains(q);
  }

  /// Áp filter trạng thái trên list đã match nội dung
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _applyStatusFilter(
      List<QueryDocumentSnapshot<Map<String, dynamic>>> list,
      String filter,
      ) {
    if (filter == 'all') {
      return List<QueryDocumentSnapshot<Map<String, dynamic>>>.from(list);
    }

    bool Function(String) matchStatus;

    switch (filter) {
      case 'pending':
      // Gom các trạng thái đang xử lý
        matchStatus = (s) => s == 'pending' || s == 'processing';
        break;
      case 'shipping':
        matchStatus = (s) => s == 'shipping';
        break;
      case 'done':
        matchStatus = (s) =>
        s == 'done' || s == 'completed' || s == 'delivered';
        break;
      case 'cancelled':
        matchStatus = (s) => s == 'cancelled';
        break;
      default:
        return List<QueryDocumentSnapshot<Map<String, dynamic>>>.from(list);
    }

    return list.where((doc) {
      final status = (doc.data()['status'] ?? 'pending').toString();
      return matchStatus(status);
    }).toList();
  }

  void _onStatusFilterChanged(String id) {
    if (_statusFilter == id) return;
    setState(() {
      _statusFilter = id;
      _results = _applyStatusFilter(_allMatches, _statusFilter);
    });
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
                        // Card search
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
                                    controller: _searchController,
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
                                      'Nhập mã đơn / email / SĐT / tên người nhận',
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
                            'Hệ thống sẽ tìm trong các đơn mới nhất (tối đa ~200 đơn).',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark
                                  ? Colors.white70
                                  : cs.onSurfaceVariant.withOpacity(0.9),
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),

                        // ===== Thanh filter trạng thái =====
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: _buildStatusFilterBar(cs),
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

                // Nút tips tròn
                Positioned(
                  left: isWide
                      ? (constraints.maxWidth - 700) / 2 + 20
                      : 20,
                  bottom: 16 + bottomPadding,
                  child: FloatingActionButton.small(
                    heroTag: 'lookup_help',
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

  Widget _buildStatusFilterBar(ColorScheme cs) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _statusChips.map((chip) {
          final id = chip['id'] as String;
          final label = chip['label'] as String;
          final selected = _statusFilter == id;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(label),
              selected: selected,
              onSelected: (_) => _onStatusFilterChanged(id),
              labelStyle: TextStyle(
                fontSize: 12,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                color: selected
                    ? Colors.white
                    : (isDark ? Colors.white70 : cs.onSurfaceVariant),
              ),
              backgroundColor:
              isDark ? const Color(0xFF222222) : Colors.white,
              selectedColor: _kBlue,
              side: BorderSide(
                color: selected
                    ? Colors.transparent
                    : _kBlue.withOpacity(0.4),
              ),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildResultBody(ColorScheme cs) {
    if (_lastQuery.isEmpty) {
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
                  color: Colors.white.withOpacity(0.9),
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
                      'Nhập thông tin để tra cứu đơn hàng',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Bạn có thể dùng email, số điện thoại, mã đơn hoặc tên người nhận.',
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

    if (_results.isEmpty) {
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
              Text(
                'Không tìm thấy đơn phù hợp với:\n“$_lastQuery”.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: cs.onSurface,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Hãy thử kiểm tra lại mã đơn hoặc dùng email / số điện thoại.',
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

    return ListView.separated(
      key: const ValueKey('result_list'),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
      itemCount: _results.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final doc = _results[index];
        return _OrderLookupCard(doc: doc);
      },
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
                  'Hướng dẫn tra cứu đơn',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                const Text('Bạn có thể nhập:', style: TextStyle(fontSize: 13)),
                const SizedBox(height: 4),
                const Text('• Mã đơn CSES-0412-5E09B417',
                    style: TextStyle(fontSize: 13)),
                const Text('• Email khách hàng',
                    style: TextStyle(fontSize: 13)),
                const Text('• Số điện thoại người nhận',
                    style: TextStyle(fontSize: 13)),
                const Text('• Tên người nhận',
                    style: TextStyle(fontSize: 13)),
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
/// 🧾 Card hiển thị 1 đơn trong kết quả tra cứu
/// ============================================================================

class _OrderLookupCard extends StatelessWidget {
  final QueryDocumentSnapshot<Map<String, dynamic>> doc;

  const _OrderLookupCard({required this.doc});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final data = doc.data();
    final orderId = doc.id;
    final total = _toDouble(data['total']);
    final status = (data['status'] ?? 'pending').toString();
    final createdAt = data['createdAt'];
    final createdText = _fmtTimeAny(createdAt);

    // shippingAddress có thể là Map hoặc String
    final rawShipping = data['shippingAddress'];
    Map<String, dynamic> shipping = {};
    if (rawShipping is Map) {
      shipping = Map<String, dynamic>.from(rawShipping);
    }

    final name =
    (shipping['name'] ?? data['toName'] ?? '').toString().trim();
    final phone =
    (shipping['phone'] ?? data['toPhone'] ?? '').toString().trim();

    final orderCode = (data['orderCode'] ?? '').toString().trim();
    final displayCode = orderCode.isNotEmpty
        ? orderCode
        : 'CSES-${orderId.substring(0, 4)}-${orderId.substring(orderId.length - 6)}';

    final statusColor = _statusColor(status);

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF101010) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: cs.outlineVariant.withOpacity(0.4)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.35 : 0.06),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: InkWell(
          onTap: () {
            Navigator.pushNamed(
              context,
              AppRoutes.adminOrderDetail,
              arguments: {
                'orderId': orderId,
                'customerId': data['customerId'],
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
                        'Đơn $displayCode',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: cs.onSurface,
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
                            AppRoutes.adminOrderDetail,
                            arguments: {
                              'orderId': orderId,
                              'customerId': data['customerId'],
                            },
                          );
                        },
                        icon: const Icon(
                          CupertinoIcons.doc_text_search,
                          size: 16,
                          color: _kBlue,
                        ),
                        label: const Text(
                          'Bấm để xem chi tiết đơn',
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
      return const Color(0xFF34C759); // xanh Apple
    case 'cancelled':
      return const Color(0xFFFF3B30); // đỏ Apple
    case 'pending':
    case 'processing':
      return const Color(0xFFFF9500); // cam
    case 'shipping':
      return const Color(0xFF007AFF); // xanh dương
    default:
      return Colors.grey;
  }
}
