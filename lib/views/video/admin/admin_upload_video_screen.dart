import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/product_min.dart';
import '../services/cloudinary_video_uploader.dart';
import '../../../config/cloudinary_config.dart';

class AdminUploadVideoScreen extends StatefulWidget {
  const AdminUploadVideoScreen({super.key});

  @override
  State<AdminUploadVideoScreen> createState() => _AdminUploadVideoScreenState();
}

class _AdminUploadVideoScreenState extends State<AdminUploadVideoScreen> {
  final _formKey = GlobalKey<FormState>();

  // ✅ Dropdown value dùng String để tránh lỗi "exactly one item"
  String? _selectedProductId;
  String? _selectedProductName;

  // ✅ Mobile/Desktop: chỉ lưu path (UI không import dart:io -> web build OK)
  String? _videoPath;

  // ✅ Web: bytes
  Uint8List? _videoBytes;
  String? _videoName;

  double _progress = 0;
  bool _uploading = false;

  final _titleCtl = TextEditingController();
  final _orderCtl = TextEditingController(text: '1');
  final _voucherTextCtl = TextEditingController();
  final _voucherCodeCtl = TextEditingController();

  late final CloudinaryVideoUploader _uploader = CloudinaryVideoUploader(
    cloudName: CloudinaryConfig.cloudName,
    uploadPreset: CloudinaryConfig.uploadPreset,
  );

