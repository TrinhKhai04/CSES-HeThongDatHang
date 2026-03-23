import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'admin_upload_video_screen.dart';

class AdminVideoManagerScreen extends StatefulWidget {
  const AdminVideoManagerScreen({super.key});

  @override
  State<AdminVideoManagerScreen> createState() => _AdminVideoManagerScreenState();
}

class _AdminVideoManagerScreenState extends State<AdminVideoManagerScreen> {
  final _searchCtl = TextEditingController();

  String _keyword = '';
  bool _activeOnly = false;

  @override
  void dispose() {
    _searchCtl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final w = MediaQuery.sizeOf(context).width;

    // Breakpoints đơn giản (bạn có thể chỉnh theo ý)
    final isWide = w >= 720; // tablet/web
    final maxWidth = isWide ? 860.0 : double.infinity;
    final padX = isWide ? 20.0 : 12.0;
    final padTop = isWide ? 16.0 : 12.0;

    final q = FirebaseFirestore.instance
        .collection('videos')
        .orderBy('createdAt', descending: true);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Video sản phẩm'),
        actions: [
          IconButton(
            tooltip: 'Làm mới',
            icon: const Icon(Icons.refresh),
            onPressed: () => setState(() {}),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const AdminUploadVideoScreen()),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('Thêm video'),
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Column(
              children: [
                // ====== Search + Filter ======
                Padding(
                  padding: EdgeInsets.fromLTRB(padX, padTop, padX, 8),
                  child: _Toolbar(
                    searchCtl: _searchCtl,
                    keyword: _keyword,
                    activeOnly: _activeOnly,
                    onKeywordChanged: (v) => setState(() => _keyword = v.trim().toLowerCase()),
                    onToggleActive: (v) => setState(() => _activeOnly = v),
                  ),
                ),

                // ====== List ======
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: q.snapshots(),
                    builder: (context, snap) {
                      if (snap.hasError) {
                        return Center(
                          child: Padding(
                            padding: EdgeInsets.all(padX),
                            child: Text(
                              'Lỗi: ${snap.error}',
                              style: TextStyle(color: cs.error),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        );
                      }
                      if (!snap.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final docs = snap.data!.docs;

                      final filtered = docs.where((doc) {
                        final d = doc.data() as Map<String, dynamic>;
                        final title = (d['title'] ?? '').toString().toLowerCase();
                        final productId = (d['productId'] ?? '').toString().toLowerCase();
                        final active = (d['active'] ?? true) as bool;

                        if (_activeOnly && !active) return false;
                        if (_keyword.isEmpty) return true;
                        return title.contains(_keyword) || productId.contains(_keyword);
                      }).toList();

                      if (filtered.isEmpty) {
                        return Center(
                          child: Text(
                            'Chưa có video phù hợp',
                            style: TextStyle(color: cs.onSurfaceVariant),
                          ),
                        );
                      }

                      return Scrollbar(
                        child: ListView.separated(
                          padding: EdgeInsets.fromLTRB(padX, 8, padX, 96),
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (context, i) {
                            final doc = filtered[i];
                            final d = doc.data() as Map<String, dynamic>;

                            final title = (d['title'] ?? '') as String;
                            final productId = (d['productId'] ?? '') as String;
                            final videoUrl = (d['videoUrl'] ?? '') as String;

                            final active = (d['active'] ?? true) as bool;
                            final order = (d['order'] ?? 0) as int;
                            final views = (d['views'] ?? 0) as int;

                            return _VideoCard(
                              title: title.isEmpty ? '(Không có tiêu đề)' : title,
                              productId: productId,
                              videoUrl: videoUrl,
                              active: active,
                              order: order,
                              views: views,
                              onEdit: () => _openEditAdaptive(context, doc.id, d),
                              onDelete: () => _confirmDelete(context, doc.id),
                              // (optional) onTapPreview: () {}
                            );
                          },
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, String videoId) async {
    final cs = Theme.of(context).colorScheme;

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Xóa video?'),
        content: const Text('Video sẽ bị xóa khỏi Firestore (app user sẽ không thấy).'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Hủy')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Xóa')),
        ],
      ),
    );

    if (ok != true) return;

    try {
      await FirebaseFirestore.instance.collection('videos').doc(videoId).delete();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã xóa video')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi xóa: $e'), backgroundColor: cs.error),
      );
    }
  }

  Future<void> _openEditAdaptive(
      BuildContext context,
      String videoId,
      Map<String, dynamic> data,
      ) async {
    final w = MediaQuery.sizeOf(context).width;
    final isWide = w >= 720;

    // Controllers
    final titleCtl = TextEditingController(text: (data['title'] ?? '').toString());
    final orderCtl = TextEditingController(text: '${data['order'] ?? 0}');
    final voucherTextCtl = TextEditingController(text: (data['voucherText'] ?? '').toString());
    final voucherCodeCtl = TextEditingController(text: (data['voucherCode'] ?? '').toString());
    bool active = (data['active'] ?? true) as bool;

    Future<bool?> showEditor() {
      final content = StatefulBuilder(
        builder: (context, setLocal) => _EditVideoForm(
          titleCtl: titleCtl,
          orderCtl: orderCtl,
          voucherTextCtl: voucherTextCtl,
          voucherCodeCtl: voucherCodeCtl,
          active: active,
          onActiveChanged: (v) => setLocal(() => active = v),
          onCancel: () => Navigator.pop(context, false),
          onSave: () => Navigator.pop(context, true),
        ),
      );

      // Wide: dialog gọn, đẹp
      if (isWide) {
        return showDialog<bool>(
          context: context,
          builder: (_) => Dialog(
            insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: content,
            ),
          ),
        );
      }

      // Mobile: bottom sheet tránh keyboard, kéo lên được
      return showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        ),
        builder: (ctx) {
          final bottomInset = MediaQuery.viewInsetsOf(ctx).bottom;
          return Padding(
            padding: EdgeInsets.only(bottom: bottomInset),
            child: content,
          );
        },
      );
    }

