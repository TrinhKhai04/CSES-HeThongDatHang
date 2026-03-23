import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AdminTicketDetailScreen extends StatefulWidget {
  const AdminTicketDetailScreen({super.key});

  @override
  State<AdminTicketDetailScreen> createState() => _AdminTicketDetailScreenState();
}

class _AdminTicketDetailScreenState extends State<AdminTicketDetailScreen> {
  late final String ticketId;
  final _replyCtl = TextEditingController();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)!.settings.arguments as Map?;
    ticketId = (args?['ticketId'] ?? '') as String;
  }

  @override
  void dispose() {
    _replyCtl.dispose();
    super.dispose();
  }

  Future<void> _updateStatus(String newStatus) async {
    await FirebaseFirestore.instance.collection('support_tickets').doc(ticketId).update({
      'status': newStatus,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Đã cập nhật trạng thái: $newStatus')),
      );
    }
  }

  Future<void> _sendReply(String text) async {
    final col = FirebaseFirestore.instance
        .collection('support_tickets')
        .doc(ticketId)
        .collection('messages');
    await col.add({
      'sender': 'admin',         // hoặc lưu uid admin
      'text': text.trim(),
      'createdAt': FieldValue.serverTimestamp(),
    });
    _replyCtl.clear();
  }

  @override
  Widget build(BuildContext context) {
    if (ticketId.isEmpty) {
      return const Scaffold(body: Center(child: Text('Thiếu ticketId')));
    }

    final docRef = FirebaseFirestore.instance.collection('support_tickets').doc(ticketId);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chi tiết yêu cầu'),
        actions: [
          PopupMenuButton<String>(
            onSelected: _updateStatus,
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'open', child: Text('Mới tạo')),
              PopupMenuItem(value: 'in_progress', child: Text('Đang xử lý')),
              PopupMenuItem(value: 'resolved', child: Text('Đã giải quyết')),
              PopupMenuItem(value: 'closed', child: Text('Đã đóng')),
            ],
            icon: const Icon(Icons.sync),
            tooltip: 'Đổi trạng thái',
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: docRef.snapshots(),
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          if (!snap.data!.exists) return const Center(child: Text('Không tìm thấy ticket.'));

          final d = snap.data!.data()!;
          final ts = d['createdAt'] as Timestamp?;
          final created = ts != null ? DateFormat('dd/MM/yyyy HH:mm').format(ts.toDate()) : '';

          return Column(
            children: [
              // Header info
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: _InfoCard(
                  subject: d['subject'] ?? 'Yêu cầu hỗ trợ',
                  name: d['name'] ?? '',
                  email: d['email'] ?? '',
                  category: d['category'] ?? '',
                  orderId: d['orderId'] ?? '',
                  created: created,
                  status: d['status'] ?? 'open',
                ),
              ),
              const Divider(height: 1),

              // Messages thread
              Expanded(
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: docRef.collection('messages').orderBy('createdAt').snapshots(),
                  builder: (context, msnap) {
                    if (!msnap.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final msgs = msnap.data!.docs;
                    if (msgs.isEmpty) {
                      return const Center(child: Text('Chưa có trao đổi.'));
                    }
                    return ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: msgs.length,
                      itemBuilder: (_, i) {
                        final m = msgs[i].data();
                        final isAdmin = (m['sender'] ?? '') == 'admin';
                        final mts = m['createdAt'] as Timestamp?;
                        final t = mts != null
                            ? DateFormat('dd/MM HH:mm').format(mts.toDate())
                            : '';
                        return Align(
                          alignment: isAdmin ? Alignment.centerRight : Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: isAdmin
                                  ? Theme.of(context).colorScheme.primaryContainer
                                  : Theme.of(context).colorScheme.surfaceVariant,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Column(
                              crossAxisAlignment:
                              isAdmin ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                              children: [
                                Text((m['text'] ?? '').toString()),
                                if (t.isNotEmpty)
                                  Text(t,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                                      )),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),

              // Composer
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _replyCtl,
                          minLines: 1,
                          maxLines: 5,
                          decoration: const InputDecoration(
                            hintText: 'Nhập phản hồi...',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.icon(
                        onPressed: () {
                          final text = _replyCtl.text.trim();
                          if (text.isNotEmpty) _sendReply(text);
                        },
                        icon: const Icon(Icons.send_rounded),
                        label: const Text('Gửi'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String subject, name, email, category, orderId, created, status;
  const _InfoCard({
    required this.subject,
    required this.name,
    required this.email,
    required this.category,
    required this.orderId,
    required this.created,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    String label;
    Color bg, fg;
    switch (status) {
      case 'in_progress': label = 'Đang xử lý'; bg = cs.tertiaryContainer; fg = cs.onTertiaryContainer; break;
      case 'resolved':    label = 'Đã giải quyết'; bg = cs.secondaryContainer; fg = cs.onSecondaryContainer; break;
      case 'closed':      label = 'Đã đóng'; bg = cs.surfaceVariant; fg = cs.onSurfaceVariant; break;
      default:            label = 'Mới tạo'; bg = cs.primaryContainer; fg = cs.onPrimaryContainer;
    }
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(subject, style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _KV('Khách', '$name · $email'),
              if (category.isNotEmpty) _KV('Danh mục', category),
              if (orderId.isNotEmpty) _KV('Mã đơn', orderId),
              if (created.isNotEmpty) _KV('Tạo lúc', created),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
                child: Text(label, style: TextStyle(color: fg, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _KV extends StatelessWidget {
  final String k, v;
  const _KV(this.k, this.v);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: cs.surfaceVariant,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text('$k: $v', style: TextStyle(color: cs.onSurface)),
    );
  }
}
