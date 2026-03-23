import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../controllers/auth_controller.dart';

class UserTicketDetailScreen extends StatefulWidget {
  const UserTicketDetailScreen({super.key});

  @override
  State<UserTicketDetailScreen> createState() => _UserTicketDetailScreenState();
}

class _UserTicketDetailScreenState extends State<UserTicketDetailScreen> {
  late final String ticketId;
  final _replyCtl = TextEditingController();
  final _scroll = ScrollController();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)!.settings.arguments as Map?;
    ticketId = (args?['ticketId'] ?? '') as String;
  }

  @override
  void dispose() {
    _replyCtl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _sendReply() async {
    final text = _replyCtl.text.trim();
    if (text.isEmpty) return;

    final auth = context.read<AuthController>();
    final uid = auth.user?.uid ?? '';

    // Lấy tên hiển thị của user để lưu vào message
    final senderName = (auth.profile?['name'] ??
        auth.user?.displayName ??
        auth.user?.email?.split('@').first ??
        'Bạn')
        .toString();

    final doc =
    FirebaseFirestore.instance.collection('support_tickets').doc(ticketId);

    await doc.collection('messages').add({
      'sender': 'user',
      'senderId': uid, // 👈 mới
      'senderName': senderName, // 👈 mới
      'userId': uid, // giữ để tương thích code cũ
      'text': text,
      'createdAt': FieldValue.serverTimestamp(),
    });

    await doc.update({'updatedAt': FieldValue.serverTimestamp()});

    _replyCtl.clear();

    await Future.delayed(const Duration(milliseconds: 150));
    if (_scroll.hasClients) {
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (ticketId.isEmpty) {
      return const Scaffold(body: Center(child: Text('Thiếu ticketId')));
    }

    final cs = Theme.of(context).colorScheme;
    final docRef =
    FirebaseFirestore.instance.collection('support_tickets').doc(ticketId);

    return Scaffold(
      appBar: AppBar(title: const Text('Chi tiết yêu cầu')),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: docRef.snapshots(),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snap.data!.exists) {
            return const Center(child: Text('Không tìm thấy yêu cầu.'));
          }

          final d = snap.data!.data()!;
          final subject = (d['subject'] ?? 'Yêu cầu hỗ trợ') as String;
          final category = (d['category'] ?? '') as String;
          final orderId = (d['orderId'] ?? '') as String;
          final status = (d['status'] ?? 'open') as String;
          final ts = d['createdAt'] as Timestamp?;
          final created =
          ts != null ? DateFormat('dd/MM/yyyy HH:mm').format(ts.toDate()) : '';

          // fallback tên khách nếu message chưa có senderName
          final ticketUserName = (d['userName'] ?? '') as String? ?? '';
          final ticketUserEmail = (d['userEmail'] ?? '') as String? ?? '';

          final canReply = status != 'closed';

          return Column(
            children: [
              // ------- info -------
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Container(
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
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          if (category.isNotEmpty) _kv('Danh mục', category),
                          if (orderId.isNotEmpty) _kv('Mã đơn', orderId),
                          if (created.isNotEmpty) _kv('Tạo lúc', created),
                          _StatusChip(status: status),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const Divider(height: 1),

              // ------- messages thread -------
              Expanded(
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: docRef
                      .collection('messages')
                      .orderBy('createdAt') // single-field index đủ dùng
                      .snapshots(),
                  builder: (context, msnap) {
                    if (!msnap.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    // Auto-scroll xuống cuối khi có tin mới
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (_scroll.hasClients) {
                        _scroll.jumpTo(_scroll.position.maxScrollExtent);
                      }
                    });

                    final msgs = msnap.data!.docs;
                    return ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.all(16),
                      itemCount: msgs.length,
                      itemBuilder: (_, i) {
                        final m = msgs[i].data();
                        final isUser = (m['sender'] ?? '') == 'user';
                        final mts = m['createdAt'] as Timestamp?;
                        final t = mts != null
                            ? DateFormat('dd/MM HH:mm').format(mts.toDate())
                            : '';

                        // === Tính tên người gửi ===
                        String nameFromTicket() {
                          if (isUser) {
                            if (ticketUserName.trim().isNotEmpty) return ticketUserName;
                            if (ticketUserEmail.trim().isNotEmpty) {
                              return ticketUserEmail.split('@').first;
                            }
                            return 'Khách';
                          } else {
                            return 'Admin';
                          }
                        }

                        final senderName =
                        ((m['senderName'] ?? '') as String).trim().isNotEmpty
                            ? (m['senderName'] as String)
                            : nameFromTicket();

                        // Gom nhóm: chỉ hiện tên khi đổi người gửi
                        final prev = i > 0 ? msgs[i - 1].data() : null;
                        final currId =
                        (m['senderId'] ?? m['userId'] ?? '') as String;
                        final prevId =
                        (prev?['senderId'] ?? prev?['userId'] ?? '') as String;
                        final showName = i == 0 || prevId != currId;

                        return Align(
                          alignment:
                          isUser ? Alignment.centerRight : Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: isUser
                                  ? cs.primaryContainer
                                  : cs.surfaceVariant,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Column(
                              crossAxisAlignment: isUser
                                  ? CrossAxisAlignment.end
                                  : CrossAxisAlignment.start,
                              children: [
                                if (showName)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 2),
                                    child: Text(
                                      senderName,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: cs.onSurfaceVariant,
                                      ),
                                    ),
                                  ),
                                Text((m['text'] ?? '').toString()),
                                if (t.isNotEmpty)
                                  Text(
                                    t,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: cs.onSurfaceVariant,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),

              // ------- composer -------
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
                          enabled: canReply,
                          decoration: InputDecoration(
                            hintText:
                            canReply ? 'Nhập phản hồi...' : 'Yêu cầu đã đóng',
                            border: const OutlineInputBorder(),
                          ),
                          onSubmitted: (_) => canReply ? _sendReply() : null,
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.icon(
                        onPressed: canReply ? _sendReply : null,
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

  Widget _kv(String k, String v) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: cs.surfaceVariant,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text('$k: $v'),
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
      decoration:
      BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Text(label,
          style: TextStyle(color: fg, fontWeight: FontWeight.w700)),
    );
  }
}