    final saved = await showEditor();

    // Dispose controllers
    titleCtl.dispose();
    orderCtl.dispose();
    voucherTextCtl.dispose();
    voucherCodeCtl.dispose();

    if (saved != true) return;

    final order = int.tryParse(orderCtl.text.trim()) ?? 0;

    await FirebaseFirestore.instance.collection('videos').doc(videoId).update({
      'active': active,
      'title': titleCtl.text.trim(),
      'order': order,
      'voucherText': voucherTextCtl.text.trim(),
      'voucherCode': voucherCodeCtl.text.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Đã lưu')),
    );
  }
}

// ===================== UI WIDGETS =====================

class _Toolbar extends StatelessWidget {
  const _Toolbar({
    required this.searchCtl,
    required this.keyword,
    required this.activeOnly,
    required this.onKeywordChanged,
    required this.onToggleActive,
  });

  final TextEditingController searchCtl;
  final String keyword;
  final bool activeOnly;
  final ValueChanged<String> onKeywordChanged;
  final ValueChanged<bool> onToggleActive;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final w = MediaQuery.sizeOf(context).width;
    final isWide = w >= 720;

    return Column(
      children: [
        TextField(
          controller: searchCtl,
          onChanged: onKeywordChanged,
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.search),
            hintText: 'Tìm theo tiêu đề hoặc productId...',
            filled: true,
            fillColor: cs.surface,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: cs.outlineVariant),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: cs.primary, width: 1.2),
            ),
          ),
        ),
        const SizedBox(height: 10),

        // Mobile: 1 hàng; Wide: chia bố cục thoáng hơn
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: cs.outlineVariant),
          ),
          child: Row(
            children: [
              Icon(Icons.filter_alt_outlined, color: cs.onSurfaceVariant),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  activeOnly ? 'Chỉ Active' : 'Tất cả trạng thái',
                  style: TextStyle(
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (isWide) const SizedBox(width: 8),
              Switch(
                value: activeOnly,
                onChanged: onToggleActive,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _VideoCard extends StatelessWidget {
  const _VideoCard({
    required this.title,
    required this.productId,
    required this.videoUrl,
    required this.active,
    required this.order,
    required this.views,
    required this.onEdit,
    required this.onDelete,
  });

  final String title;
  final String productId;
  final String videoUrl;
  final bool active;
  final int order;
  final int views;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Material(
      color: cs.surface,
      elevation: 0,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onEdit, // nhấn card => mở sửa (nhanh)
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: cs.outlineVariant),
            boxShadow: [
              BoxShadow(
                color: cs.shadow.withOpacity(0.05),
                blurRadius: 14,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Thumbnail placeholder
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.play_circle_outline,
                  color: cs.primary,
                  size: 32,
                ),
              ),
              const SizedBox(width: 12),

              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title + status chip
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _StatusChip(active: active),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'productId: $productId',
                      style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'order: $order • views: $views',
                      style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
                    ),
                    if (videoUrl.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        videoUrl,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: cs.onSurfaceVariant, fontSize: 11),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(width: 8),

              // Actions
              Column(
                children: [
                  IconButton(
                    tooltip: 'Sửa',
                    icon: const Icon(Icons.edit_outlined),
                    color: cs.primary,
                    onPressed: onEdit,
                  ),
                  IconButton(
                    tooltip: 'Xóa',
                    icon: const Icon(Icons.delete_outline),
                    color: cs.error,
                    onPressed: onDelete,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.active});
  final bool active;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final bg = active ? Colors.green.withOpacity(0.14) : cs.error.withOpacity(0.12);
    final fg = active ? Colors.green : cs.error;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: fg.withOpacity(0.25)),
      ),
      child: Text(
        active ? 'Đang bật' : 'Đã tắt',
        style: TextStyle(color: fg, fontWeight: FontWeight.w800, fontSize: 12),
      ),
    );
  }
}

