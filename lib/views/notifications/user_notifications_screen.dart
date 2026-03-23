import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../controllers/notification_controller.dart';
import '../../routes/app_routes.dart';

class UserNotificationsScreen extends StatefulWidget {
  const UserNotificationsScreen({super.key});

  @override
  State<UserNotificationsScreen> createState() =>
      _UserNotificationsScreenState();
}

class _UserNotificationsScreenState extends State<UserNotificationsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<NotificationController>().listenToUserNotifications();
    });
  }

  String _formatTime(dynamic ts) {
    if (ts == null) return '';
    DateTime? dt;
    if (ts is Timestamp) {
      dt = ts.toDate();
    } else if (ts is DateTime) {
      dt = ts;
    } else if (ts is int) {
      dt = DateTime.fromMillisecondsSinceEpoch(ts);
    }
    if (dt == null) return '';

    final now = DateTime.now();
    final isSameDay =
        dt.year == now.year && dt.month == now.month && dt.day == now.day;
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    if (isSameDay) return '$hh:$mm';
    final dd = dt.day.toString().padLeft(2, '0');
    final mo = dt.month.toString().padLeft(2, '0');
    return '$dd/$mo · $hh:$mm';
  }

  Future<void> _onRefresh(NotificationController noti) async {
    await noti.refresh();
  }

  @override
  Widget build(BuildContext context) {
    final noti = context.watch<NotificationController>();
    final list = noti.notifications;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final screenWidth = MediaQuery.of(context).size.width;
    final double maxContentWidth;
    if (screenWidth >= 1000) {
      maxContentWidth = 560;
    } else if (screenWidth >= 600) {
      maxContentWidth = 480;
    } else {
      maxContentWidth = screenWidth; // mobile: full width (vẫn có padding 16)
    }

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        elevation: 0,
        centerTitle: true,
        backgroundColor: Colors.transparent,
        foregroundColor: cs.onSurface,
        title: Text(
          'Thông báo',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          if (list.isNotEmpty)
            IconButton(
              tooltip: 'Đánh dấu tất cả là đã đọc',
              icon: const Icon(Icons.done_all_rounded),
              onPressed: () async {
                await noti.markAllAsRead();
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Đã đánh dấu tất cả là đã đọc'),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
            ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              cs.surface,
              cs.surfaceVariant.withOpacity(0.4),
            ],
          ),
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxContentWidth),
            child: list.isEmpty
                ? const _EmptyState()
                : RefreshIndicator(
              onRefresh: () => _onRefresh(noti),
              child: ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                itemCount: list.length,
                separatorBuilder: (_, __) =>
                const SizedBox(height: 10),
                itemBuilder: (context, i) {
                  final n = list[i] as Map<String, dynamic>;
                  final String id = (n['id'] ?? '').toString();
                  final String title =
                  (n['title'] ?? 'Thông báo').toString();
                  final String msg =
                  (n['message'] ?? '').toString();
                  final dynamic ts = n['createdAt'];
                  final bool isRead = n['isRead'] == true;
                  final String? orderId = n['orderId']?.toString();
                  final time = _formatTime(ts);

                  return Dismissible(
                    key: ValueKey('noti_${id}_$i'),
                    background: _SwipeAction(
                      icon: Icons.mark_email_read_rounded,
                      label: 'Đã đọc',
                      color: cs.primaryContainer,
                      foreground: cs.onPrimaryContainer,
                      alignLeft: true,
                    ),
                    secondaryBackground: _SwipeAction(
                      icon: Icons.delete_outline_rounded,
                      label: 'Xoá',
                      color: cs.errorContainer,
                      foreground: cs.onErrorContainer,
                      alignLeft: false,
                    ),
                    confirmDismiss: (direction) async {
                      if (direction ==
                          DismissDirection.startToEnd) {
                        if (!isRead && id.isNotEmpty) {
                          await noti.markAsRead(id);
                        }
                        return false; // chỉ đánh dấu, không xoá
                      } else {
                        final ok = await showDialog<bool>(
                          context: context,
                          builder: (_) => AlertDialog(
                            title: const Text('Xoá thông báo?'),
                            content: const Text(
                                'Thao tác này không thể hoàn tác.'),
                            actions: [
                              TextButton(
                                onPressed: () =>
                                    Navigator.pop(context, false),
                                child: const Text('Huỷ'),
                              ),
                              FilledButton(
                                onPressed: () =>
                                    Navigator.pop(context, true),
                                child: const Text('Xoá'),
                              ),
                            ],
                          ),
                        );
                        if (ok == true) {
                          if (id.isNotEmpty) {
                            await noti.delete(id);
                          }
                          return true;
                        }
                        return false;
                      }
                    },
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: InkWell(
                        onTap: () async {
                          if (!isRead && id.isNotEmpty) {
                            await noti.markAsRead(id);
                          }
                          if (orderId != null &&
                              orderId.isNotEmpty) {
                            if (!mounted) return;
                            Navigator.pushNamed(
                              context,
                              AppRoutes.orderDetail,
                              arguments: {
                                'orderId': orderId,
                                'source': 'notification',
                              },
                            );
                          }
                        },
                        onLongPress: () async {
                          final action =
                          await showModalBottomSheet<String>(
                            context: context,
                            showDragHandle: true,
                            builder: (_) => SafeArea(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  ListTile(
                                    leading: const Icon(
                                      Icons
                                          .mark_email_read_rounded,
                                    ),
                                    title: const Text(
                                        'Đánh dấu đã đọc'),
                                    onTap: () => Navigator.pop(
                                        context, 'read'),
                                  ),
                                  ListTile(
                                    leading: const Icon(
                                      Icons
                                          .delete_outline_rounded,
                                    ),
                                    title: const Text('Xoá'),
                                    onTap: () => Navigator.pop(
                                        context, 'delete'),
                                  ),
                                ],
                              ),
                            ),
                          );
                          if (action == 'read' &&
                              !isRead &&
                              id.isNotEmpty) {
                            await noti.markAsRead(id);
                          } else if (action == 'delete' &&
                              id.isNotEmpty) {
                            await noti.delete(id);
                          }
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: cs.surface,
                            borderRadius:
                            BorderRadius.circular(20),
                            border: Border.all(
                              color: cs.outlineVariant
                                  .withOpacity(0.5),
                              width: 0.6,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black
                                    .withOpacity(0.04),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                          child: Row(
                            crossAxisAlignment:
                            CrossAxisAlignment.start,
                            children: [
                              // icon + nền tròn
                              Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: isRead
                                      ? cs.surfaceVariant
                                      .withOpacity(0.4)
                                      : cs.primary
                                      .withOpacity(0.12),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  isRead
                                      ? Icons
                                      .notifications_none_outlined
                                      : Icons
                                      .notifications_active_rounded,
                                  size: 18,
                                  color: isRead
                                      ? cs.outline
                                      : cs.primary,
                                ),
                              ),
                              const SizedBox(width: 12),
                              // nội dung
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                  CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            title,
                                            maxLines: 2,
                                            overflow: TextOverflow
                                                .ellipsis,
                                            style: theme.textTheme
                                                .titleMedium
                                                ?.copyWith(
                                              fontWeight: isRead
                                                  ? FontWeight
                                                  .w600
                                                  : FontWeight
                                                  .w700,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          time,
                                          textAlign:
                                          TextAlign.right,
                                          style: theme.textTheme
                                              .bodySmall
                                              ?.copyWith(
                                            color: cs
                                                .onSurfaceVariant,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      msg,
                                      maxLines: 2,
                                      overflow: TextOverflow
                                          .ellipsis,
                                      style: theme.textTheme
                                          .bodyMedium
                                          ?.copyWith(
                                        color:
                                        cs.onSurfaceVariant,
                                      ),
                                    ),
                                    if (!isRead) ...[
                                      const SizedBox(height: 6),
                                      Row(
                                        children: [
                                          Container(
                                            width: 6,
                                            height: 6,
                                            decoration:
                                            BoxDecoration(
                                              color: cs.primary,
                                              shape:
                                              BoxShape.circle,
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            'Mới',
                                            style: theme.textTheme
                                                .labelSmall
                                                ?.copyWith(
                                              color: cs.primary,
                                              fontWeight:
                                              FontWeight
                                                  .w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.notifications_none_rounded,
              size: 64,
              color: cs.outline,
            ),
            const SizedBox(height: 12),
            Text(
              'Chưa có thông báo',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Khi có cập nhật đơn hàng, khuyến mãi\nhoặc tin quan trọng, chúng tôi sẽ báo bạn ngay.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SwipeAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Color foreground;
  final bool alignLeft;

  const _SwipeAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.foreground,
    required this.alignLeft,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: color,
      alignment: alignLeft ? Alignment.centerLeft : Alignment.centerRight,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment:
        alignLeft ? MainAxisAlignment.start : MainAxisAlignment.end,
        children: alignLeft
            ? [
          Icon(icon, color: foreground),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: foreground,
              fontWeight: FontWeight.w700,
            ),
          ),
        ]
            : [
          Text(
            label,
            style: TextStyle(
              color: foreground,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 8),
          Icon(icon, color: foreground),
        ],
      ),
    );
  }
}
