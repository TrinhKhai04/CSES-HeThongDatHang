import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// ============================================================================
/// 🧭 AdminPolicyScreen — Chính sách & Điều khoản (Dark/Light aware)
/// ============================================================================
class AdminPolicyScreen extends StatefulWidget {
  const AdminPolicyScreen({super.key});

  @override
  State<AdminPolicyScreen> createState() => _AdminPolicyScreenState();
}

class _AdminPolicyScreenState extends State<AdminPolicyScreen> {
  final _col = FirebaseFirestore.instance.collection('policies');

  // ────────────────────────────────────────────────────────────────────────────
  // FORM: Thêm/Sửa (AlertDialog theo theme)
  // ────────────────────────────────────────────────────────────────────────────
  void _openForm({DocumentSnapshot? doc}) {
    final cs = Theme.of(context).colorScheme;

    final titleCtl = TextEditingController(text: (doc?.data() as Map?)?['title'] ?? '');
    final contentCtl = TextEditingController(text: (doc?.data() as Map?)?['content'] ?? '');
    final isEdit = doc != null;

    InputDecoration _inputDeco(String label) => InputDecoration(
      labelText: label,
      border: _outlined(cs),
      enabledBorder: _outlined(cs, outline: cs.outlineVariant),
      filled: true,
      fillColor: _fieldFill(cs),
      alignLabelWithHint: true,
    );

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: cs.surface,
        surfaceTintColor: cs.surfaceTint,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          isEdit ? 'Chỉnh sửa chính sách' : 'Thêm chính sách mới',
          style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.w700),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleCtl,
                style: TextStyle(color: cs.onSurface),
                decoration: _inputDeco('Tiêu đề'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: contentCtl,
                maxLines: 6,
                style: TextStyle(color: cs.onSurface),
                decoration: _inputDeco('Nội dung'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Hủy', style: TextStyle(color: cs.primary)),
          ),
          FilledButton(
            onPressed: () async {
              final data = {
                'title': titleCtl.text.trim(),
                'content': contentCtl.text.trim(),
                'updatedAt': Timestamp.now(),
                'isActive': true,
              };
              if (isEdit) {
                await _col.doc(doc!.id).update(data);
              } else {
                await _col.add(data);
              }
              if (context.mounted) Navigator.pop(context);
            },
            child: Text(isEdit ? 'Cập nhật' : 'Thêm'),
          ),
        ],
      ),
    );
  }

  // ────────────────────────────────────────────────────────────────────────────
  // DELETE: Xác nhận xoá (AlertDialog theo theme)
  // ────────────────────────────────────────────────────────────────────────────
  Future<void> _deletePolicy(String id) async {
    final cs = Theme.of(context).colorScheme;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: cs.surface,
        surfaceTintColor: cs.surfaceTint,
        title: Text('Xóa chính sách này?', style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.w700)),
        content: Text('Hành động này không thể hoàn tác.', style: TextStyle(color: cs.onSurfaceVariant)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Hủy', style: TextStyle(color: cs.primary)),
          ),
          FilledButton.tonal(
            style: ButtonStyle(
              backgroundColor: WidgetStatePropertyAll(cs.errorContainer),
              foregroundColor: WidgetStatePropertyAll(cs.onErrorContainer),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _col.doc(id).delete();
    }
  }

  // ────────────────────────────────────────────────────────────────────────────
  // UI CHÍNH
  // ────────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        backgroundColor: cs.surface,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: cs.onSurface),
        title: Text(
          'Chính sách & Điều khoản',
          style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.w700, fontSize: 18),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.add, color: cs.primary),
            tooltip: 'Thêm',
            onPressed: () => _openForm(),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, thickness: 1, color: cs.outlineVariant),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _col.orderBy('updatedAt', descending: true).snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CupertinoActivityIndicator());
          }
          if (!snap.hasData || snap.data!.docs.isEmpty) {
            return Center(
              child: Text('Chưa có chính sách nào.', style: TextStyle(color: cs.onSurfaceVariant)),
            );
          }

          final docs = snap.data!.docs;
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, i) {
              final d = docs[i];
              final data = d.data() as Map<String, dynamic>? ?? {};
              final isActive = data['isActive'] == true;
              final title = (data['title'] ?? '') as String;
              final content = (data['content'] ?? '') as String;

              return Container(
                margin: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: cs.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: cs.outlineVariant),
                  boxShadow: isDark
                      ? null
                      : [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(14),
                  title: Text(
                    title,
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: cs.onSurface),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      content,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13.5),
                    ),
                  ),
                  trailing: Wrap(
                    spacing: 2,
                    children: [
                      Switch.adaptive(
                        value: isActive,
                        onChanged: (v) => _col.doc(d.id).update({'isActive': v}),
                      ),
                      IconButton(
                        tooltip: 'Sửa',
                        icon: Icon(Icons.edit_outlined, color: cs.primary),
                        onPressed: () => _openForm(doc: d),
                      ),
                      IconButton(
                        tooltip: 'Xóa',
                        icon: const Icon(Icons.delete_outline),
                        color: cs.error,
                        onPressed: () => _deletePolicy(d.id),
                      ),
                    ],
                  ),
                  onTap: () => _openForm(doc: d),
                ),
              );
            },
          );
        },
      ),
    );
  }

  // ────────────────────────────────────────────────────────────────────────────
  // Helpers (theo theme)
  // ────────────────────────────────────────────────────────────────────────────
  static OutlineInputBorder _outlined(ColorScheme cs, {Color? outline}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: outline ?? cs.outline),
    );
  }

  static Color _fieldFill(ColorScheme cs) {
    return cs.brightness == Brightness.dark
        ? cs.surfaceVariant.withOpacity(0.35)
        : cs.surfaceVariant.withOpacity(0.4);
  }
}