class _EditVideoForm extends StatelessWidget {
  const _EditVideoForm({
    required this.titleCtl,
    required this.orderCtl,
    required this.voucherTextCtl,
    required this.voucherCodeCtl,
    required this.active,
    required this.onActiveChanged,
    required this.onCancel,
    required this.onSave,
  });

  final TextEditingController titleCtl;
  final TextEditingController orderCtl;
  final TextEditingController voucherTextCtl;
  final TextEditingController voucherCodeCtl;
  final bool active;
  final ValueChanged<bool> onActiveChanged;
  final VoidCallback onCancel;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final w = MediaQuery.sizeOf(context).width;
    final isWide = w >= 720;

    final pad = isWide ? 18.0 : 16.0;

    return Padding(
      padding: EdgeInsets.fromLTRB(pad, pad, pad, pad),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Sửa video',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                ),
              ),
              IconButton(
                tooltip: 'Đóng',
                onPressed: onCancel,
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Active
          Container(
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: cs.outlineVariant),
            ),
            child: SwitchListTile(
              value: active,
              onChanged: onActiveChanged,
              title: const Text('Active'),
              dense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
            ),
          ),

          const SizedBox(height: 12),

          // Fields
          _Field(
            controller: titleCtl,
            label: 'Title',
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 10),

          _Field(
            controller: orderCtl,
            label: 'Order',
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 10),

          _Field(
            controller: voucherTextCtl,
            label: 'Voucher text',
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 10),

          _Field(
            controller: voucherCodeCtl,
            label: 'Voucher code',
            textInputAction: TextInputAction.done,
          ),

          const SizedBox(height: 16),

          // Actions (tự wrap khi màn nhỏ)
          Wrap(
            spacing: 10,
            runSpacing: 10,
            alignment: WrapAlignment.end,
            children: [
              TextButton(onPressed: onCancel, child: const Text('Hủy')),
              FilledButton.icon(
                onPressed: onSave,
                icon: const Icon(Icons.save_outlined),
                label: const Text('Lưu'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.label,
    this.keyboardType,
    this.inputFormatters,
    this.textInputAction,
  });

  final TextEditingController controller;
  final String label;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final TextInputAction? textInputAction;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      textInputAction: textInputAction,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: cs.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: cs.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: cs.primary, width: 1.2),
        ),
      ),
    );
  }
}
