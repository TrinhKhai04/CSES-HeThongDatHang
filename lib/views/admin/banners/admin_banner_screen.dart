// ignore_for_file: unnecessary_const, use_build_context_synchronously

import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:path/path.dart' as p;

import '../widgets/admin_drawer.dart';
import '../../../services/cloudinary_service.dart';

class AdminBannerScreen extends StatefulWidget {
  const AdminBannerScreen({super.key});
  @override
  State<AdminBannerScreen> createState() => _AdminBannerScreenState();
}

class _AdminBannerScreenState extends State<AdminBannerScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleCtl;
  late final TextEditingController _imageCtl;

  bool _active = true;
  bool _uploading = false;
  bool _openingSheet = false;

  final _cloud = CloudinaryService();
  final _picker = ImagePicker();
  final _col = FirebaseFirestore.instance.collection('banners');

  @override
  void initState() {
    super.initState();
    _titleCtl = TextEditingController();
    _imageCtl = TextEditingController();
  }

  @override
  void dispose() {
    _titleCtl.dispose();
    _imageCtl.dispose();
    super.dispose();
  }

  Future<String?> _uploadToFirebase(String path) async {
    try {
      setState(() => _uploading = true);
      final fileName =
          'banners/${DateTime.now().millisecondsSinceEpoch}_${p.basename(path)}';
      final ref = FirebaseStorage.instance.ref().child(fileName);
      final file = File(path);
      await ref.putFile(file);
      return await ref.getDownloadURL();
    } catch (e) {
      debugPrint('❌ Firebase upload failed: $e');
      return null;
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<String?> _uploadToCloudinary(File file) async {
    try {
      setState(() => _uploading = true);
      final url = await _cloud.uploadImage(file, folder: 'banners');
      return url;
    } catch (e) {
      debugPrint('❌ Cloudinary upload failed: $e');
      return null;
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _pickImage({bool useCloudinary = false}) async {
    final res =
    await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (res == null) return;
    final file = File(res.path);
    final url =
    useCloudinary ? await _uploadToCloudinary(file) : await _uploadToFirebase(res.path);
    if (url != null && mounted) {
      _imageCtl.text = url;
      setState(() {});
    }
  }

  Future<void> _onOpenSheetDebounced({
    String? docId,
    String initTitle = '',
    String initImageUrl = '',
    bool initActive = true,
  }) async {
    if (_openingSheet) return;
    _openingSheet = true;
    try {
      await _openBannerSheet(
        docId: docId,
        initTitle: initTitle,
        initImageUrl: initImageUrl,
        initActive: initActive,
      );
    } finally {
      _openingSheet = false;
    }
  }

  Future<void> _openBannerSheet({
    String? docId,
    String initTitle = '',
    String initImageUrl = '',
    bool initActive = true,
  }) async {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    _titleCtl.text = initTitle;
    _imageCtl.text = initImageUrl;
    _active = initActive;
    setState(() {});

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: cs.surface,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) {
        final bottom = MediaQuery.of(ctx).viewInsets.bottom;
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(16, 12, 16, bottom + 16),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        docId == null ? 'Thêm banner mới' : 'Chỉnh sửa banner',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                          color: cs.onSurface,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    TextFormField(
                      controller: _titleCtl,
                      decoration: InputDecoration(
                        labelText: 'Tiêu đề banner',
                        border: _outlined(cs),
                        enabledBorder: _outlined(cs, outline: cs.outlineVariant),
                        filled: true,
                        fillColor: _fieldFill(cs),
                      ),
                      validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Nhập tiêu đề' : null,
                    ),
                    const SizedBox(height: 12),

                    Row(
                      children: [
                        _ImagePreview(imageUrl: _imageCtl.text),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _imageCtl,
                            readOnly: true,
                            decoration: InputDecoration(
                              labelText: 'Ảnh (URL)',
                              border: _outlined(cs),
                              enabledBorder:
                              _outlined(cs, outline: cs.outlineVariant),
                              filled: true,
                              fillColor: _fieldFill(cs),
                              suffixIcon: PopupMenuButton<String>(
                                tooltip: 'Chọn nguồn upload',
                                color: cs.surface,
                                surfaceTintColor: cs.surfaceTint,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: BorderSide(color: cs.outlineVariant),
                                ),
                                icon: Icon(CupertinoIcons.photo,
                                    color: cs.onSurfaceVariant),
                                onSelected: (v) async {
                                  if (v == 'firebase') {
                                    await _pickImage(useCloudinary: false);
                                  } else {
                                    await _pickImage(useCloudinary: true);
                                  }
                                  setModalState(() {});
                                },
                                itemBuilder: (_) => [
                                  PopupMenuItem(
                                    value: 'firebase',
                                    child: Text('Upload Firebase',
                                        style: TextStyle(color: cs.onSurface)),
                                  ),
                                  PopupMenuItem(
                                    value: 'cloudinary',
                                    child: Text('Upload Cloudinary',
                                        style: TextStyle(color: cs.onSurface)),
                                  ),
                                ],
                              ),
                            ),
                            validator: (v) => (v == null || v.isEmpty)
                                ? 'Chọn hoặc dán URL ảnh'
                                : null,
                          ),
                        ),
                      ],
                    ),

                    if (_uploading)
                      const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: LinearProgressIndicator(),
                      ),

                    const SizedBox(height: 10),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Kích hoạt', style: TextStyle(color: cs.onSurface)),
                        Switch.adaptive(
                          value: _active,
                          onChanged: (v) {
                            _active = v;
                            setModalState(() {});
                          },
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),

                    SizedBox(
                      width: double.infinity,
                      child: CupertinoButton.filled(
                        borderRadius: BorderRadius.circular(12),
                        onPressed: _uploading
                            ? null
                            : () async {
                          if (!_formKey.currentState!.validate()) return;
                          final data = <String, dynamic>{
                            'title': _titleCtl.text.trim(),
                            'imageUrl': _imageCtl.text.trim(),
                            'active': _active,
                            'updatedAt': FieldValue.serverTimestamp(),
                          };
                          if (docId == null) {
                            data['createdAt'] = FieldValue.serverTimestamp();
                            await _col.add(data);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('✅ Đã thêm banner')),
                            );
                          } else {
                            await _col.doc(docId).update(data);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('✅ Đã cập nhật banner')),
                            );
                          }
                          Navigator.of(context).pop();
                        },
                        child:
                        Text(docId == null ? 'Lưu banner' : 'Cập nhật'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      drawer: const AdminDrawer(),
      appBar: AppBar(
        backgroundColor: cs.surface,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: cs.onSurface),
        title: Text(
          'Khuyến mãi / Banner',
          style: TextStyle(
            color: cs.onSurface,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, thickness: 1, color: cs.outlineVariant),
        ),
      ),

      body: StreamBuilder<QuerySnapshot>(
        stream: _col.orderBy('updatedAt', descending: true).snapshots(),
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(
              child: Text('Lỗi: ${snap.error}',
                  style: TextStyle(color: cs.error)),
            );
          }
          if (!snap.hasData) {
            return const Center(child: CupertinoActivityIndicator());
          }

          final docs = snap.data!.docs;
          if (docs.isEmpty) {
            return Center(
              child: Text('Chưa có banner nào',
                  style: TextStyle(color: cs.onSurfaceVariant)),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
            itemCount: docs.length,
            itemBuilder: (_, i) => _bannerCard(context, docs[i], cs),
          );
        },
      ),

      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: cs.primaryContainer,
        foregroundColor: cs.onPrimaryContainer,
        icon: const Icon(CupertinoIcons.add),
        label: const Text('Thêm'),
        onPressed: () => _onOpenSheetDebounced(),
      ),
    );
  }

  Widget _bannerCard(
      BuildContext context, QueryDocumentSnapshot d, ColorScheme cs) {
    final m = d.data() as Map<String, dynamic>? ?? {};
    final active = (m['active'] ?? false) as bool;
    final title = (m['title'] ?? 'Không tiêu đề') as String;
    final imageUrl = (m['imageUrl'] ?? '') as String;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      key: ValueKey(d.id),
      margin: const EdgeInsets.only(bottom: 14),
      decoration: _cardDecoration(cs, isDark),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),

        leading: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: imageUrl.isNotEmpty
              ? Image.network(
            imageUrl,
            width: 60,
            height: 60,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) =>
                Icon(CupertinoIcons.photo, color: cs.onSurfaceVariant),
          )
              : Container(
            width: 60,
            height: 60,
            color: _fieldFill(cs),
            child: Icon(CupertinoIcons.photo, color: cs.onSurfaceVariant),
          ),
        ),

        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 15,
            color: cs.onSurface,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              active ? 'Đang hiển thị' : 'Đã tắt',
              style: TextStyle(
                color: active ? const Color(0xFF34C759) : cs.onSurfaceVariant,
                fontWeight: FontWeight.w600,
                fontSize: 13.5,
              ),
            ),
            Text(
              'Banner hiển thị trên trang chủ',
              style: TextStyle(fontSize: 12.5, color: cs.onSurfaceVariant),
            ),
          ],
        ),

        trailing: Wrap(
          spacing: 4,
          children: [
            IconButton(
              tooltip: 'Chỉnh sửa',
              icon: Icon(CupertinoIcons.pencil, size: 20, color: cs.onSurface),
              onPressed: () => _onOpenSheetDebounced(
                docId: d.id,
                initTitle: title,
                initImageUrl: imageUrl,
                initActive: active,
              ),
            ),
            Switch.adaptive(
              value: active,
              onChanged: (v) => _col.doc(d.id).update({'active': v}),
            ),
            IconButton(
              tooltip: 'Xoá',
              icon: const Icon(CupertinoIcons.delete, size: 22),
              color: const Color(0xFFFF3B30),
              onPressed: () async {
                final ok = await showCupertinoDialog<bool>(
                  context: context,
                  builder: (_) => CupertinoAlertDialog(
                    title: const Text('Xoá banner này?'),
                    content: const Text('Hành động này không thể hoàn tác.'),
                    actions: [
                      CupertinoDialogAction(
                        child: const Text('Huỷ'),
                        onPressed: () => Navigator.pop(context, false),
                      ),
                      CupertinoDialogAction(
                        isDestructiveAction: true,
                        child: const Text('Xoá'),
                        onPressed: () => Navigator.pop(context, true),
                      ),
                    ],
                  ),
                );
                if (ok == true) {
                  await _col.doc(d.id).delete();
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('🗑️ Đã xoá banner')),
                  );
                }
              },
            ),
          ],
        ),

        onTap: () => _onOpenSheetDebounced(
          docId: d.id,
          initTitle: title,
          initImageUrl: imageUrl,
          initActive: active,
        ),
      ),
    );
  }

  // ======= UI helpers (theo theme) =======
  static BoxDecoration _cardDecoration(ColorScheme cs, bool isDark) {
    return BoxDecoration(
      color: cs.surface,
      borderRadius: BorderRadius.circular(18),
      boxShadow: isDark
          ? null
          : [
        BoxShadow(
          color: Colors.black.withOpacity(0.06),
          blurRadius: 10,
          offset: const Offset(0, 3),
        ),
      ],
      border: Border.all(color: cs.outlineVariant, width: 1),
    );
  }

  static InputBorder _outlined(ColorScheme cs, {Color? outline}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: outline ?? cs.outline),
    );
  }

  static Color _fieldFill(ColorScheme cs) {
    // màu nền nhẹ cho field; trong dark dùng surfaceVariant cho sáng hơn
    return cs.brightness == Brightness.dark
        ? cs.surfaceVariant.withOpacity(0.35)
        : cs.surfaceVariant.withOpacity(0.4);
  }
}

class _ImagePreview extends StatelessWidget {
  final String? imageUrl;
  const _ImagePreview({this.imageUrl});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    const size = 84.0;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant),
        color: _AdminBannerScreenState._fieldFill(cs),
      ),
      clipBehavior: Clip.antiAlias,
      child: (imageUrl != null && imageUrl!.isNotEmpty)
          ? Image.network(
        imageUrl!,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) =>
            Icon(CupertinoIcons.photo_on_rectangle, color: cs.onSurfaceVariant),
      )
          : Icon(CupertinoIcons.photo_on_rectangle, color: cs.onSurfaceVariant),
    );
  }
}
