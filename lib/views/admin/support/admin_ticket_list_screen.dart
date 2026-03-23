import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../routes/app_routes.dart';

class AdminTicketListScreen extends StatefulWidget {
  const AdminTicketListScreen({super.key});

  @override
  State<AdminTicketListScreen> createState() => _AdminTicketListScreenState();
}

class _AdminTicketListScreenState extends State<AdminTicketListScreen> {
  final _searchCtl = TextEditingController();
  String _query = '';
  String _status = 'Tất cả';

  static const _statuses = ['Tất cả', 'open', 'in_progress', 'resolved', 'closed'];

  @override
  void initState() {
    super.initState();
    _searchCtl.addListener(() => setState(() => _query = _searchCtl.text.trim()));
  }

  @override
  void dispose() {
    _searchCtl.dispose();
    super.dispose();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _stream() {
    // Để tránh index phức tạp, chỉ orderBy theo createdAt (single-field index mặc định đã có)
    return FirebaseFirestore.instance
        .collection('support_tickets')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Hỗ trợ – Tất cả yêu cầu'),
        actions: [
          IconButton(
            tooltip: 'Tra cứu đơn hàng',
            icon: const Icon(Icons.receipt_long_rounded),
            onPressed: () {
              Navigator.pushNamed(context, AppRoutes.adminOrderLookup);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: TextField(
              controller: _searchCtl,
              decoration: const InputDecoration(
                hintText: 'Tìm theo tiêu đề, email, mã đơn...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
            ),
          ),
          // chips lọc trạng thái (lọc client – không cần index)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
            child: Row(
              children: _statuses.map((s) {
                final sel = _status == s;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(
                      s == 'open'
                          ? 'Mới tạo'
                          : s == 'in_progress'
                          ? 'Đang xử lý'
                          : s == 'resolved'
                          ? 'Đã giải quyết'
                          : s == 'closed'
                          ? 'Đã đóng'
                          : 'Tất cả',
                    ),
                    selected: sel,
                    onSelected: (_) => setState(() => _status = s),
                    selectedColor: cs.primaryContainer,
                    labelStyle: TextStyle(
                      color: sel ? cs.onPrimaryContainer : cs.onSurface,
                      fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                    ),
                    shape: const StadiumBorder(),
                  ),
                );
              }).toList(),
            ),
          ),
          const Divider(height: 1),

          // ==== LIST VÉ HỖ TRỢ ====
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _stream(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return Center(child: Text('Lỗi tải: ${snap.error}'));
                }

                var docs = snap.data?.docs ?? [];

                // Lọc client theo trạng thái + tìm kiếm
                if (_status != 'Tất cả') {
                  docs = docs.where((e) => (e['status'] ?? '') == _status).toList();
                }
                if (_query.isNotEmpty) {
                  final q = _query.toLowerCase();
                  docs = docs.where((e) {
                    final d = e.data();
                    return (d['subject'] ?? '')
                        .toString()
                        .toLowerCase()
                        .contains(q) ||
                        (d['email'] ?? '')
                            .toString()
                            .toLowerCase()
                            .contains(q) ||
                        (d['orderId'] ?? '')
                            .toString()
                            .toLowerCase()
                            .contains(q);
                  }).toList();
                }

                if (docs.isEmpty) {
                  return const Center(child: Text('Không có yêu cầu phù hợp.'));
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (_, i) {
                    final doc = docs[i];
                    final d = doc.data();
                    final ts = d['createdAt'] as Timestamp?;
                    final created = ts != null
                        ? DateFormat('dd/MM/yyyy HH:mm').format(ts.toDate())
                        : '';
                    final st = (d['status'] ?? 'open') as String;

                    return InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => Navigator.pushNamed(
                        context,
                        AppRoutes.adminTicketDetail,
                        arguments: {'ticketId': doc.id},
                      ),
                      child: Ink(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: cs.outlineVariant),
                          color: cs.surface,
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: cs.primaryContainer,
                              foregroundColor: cs.onPrimaryContainer,
                              child:
                              const Icon(Icons.confirmation_num_outlined),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    (d['subject'] ?? 'Yêu cầu hỗ trợ') as String,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Từ: ${(d['name'] ?? '')} • ${(d['email'] ?? '')}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: cs.onSurfaceVariant,
                                    ),
                                  ),
                                  if ((d['orderId'] ?? '')
                                      .toString()
                                      .isNotEmpty)
                                    Text(
                                      'Mã đơn: ${d['orderId']}',
                                      style: TextStyle(
                                        color: cs.onSurfaceVariant,
                                      ),
                                    ),
                                  if (created.isNotEmpty)
                                    Text(
                                      'Tạo lúc: $created',
                                      style: TextStyle(
                                        color: cs.onSurfaceVariant,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            _StatusChip(status: st),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),

          // ==== GỢI Ý TRA CỨU ĐƠN HÀNG ====
          SafeArea(
            top: false,
            child: Padding(
              padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Muốn xem chi tiết đơn hàng liên quan?',
                      style: TextStyle(
                        fontSize: 12,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.pushNamed(context, AppRoutes.adminOrderLookup);
                    },
                    child: const Text(
                      'Tra cứu đơn hàng',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    late Color bg, fg;
    late String label;
    switch (status) {
      case 'in_progress':
        bg = cs.tertiaryContainer;
        fg = cs.onTertiaryContainer;
        label = 'Đang xử lý';
        break;
      case 'resolved':
        bg = cs.secondaryContainer;
        fg = cs.onSecondaryContainer;
        label = 'Đã giải quyết';
        break;
      case 'closed':
        bg = cs.surfaceVariant;
        fg = cs.onSurfaceVariant;
        label = 'Đã đóng';
        break;
      default:
        bg = cs.primaryContainer;
        fg = cs.onPrimaryContainer;
        label = 'Mới tạo';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: fg,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