  @override
  void dispose() {
    _titleCtl.dispose();
    _orderCtl.dispose();
    _voucherTextCtl.dispose();
    _voucherCodeCtl.dispose();
    super.dispose();
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  bool get _hasVideoSelected {
    if (kIsWeb) return _videoBytes != null && (_videoName ?? '').isNotEmpty;
    return (_videoPath ?? '').isNotEmpty;
  }

  String get _fileLabel {
    if (kIsWeb) return _videoName == null ? 'Chưa chọn video' : _videoName!;
    if ((_videoPath ?? '').isEmpty) return 'Chưa chọn video';
    return _videoPath!.split(RegExp(r'[\\/]+')).last;
  }

  Future<void> pickVideo() async {
    try {
      final res = await FilePicker.platform.pickFiles(
        type: FileType.video,
        withData: kIsWeb, // web cần bytes
      );
      if (res == null || res.files.isEmpty) return;

      final f = res.files.single;

      if (kIsWeb) {
        if (f.bytes == null) {
          _snack('Không lấy được bytes video trên Web. Hãy thử lại.');
          return;
        }
        setState(() {
          _videoBytes = f.bytes!;
          _videoName = f.name;
          _videoPath = null;
        });
        return;
      }

      // Mobile/Desktop
      if (f.path == null || f.path!.isEmpty) {
        _snack('Không lấy được path video. Hãy thử lại.');
        return;
      }

      setState(() {
        _videoPath = f.path!;
        _videoBytes = null;
        _videoName = f.name;
      });
    } catch (e) {
      _snack('Lỗi chọn video: $e');
    }
  }

  Future<void> uploadAndCreateVideo() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final productId = _selectedProductId;
    final productName = (_selectedProductName ?? '').trim();

    if (productId == null || productId.isEmpty) {
      _snack('Vui lòng chọn sản phẩm');
      return;
    }
    if (!_hasVideoSelected) {
      _snack('Vui lòng chọn video');
      return;
    }

    // title default = tên sản phẩm (nếu không nhập)
    final titleInput = _titleCtl.text.trim();
    final title = titleInput.isEmpty
        ? (productName.isEmpty ? 'Video sản phẩm' : productName)
        : titleInput;

    final order = int.tryParse(_orderCtl.text.trim()) ?? 0;

    setState(() {
      _uploading = true;
      _progress = 0;
    });

    try {
      final videoRef = FirebaseFirestore.instance.collection('videos').doc();

      // ✅ Upload Cloudinary (progress thật)
      final result = await _uploader.uploadVideoAuto(
        filePath: _videoPath, // mobile/desktop
        bytes: _videoBytes,   // web
        filename: _videoName ?? 'video.mp4',
        folder: 'cses/videos',
        onProgress: (p) {
          if (!mounted) return;
          setState(() => _progress = p);
        },
      );

      // ✅ (Khuyến nghị) thumbUrl để admin list đẹp hơn
      final thumbUrl = _uploader.buildThumbUrl(
        result.publicId,
        second: 0,
        width: 480,
      );

      await videoRef.set({
        'title': title,
        'productId': productId,
        'videoUrl': result.secureUrl,
        'cloudPublicId': result.publicId,
        'thumbUrl': thumbUrl,
        'active': true,
        'order': order,
        'voucherText': _voucherTextCtl.text.trim(),
        'voucherCode': _voucherCodeCtl.text.trim(),
        'views': 0,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      setState(() {
        _videoPath = null;
        _videoBytes = null;
        _videoName = null;

        _progress = 0;
        _uploading = false;

        _titleCtl.clear();
        _orderCtl.text = '1';
        _voucherTextCtl.clear();
        _voucherCodeCtl.clear();
        // giữ lại product đã chọn để upload liên tục cho nhanh
      });

      _snack('Upload & tạo video thành công');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _uploading = false;
        _progress = 0;
      });
      _snack('Lỗi upload: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final productsQuery = FirebaseFirestore.instance
        .collection('products')
        .where('status', isEqualTo: 'active')
        .orderBy('name');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin - Upload Video sản phẩm'),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, c) {
            final maxW = c.maxWidth;
            final isWide = maxW >= 720;
            final outerPad = EdgeInsets.symmetric(
              horizontal: isWide ? 20 : 12,
              vertical: isWide ? 16 : 12,
            );

            return Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 920),
                child: SingleChildScrollView(
                  padding: outerPad,
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _SectionCard(
                          title: 'Thiết lập video',
                          subtitle: 'Chọn sản phẩm → chọn video → nhập thông tin (tuỳ chọn) → Upload.',
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              StreamBuilder<QuerySnapshot>(
                                stream: productsQuery.snapshots(),
                                builder: (context, snap) {
                                  if (snap.hasError) {
                                    return _ErrorBox('Lỗi load products: ${snap.error}');
                                  }
                                  if (!snap.hasData) {
                                    return const LinearProgressIndicator();
                                  }

                                  final products = snap.data!.docs
                                      .map((d) => ProductMin.fromMap(
                                    d.id,
                                    d.data() as Map<String, dynamic>,
                                  ))
                                      .toList();

                                  final items = products
                                      .map((p) => DropdownMenuItem<String>(
                                    value: p.id,
                                    child: Text(p.name, overflow: TextOverflow.ellipsis),
                                  ))
                                      .toList();

                                  final safeValue = (_selectedProductId != null &&
                                      products.any((p) => p.id == _selectedProductId))
                                      ? _selectedProductId
                                      : null;

                                  return DropdownButtonFormField<String>(
                                    value: safeValue,
                                    isExpanded: true,
                                    decoration: InputDecoration(
                                      labelText: 'Chọn sản phẩm *',
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      filled: true,
                                      fillColor: cs.surface,
                                    ),
                                    items: items,
                                    onChanged: _uploading
                                        ? null
                                        : (id) {
                                      if (id == null) return;
                                      final p = products.firstWhere((x) => x.id == id);
                                      setState(() {
                                        _selectedProductId = id;
                                        _selectedProductName = p.name;
                                      });
                                    },
                                    validator: (_) {
                                      if ((_selectedProductId ?? '').isEmpty) {
                                        return 'Vui lòng chọn sản phẩm';
                                      }
                                      return null;
                                    },
                                  );
                                },
                              ),

                              const SizedBox(height: 12),

                              if (isWide)
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      flex: 3,
                                      child: _TextField(
                                        controller: _titleCtl,
                                        enabled: !_uploading,
                                        label: 'Tiêu đề video (tuỳ chọn)',
                                        hint: 'Nếu để trống, tự lấy tên sản phẩm',
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      flex: 2,
                                      child: _TextField(
                                        controller: _orderCtl,
                                        enabled: !_uploading,
                                        label: 'Order',
                                        keyboardType: TextInputType.number,
                                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                        validator: (v) {
                                          final t = (v ?? '').trim();
                                          if (t.isEmpty) return 'Nhập order';
                                          final n = int.tryParse(t);
                                          if (n == null) return 'Order phải là số';
                                          return null;
                                        },
                                      ),
                                    ),
                                  ],
                                )
                              else ...[
                                _TextField(
                                  controller: _titleCtl,
                                  enabled: !_uploading,
                                  label: 'Tiêu đề video (tuỳ chọn)',
                                  hint: 'Nếu để trống, tự lấy tên sản phẩm',
                                ),
                                const SizedBox(height: 12),
                                _TextField(
                                  controller: _orderCtl,
                                  enabled: !_uploading,
                                  label: 'Order',
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                  validator: (v) {
                                    final t = (v ?? '').trim();
                                    if (t.isEmpty) return 'Nhập order';
                                    final n = int.tryParse(t);
                                    if (n == null) return 'Order phải là số';
                                    return null;
                                  },
                                ),
                              ],

                              const SizedBox(height: 12),

                              LayoutBuilder(
                                builder: (context, box) {
                                  final narrow = box.maxWidth < 560;
                                  if (narrow) {
                                    return Column(
                                      children: [
                                        _TextField(
                                          controller: _voucherTextCtl,
                                          enabled: !_uploading,
                                          label: 'Voucher text (tuỳ chọn)',
                                          hint: 'VD: Giảm 50K cho đơn từ 2tr',
                                        ),
                                        const SizedBox(height: 12),
                                        _TextField(
                                          controller: _voucherCodeCtl,
                                          enabled: !_uploading,
                                          label: 'Voucher code (tuỳ chọn)',
                                          hint: 'VD: CSES50K',
                                        ),
                                      ],
                                    );
                                  }
                                  return Row(
                                    children: [
                                      Expanded(
                                        child: _TextField(
                                          controller: _voucherTextCtl,
                                          enabled: !_uploading,
                                          label: 'Voucher text (tuỳ chọn)',
                                          hint: 'VD: Giảm 50K cho đơn từ 2tr',
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: _TextField(
                                          controller: _voucherCodeCtl,
                                          enabled: !_uploading,
                                          label: 'Voucher code (tuỳ chọn)',
                                          hint: 'VD: CSES50K',
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 12),

                        _SectionCard(
                          title: 'Chọn file video',
                          subtitle: kIsWeb
                              ? 'Web: upload bằng bytes.'
                              : 'Mobile/Desktop: upload bằng file path.',
                          child: Column(
                            children: [
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: cs.surfaceContainerHighest,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(Icons.video_file_outlined, color: cs.primary),
                                ),
                                title: Text(
                                  _fileLabel,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontWeight: FontWeight.w800),
                                ),
                                subtitle: Text(
                                  _hasVideoSelected ? 'Đã chọn video' : 'Chưa chọn video (bắt buộc)',
                                  style: TextStyle(color: cs.onSurfaceVariant),
                                ),
                                trailing: OutlinedButton.icon(
                                  onPressed: _uploading ? null : pickVideo,
                                  icon: const Icon(Icons.upload_file),
                                  label: const Text('Chọn'),
                                ),
                              ),
                              const SizedBox(height: 6),
                              if (!_hasVideoSelected)
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    'Vui lòng chọn video trước khi upload.',
                                    style: TextStyle(color: cs.error, fontSize: 12),
                                  ),
                                ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 12),

                        _SectionCard(
                          title: 'Thực hiện',
                          subtitle: 'Kiểm tra lại thông tin trước khi tạo video.',
                          child: Column(
                            children: [
                              if (_uploading) ...[
                                LinearProgressIndicator(
                                  value: (_progress <= 0 || _progress >= 1) ? null : _progress,
                                ),
                                const SizedBox(height: 10),
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    'Đang upload... ${(_progress * 100).clamp(0, 100).toStringAsFixed(0)}%',
                                    style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
                                  ),
                                ),
                                const SizedBox(height: 10),
                              ],
                              SizedBox(
                                width: double.infinity,
                                height: 48,
                                child: FilledButton.icon(
                                  onPressed: _uploading ? null : uploadAndCreateVideo,
                                  icon: _uploading
                                      ? SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.2,
                                      color: cs.onPrimary,
                                    ),
                                  )
                                      : const Icon(Icons.cloud_upload_outlined),
                                  label: Text(_uploading ? 'Đang upload...' : 'Upload & Tạo video'),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 14),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// ===================== UI Helpers =====================

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
          const SizedBox(height: 4),
          Text(subtitle, style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _TextField extends StatelessWidget {
  const _TextField({
    required this.controller,
    required this.enabled,
    required this.label,
    this.hint,
    this.keyboardType,
    this.inputFormatters,
    this.validator,
  });

  final TextEditingController controller;
  final bool enabled;
  final String label;
  final String? hint;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return TextFormField(
      controller: controller,
      enabled: enabled,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        filled: true,
        fillColor: cs.surface,
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

class _ErrorBox extends StatelessWidget {
  final String text;
  const _ErrorBox(this.text);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.error.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.error.withOpacity(0.25)),
      ),
      child: Text(text, style: TextStyle(color: cs.error)),
    );
  }
}
