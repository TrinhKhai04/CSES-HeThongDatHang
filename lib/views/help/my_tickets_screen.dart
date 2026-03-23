import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../controllers/auth_controller.dart';
import '../../routes/app_routes.dart'; // 👈 thêm import

class MyTicketsScreen extends StatelessWidget {
  const MyTicketsScreen({super.key});

  // Stream KHÔNG orderBy -> KHÔNG cần composite index
  Stream<QuerySnapshot<Map<String, dynamic>>> _stream(String uid) {
    return FirebaseFirestore.instance
        .collection('support_tickets')
        .where('userId', isEqualTo: uid)
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    final uid = context.read<AuthController>().user?.uid ?? '';
    return Scaffold(
      appBar: AppBar(title: const Text('Yêu cầu của tôi')),
      body: uid.isEmpty
          ? const Center(child: Text('Bạn chưa đăng nhập.'))
          : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _stream(uid),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snap.hasError) {
            return _ErrorBox(message: snap.error.toString());
          }

          // Lấy & sắp xếp local: ưu tiên updatedAt (nếu có) rồi đến createdAt
          final docs = [...(snap.data?.docs ?? [])];
          DateTime _dt(Map<String, dynamic> d) {
            final up = d['updatedAt'] as Timestamp?;
            final cr = d['createdAt'] as Timestamp?;
            return (up ?? cr)?.toDate() ??
                DateTime.fromMillisecondsSinceEpoch(0);
          }

          docs.sort((a, b) => _dt(b.data()).compareTo(_dt(a.data())));

          if (docs.isEmpty) {
            return const Center(child: Text('Bạn chưa có yêu cầu nào.'));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (_, i) {
              final data = docs[i].data();
              final ts = (data['createdAt'] as Timestamp?);
              final created = ts != null
                  ? DateFormat('dd/MM/yyyy HH:mm').format(ts.toDate())
                  : '';
              final status = (data['status'] ?? 'open') as String;

              return Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                  title: Text(
                    (data['subject'] ?? 'Yêu cầu hỗ trợ') as String,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if ((data['category'] ?? '').toString().isNotEmpty)
                        Text('Danh mục: ${data['category']}'),
                      if ((data['orderId'] ?? '').toString().isNotEmpty)
                        Text('Mã đơn: ${data['orderId']}'),
                      if (created.isNotEmpty) Text('Tạo lúc: $created'),
                    ],
                  ),
                  trailing: _StatusChip(status: status),
                  onTap: () {
                    Navigator.pushNamed(
                      context,
                      AppRoutes.userTicketDetail, // 👈 mở màn chat user
                      arguments: {'ticketId': docs[i].id},
                    );
                  },
                ),
              );
            },
          );
        },
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
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child:
      Text(label, style: TextStyle(color: fg, fontWeight: FontWeight.w700)),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  final String message;
  const _ErrorBox({required this.message});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: cs.error),
          color: cs.errorContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(Icons.error_outline, color: cs.onErrorContainer),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Không thể tải dữ liệu:\n$message',
                style: TextStyle(color: cs.onErrorContainer),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
