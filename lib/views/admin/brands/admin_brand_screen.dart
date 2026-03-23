// ignore_for_file: unnecessary_const
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../controllers/admin_product_controller.dart';
import '../widgets/admin_drawer.dart';

class AdminBrandScreen extends StatefulWidget {
  const AdminBrandScreen({super.key});

  @override
  State<AdminBrandScreen> createState() => _AdminBrandScreenState();
}

class _AdminBrandScreenState extends State<AdminBrandScreen> {
  final _db = FirebaseFirestore.instance;
  final String _collection = 'brands';

  Stream<QuerySnapshot<Map<String, dynamic>>> _streamBrands() =>
      _db.collection(_collection).orderBy('name').snapshots();

  // ============================== ADD/EDIT SHEET ==============================

  Future<void> _showEditor({String? id, String? name}) async {
    final ctl = TextEditingController(text: name ?? '');
    final isEdit = id != null;

    // Lấy controller trước để dùng trong onPressed bên trong sheet
    final adminCtrl = context.read<AdminProductController>();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(.35),
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        final mq = MediaQuery.of(ctx);
        final screenH = mq.size.height;
        final isCompact = screenH < 650;
        final sidePad = mq.size.width >= 600 ? 24.0 : 16.0;
        final bottomGap = isCompact ? 10.0 : 18.0;

        return SafeArea(
          top: false,
          child: AnimatedPadding(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            padding: EdgeInsets.only(
              left: sidePad,
              right: sidePad,
              bottom: mq.viewInsets.bottom + bottomGap,
            ),
            child: Align(
              alignment: Alignment.bottomCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Container(
                  decoration: BoxDecoration(
                    color: cs.surface,
                    borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(22)),
                    border: Border.all(color: cs.outlineVariant),
                    boxShadow: [
                      BoxShadow(
                        color: Theme.of(ctx).brightness == Brightness.dark
                            ? Colors.black.withOpacity(.35)
                            : Colors.black.withOpacity(.12),
                        blurRadius: 22,
                        offset: const Offset(0, -4),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      20,
                      isCompact ? 16 : 20,
                      20,
                      isCompact ? 18 : 24,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(
                          child: Text(
                            isEdit ? 'Sửa thương hiệu' : 'Thêm thương hiệu',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: isCompact ? 16 : 17,
                              color: cs.onSurface,
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),

                        CupertinoTextField(
                          controller: ctl,
                          placeholder: 'Tên thương hiệu',
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: cs.surfaceVariant.withOpacity(.7),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: cs.outlineVariant),
                          ),
                          style: TextStyle(color: cs.onSurface),
                          placeholderStyle: TextStyle(
                            color: cs.onSurfaceVariant,
                            fontSize: 14,
                          ),
                        ),

                        const SizedBox(height: 18),

                        // Lưu
                        CupertinoButton(
                          borderRadius: BorderRadius.circular(12),
                          color: cs.primary,
                          onPressed: () async {
                            final n = ctl.text.trim();
                            if (n.isEmpty) return;

                            if (isEdit) {
                              await _db
                                  .collection(_collection)
                                  .doc(id)
                                  .update({
                                'name': n,
                                'updatedAt': FieldValue.serverTimestamp(),
                              });
                            } else {
                              await _db.collection(_collection).add({
                                'name': n,
                                'createdAt': FieldValue.serverTimestamp(),
                              });
                            }

                            Navigator.pop(ctx);
                            adminCtrl.refreshRefs();
                          },
                          child: Text(
                            'Lưu',
                            style: TextStyle(color: cs.onPrimary),
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Huỷ
                        CupertinoButton(
                          borderRadius: BorderRadius.circular(12),
                          color: cs.surface,
                          onPressed: () => Navigator.pop(ctx),
                          child: Text(
                            'Huỷ',
                            style: TextStyle(color: cs.primary),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ================================ DELETE ===================================

  Future<void> _delete(String id, String name) async {
    final cs = Theme.of(context).colorScheme;

    final ok = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Xoá thương hiệu?'),
        content: Text('Bạn có chắc muốn xoá “$name”?'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Huỷ', style: TextStyle(color: cs.primary)),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Xoá'),
          ),
        ],
      ),
    );

    if (ok == true) {
      await _db.collection(_collection).doc(id).delete();
      context.read<AdminProductController>().refreshRefs();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('🗑️ Đã xoá thương hiệu')),
        );
      }
    }
  }

  // ================================ UI =======================================

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final bg = CupertinoColors.systemGroupedBackground.resolveFrom(context);

    return Scaffold(
      backgroundColor: bg,
      drawer: const AdminDrawer(),
      appBar: AppBar(
        backgroundColor: cs.surface,
        foregroundColor: cs.onSurface,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: cs.primary),
        title: Text(
          'Thương hiệu',
          style: TextStyle(
            color: cs.primary,
            fontWeight: FontWeight.w600,
            fontSize: 18,
            letterSpacing: -0.3,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Thêm thương hiệu',
            icon: const Icon(CupertinoIcons.add),
            onPressed: () => _showEditor(),
          ),
        ],
      ),

      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 700;
          final horizontalPadding = isWide ? 24.0 : 16.0;
          final maxContentWidth =
          isWide ? 720.0 : constraints.maxWidth - horizontalPadding * 2;

          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _streamBrands(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CupertinoActivityIndicator(radius: 14),
                );
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return _EmptyState(onAdd: () => _showEditor());
              }

              final docs = snapshot.data!.docs;

              return ListView.separated(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.fromLTRB(
                  horizontalPadding,
                  16,
                  horizontalPadding,
                  24,
                ),
                itemCount: docs.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (_, i) {
                  final d = docs[i];
                  return Align(
                    alignment: Alignment.center,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: maxContentWidth),
                      child: _AppleBrandTile(
                        id: d.id,
                        name: d.data()['name'] ?? '',
                        onEdit: () =>
                            _showEditor(id: d.id, name: d['name'] as String?),
                        onDelete: () =>
                            _delete(d.id, d['name'] as String? ?? ''),
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

// ============================= ITEM TILE ====================================

class _AppleBrandTile extends StatelessWidget {
  const _AppleBrandTile({
    required this.id,
    required this.name,
    required this.onEdit,
    required this.onDelete,
  });

  final String id;
  final String name;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final mq = MediaQuery.of(context);
    final isCompactHeight = mq.size.height < 650;
    final isWide = mq.size.width >= 700;

    final radius = isCompactHeight ? 14.0 : 18.0;
    final verticalPad = isCompactHeight ? 10.0 : 14.0;
    final horizontalPad = isCompactHeight ? 14.0 : 16.0;
    final blur = isWide ? 10.0 : 8.0;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: horizontalPad,
        vertical: verticalPad,
      ),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: cs.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.black.withOpacity(.30)
                : Colors.black.withOpacity(.05),
            blurRadius: blur,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(CupertinoIcons.tag, color: cs.onSurfaceVariant, size: 22),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              name,
              style: TextStyle(
                fontSize: isCompactHeight ? 15 : 16,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.2,
                color: cs.onSurface,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _CircleIconButton(
                tooltip: 'Sửa',
                icon: CupertinoIcons.pencil,
                color: cs.primary,
                onTap: onEdit,
              ),
              const SizedBox(width: 8),
              _CircleIconButton(
                tooltip: 'Xoá',
                icon: CupertinoIcons.delete,
                color: Colors.redAccent,
                onTap: onDelete,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Nút icon dạng chip tròn, dùng lại cho Edit/Delete
class _CircleIconButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final String? tooltip;

  const _CircleIconButton({
    required this.icon,
    required this.color,
    required this.onTap,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final isCompactHeight = mq.size.height < 650;

    final double iconSize = isCompactHeight ? 18 : 20;
    final double pad = isCompactHeight ? 6 : 7;

    final child = InkWell(
      customBorder: const CircleBorder(),
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(pad),
        decoration: BoxDecoration(
          color: color.withOpacity(.06),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: iconSize, color: color),
      ),
    );

    if (tooltip == null || tooltip!.isEmpty) return child;

    return Tooltip(
      message: tooltip!,
      child: child,
    );
  }
}

// ============================= EMPTY STATE ==================================

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAdd});
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(CupertinoIcons.tag, size: 70, color: cs.primary),
            const SizedBox(height: 12),
            Text(
              'Chưa có thương hiệu',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 16,
                color: cs.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              'Nhấn dấu “+” ở góc phải hoặc nút bên dưới để thêm mới.',
              style: TextStyle(color: cs.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 18),
            CupertinoButton(
              color: cs.secondaryContainer,
              borderRadius: BorderRadius.circular(24),
              padding:
              const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              onPressed: onAdd,
              child: Text(
                'Thêm thương hiệu',
                style: TextStyle(color: cs.onSecondaryContainer),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
