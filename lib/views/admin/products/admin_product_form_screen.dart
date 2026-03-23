import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../../../controllers/admin_product_controller.dart';
import '../../../services/cloudinary_service.dart';
import '../widgets/admin_drawer.dart';

class AdminProductFormScreen extends StatefulWidget {
  const AdminProductFormScreen({super.key});
  @override
  State<AdminProductFormScreen> createState() => _AdminProductFormScreenState();
}

class _AdminProductFormScreenState extends State<AdminProductFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtl = TextEditingController();
  final _skuCtl = TextEditingController();
  final _priceCtl = TextEditingController();
  final _imageCtl = TextEditingController();
  final _descCtl = TextEditingController();

  String? _brandId;
  String? _categoryId;
  String _status = 'active';
  String? productId;
  bool initLoaded = false;
  bool _uploading = false;

  final _pendingVariants = <_VariantDraft>[];
  final _cloud = CloudinaryService();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (initLoaded) return;

    final c = context.read<AdminProductController>();
    final args = ModalRoute.of(context)!.settings.arguments;

    if (args is String) {
      productId = args;
      _loadProduct(args, c);
    } else {
      c.refreshRefs();
    }
    initLoaded = true;
  }

  Future<void> _loadProduct(String id, AdminProductController c) async {
    await c.refreshRefs();
    final data = await c.getProductById(id);
    if (data != null && mounted) {
      _nameCtl.text = data['name'] ?? '';
      _skuCtl.text = data['sku'] ?? '';
      _priceCtl.text = (data['price'] ?? 0).toString();
      _imageCtl.text = data['imageUrl'] ?? '';
      _descCtl.text = data['description'] ?? '';
      _brandId = data['brandId'];
      _categoryId = data['categoryId'];
      _status = data['status'] ?? 'active';
      setState(() {});
    }
  }

  Future<String> _uploadToFirebase(String localPath) async {
    setState(() => _uploading = true);
    final fileName =
        'products/${DateTime.now().millisecondsSinceEpoch}_${p.basename(localPath)}';
    final ref = FirebaseStorage.instance.ref().child(fileName);
    final upload = await ref.putFile(File(localPath));
    final url = await upload.ref.getDownloadURL();
    setState(() => _uploading = false);
    return url;
  }

  Future<String?> _uploadToCloudinary(File file) async {
    try {
      setState(() => _uploading = true);
      final url = await _cloud.uploadImage(file, folder: 'products');
      setState(() => _uploading = false);
      return url;
    } catch (e) {
      setState(() => _uploading = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Lỗi Cloudinary: $e')));
      return null;
    }
  }

  Future<void> _pickImage({bool useCloudinary = false}) async {
    final res = await ImagePicker()
        .pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (res == null) return;

    final file = File(res.path);
    final url = useCloudinary
        ? await _uploadToCloudinary(file)
        : await _uploadToFirebase(res.path);

    if (url != null) {
      _imageCtl.text = url;
      if (mounted) setState(() {});
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final c = context.read<AdminProductController>();

    final createdId = await c.upsertProduct(
      id: productId,
      name: _nameCtl.text.trim(),
      price: double.tryParse(_priceCtl.text.trim()) ?? 0,
      sku: _skuCtl.text.trim().isEmpty ? null : _skuCtl.text.trim(),
      brandId: _brandId,
      categoryId: _categoryId,
      description: _descCtl.text.trim().isEmpty ? null : _descCtl.text.trim(),
      imageUrl: _imageCtl.text.trim().isEmpty ? null : _imageCtl.text.trim(),
      status: _status,
    );

    // Sản phẩm mới + có pending variants -> tạo variants kèm theo
    if (productId == null && _pendingVariants.isNotEmpty) {
      for (final v in _pendingVariants) {
        await c.upsertVariant(
          productId: createdId,
          size: v.size,
          color: v.color,
          price: v.price,
          stock: v.stock,
          imageUrl: v.imageUrl,
        );
      }
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            productId == null ? '✅ Đã thêm sản phẩm' : '✅ Đã lưu thay đổi'),
      ),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<AdminProductController>();
    final cs = Theme.of(context).colorScheme;
    // Mỗi lần build sẽ gọi lại getVariants để lấy mới khi có sửa / xoá
    final variantsFuture = productId == null ? null : c.getVariants(productId!);

    return Scaffold(
      backgroundColor: cs.background,
      drawer: const AdminDrawer(),
      appBar: AppBar(
        backgroundColor: cs.surface,
        foregroundColor: cs.onSurface,
        elevation: 0,
        centerTitle: true,
        title: Text(
          productId == null ? 'Thêm sản phẩm' : 'Sửa sản phẩm',
          style: TextStyle(
            color: cs.primary,
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
        actions: [
          if (!_uploading)
            IconButton(
              icon: Icon(Icons.save_outlined, color: cs.secondary),
              tooltip: 'Lưu',
              onPressed: _save,
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // ===== ẢNH SẢN PHẨM =====
            GestureDetector(
              onTap: () async {
                await showModalBottomSheet(
                  context: context,
                  backgroundColor: Colors.transparent,
                  builder: (_) {
                    final mcs = Theme.of(context).colorScheme;
                    return Padding(
                      padding: const EdgeInsets.all(16),
                      child: Material(
                        color: mcs.surface,
                        borderRadius: BorderRadius.circular(18),
                        child: Wrap(
                          children: [
                            ListTile(
                              leading: Icon(Icons.cloud_upload_outlined,
                                  color: mcs.primary),
                              title: const Text('Upload Firebase'),
                              onTap: () async {
                                Navigator.pop(context);
                                await _pickImage(useCloudinary: false);
                              },
                            ),
                            ListTile(
                              leading: Icon(Icons.cloud_queue_outlined,
                                  color: mcs.primary),
                              title: const Text('Upload Cloudinary'),
                              onTap: () async {
                                Navigator.pop(context);
                                await _pickImage(useCloudinary: true);
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
              child: Container(
                height: 200,
                decoration: BoxDecoration(
                  color: cs.surface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: cs.outlineVariant),
                  boxShadow: [
                    BoxShadow(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.black.withOpacity(.35)
                          : Colors.black.withOpacity(.07),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    )
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  children: [
                    if (_imageCtl.text.isNotEmpty)
                      Image.network(
                        _imageCtl.text,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        errorBuilder: (_, __, ___) => Center(
                          child: Icon(Icons.broken_image_outlined,
                              size: 48, color: cs.onSurfaceVariant),
                        ),
                      )
                    else
                      Center(
                        child: Icon(Icons.photo,
                            size: 48, color: cs.onSurfaceVariant),
                      ),
                    if (_uploading)
                      const Center(child: CircularProgressIndicator()),
                    Positioned(
                      bottom: 12,
                      right: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: cs.surface.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: cs.outlineVariant),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.camera_alt_outlined,
                                size: 16, color: cs.primary),
                            const SizedBox(width: 4),
                            Text('Chọn ảnh',
                                style: TextStyle(
                                    color: cs.primary, fontSize: 13)),
                          ],
                        ),
                      ),
                    )
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // ===== THÔNG TIN CƠ BẢN =====
            _buildField(context, _nameCtl, 'Tên sản phẩm', 'Nhập tên sản phẩm'),
            _buildField(context, _skuCtl, 'SKU', 'Nhập mã SKU'),
            _buildField(context, _priceCtl, 'Giá bán', 'Nhập giá sản phẩm',
                keyboardType: TextInputType.number),
            _buildField(context, _descCtl, 'Mô tả', 'Nhập mô tả ngắn',
                maxLines: 3),

            // ===== THƯƠNG HIỆU / DANH MỤC =====
            _buildDropdown(
              context,
              'Thương hiệu',
              _brandId,
              c.brands,
                  (v) => setState(() => _brandId = v),
            ),
            _buildDropdown(
              context,
              'Danh mục',
              _categoryId,
              c.categories,
                  (v) => setState(() => _categoryId = v),
            ),

            // ===== TRẠNG THÁI =====
            DropdownButtonFormField<String>(
              value: _status,
              items: const [
                DropdownMenuItem(value: 'active', child: Text('Đang bán')),
                DropdownMenuItem(value: 'inactive', child: Text('Tạm ẩn')),
              ],
              onChanged: (v) => setState(() => _status = v ?? 'active'),
              decoration: _inputDeco(context, 'Trạng thái'),
            ),

            const SizedBox(height: 24),

            const Text('Biến thể (size / màu / giá / tồn kho)',
                style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),

            if (productId == null) ...[
              // Sản phẩm mới: quản lý list pending trong RAM
              ..._pendingVariants.asMap().entries.map((e) {
                final i = e.key;
                final v = e.value;
                return _VariantCard(
                  title: 'Size: ${v.size ?? '-'} | Màu: ${v.color ?? '-'}',
                  subtitle: 'Giá: ${v.price} • Tồn: ${v.stock}',
                  imageUrl: v.imageUrl,
                  onDelete: () => setState(() => _pendingVariants.removeAt(i)),
                );
              }),
              OutlinedButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('Thêm biến thể'),
                onPressed: () => _showVariantSheet(),
              ),
            ] else
              FutureBuilder<List<Map<String, dynamic>>>(
                future: variantsFuture,
                builder: (context, snap) {
                  final variants =
                      snap.data ?? const <Map<String, dynamic>>[];

                  return Column(
                    children: [
                      ...variants.map(
                            (v) => _VariantCard(
                          title:
                          'Size: ${v['size'] ?? '-'} | Màu: ${v['color'] ?? '-'}',
                          subtitle:
                          'Giá: ${v['price']} • Tồn: ${v['stock']}',
                          imageUrl: v['imageUrl'] as String?,
                          // ✅ Tap để sửa biến thể đã có
                          onTap: () => _showVariantSheet(
                            id: v['id'] as String?,
                            draft: _VariantDraft(
                              size: v['size'] as String?,
                              color: v['color'] as String?,
                              price: (v['price'] is num)
                                  ? (v['price'] as num).toDouble()
                                  : double.tryParse(
                                  v['price']?.toString() ?? '') ??
                                  0,
                              stock: (v['stock'] is num)
                                  ? (v['stock'] as num).toInt()
                                  : int.tryParse(
                                  v['stock']?.toString() ?? '') ??
                                  0,
                              imageUrl: v['imageUrl'] as String?,
                            ),
                          ),
                          // ✅ Xoá biến thể đã có
                          onDelete: () async {
                            final id = v['id'] as String?;
                            if (id == null || productId == null) return;
                            await context
                                .read<AdminProductController>()
                                .deleteVariant(productId!, id);
                            if (mounted) setState(() {});
                          },
                        ),
                      ),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.add),
                        label: const Text('Thêm biến thể'),
                        onPressed: () => _showVariantSheet(),
                      ),
                    ],
                  );
                },
              ),

            const SizedBox(height: 24),

            ElevatedButton.icon(
              onPressed: _save,
              icon: Icon(Icons.save_outlined, color: cs.onSecondaryContainer),
              label: Text(
                'Lưu sản phẩm',
                style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: cs.onSecondaryContainer),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: cs.secondaryContainer,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                padding:
                const EdgeInsets.symmetric(vertical: 14, horizontal: 32),
                elevation: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===== Bottom sheet biến thể =====
  Future<void> _showVariantSheet({String? id, _VariantDraft? draft}) async {
    final sizeCtl = TextEditingController(text: draft?.size ?? '');
    final colorCtl = TextEditingController(text: draft?.color ?? '');
    final priceCtl =
    TextEditingController(text: draft?.price?.toString() ?? '');
    final stockCtl =
    TextEditingController(text: draft?.stock?.toString() ?? '');
    final imgCtl = TextEditingController(text: draft?.imageUrl ?? '');
    bool uploading = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (context, setModalState) {
          final cs = Theme.of(context).colorScheme;
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom + 12,
              left: 16,
              right: 16,
              top: 12,
            ),
            child: Material(
              color: cs.surface,
              borderRadius: BorderRadius.circular(22),
              elevation: 3,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 14),
                        decoration: BoxDecoration(
                          color: cs.outlineVariant,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    Center(
                      child: Text(
                        id == null
                            ? 'Thêm biến thể'
                            : 'Sửa biến thể', // ✅ đổi title khi edit
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 18,
                            color: cs.primary),
                      ),
                    ),
                    const SizedBox(height: 16),

                    _variantField(context, sizeCtl, 'Size', 'Nhập size'),
                    _variantField(context, colorCtl, 'Màu', 'Nhập màu'),
                    _variantField(context, priceCtl, 'Giá', 'Nhập giá',
                        keyboardType: TextInputType.number),
                    _variantField(context, stockCtl, 'Tồn kho', 'Số lượng tồn',
                        keyboardType: TextInputType.number),

                    const SizedBox(height: 8),
                    Text('Ảnh biến thể',
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: cs.onSurface)),
                    const SizedBox(height: 6),

                    Row(
                      children: [
                        _VariantImagePreview(url: imgCtl.text),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: imgCtl,
                            decoration: InputDecoration(
                              hintText: 'URL hoặc chọn ảnh…',
                              filled: true,
                              fillColor: cs.surfaceVariant.withOpacity(.4),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide:
                                BorderSide(color: cs.outlineVariant),
                              ),
                              suffixIcon: PopupMenuButton<String>(
                                icon: Icon(Icons.photo_library_outlined,
                                    color: cs.primary),
                                tooltip: 'Chọn nguồn upload',
                                onSelected: (v) async {
                                  final res = await ImagePicker().pickImage(
                                      source: ImageSource.gallery,
                                      imageQuality: 85);
                                  if (res == null) return;
                                  setModalState(() => uploading = true);

                                  String url;
                                  if (v == 'firebase') {
                                    url = await _uploadToFirebase(res.path);
                                  } else {
                                    url = (await _uploadToCloudinary(
                                      File(res.path),
                                    )) ??
                                        '';
                                  }

                                  setModalState(() {
                                    imgCtl.text = url;
                                    uploading = false;
                                  });
                                },
                                itemBuilder: (_) => const [
                                  PopupMenuItem(
                                      value: 'firebase',
                                      child: Text('Upload Firebase')),
                                  PopupMenuItem(
                                      value: 'cloudinary',
                                      child: Text('Upload Cloudinary')),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (uploading)
                      const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: LinearProgressIndicator(),
                      ),

                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: Icon(Icons.save_outlined,
                            color: Theme.of(context)
                                .colorScheme
                                .onSecondaryContainer),
                        label: Text(
                          'Lưu biến thể',
                          style: TextStyle(
                            color: Theme.of(context)
                                .colorScheme
                                .onSecondaryContainer,
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context)
                              .colorScheme
                              .secondaryContainer,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          elevation: 0,
                        ),
                        onPressed: () async {
                          final newDraft = _VariantDraft(
                            size: sizeCtl.text.trim(),
                            color: colorCtl.text.trim(),
                            price: double.tryParse(priceCtl.text) ?? 0,
                            stock: int.tryParse(stockCtl.text) ?? 0,
                            imageUrl: imgCtl.text.trim(),
                          );

                          if (productId == null) {
                            // Sản phẩm mới -> chỉ thêm vào list pending
                            setState(() => _pendingVariants.add(newDraft));
                          } else {
                            // ✅ Sản phẩm đã có -> cập nhật hoặc thêm mới variant trên Firestore
                            await context
                                .read<AdminProductController>()
                                .upsertVariant(
                              id: id, // <-- truyền id vào để update
                              productId: productId!,
                              size: newDraft.size,
                              color: newDraft.color,
                              price: newDraft.price,
                              stock: newDraft.stock,
                              imageUrl: newDraft.imageUrl,
                            );
                            if (mounted) setState(() {});
                          }

                          if (mounted) Navigator.pop(context);
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ===== helpers UI =====
  Widget _variantField(
      BuildContext context,
      TextEditingController ctl,
      String label,
      String hint, {
        TextInputType? keyboardType,
      }) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: ctl,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          filled: true,
          fillColor: cs.surfaceVariant.withOpacity(.4),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: cs.outlineVariant),
          ),
          contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        ),
      ),
    );
  }

  InputDecoration _inputDeco(BuildContext context, String label) {
    final cs = Theme.of(context).colorScheme;
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: cs.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: cs.outlineVariant),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: cs.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: cs.primary),
      ),
      contentPadding:
      const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
    );
  }

  Widget _buildField(
      BuildContext context,
      TextEditingController ctl,
      String label,
      String hint, {
        TextInputType? keyboardType,
        int maxLines = 1,
      }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: ctl,
        keyboardType: keyboardType,
        maxLines: maxLines,
        validator: (v) =>
        (v == null || v.trim().isEmpty) ? 'Vui lòng nhập $label' : null,
        decoration: _inputDeco(context, label).copyWith(hintText: hint),
      ),
    );
  }

  /// Dropdown hỗ trợ giá trị null (chọn “Chọn giá trị”)
  Widget _buildDropdown(
      BuildContext context,
      String label,
      String? value,
      List<Map<String, dynamic>> items,
      void Function(String?) onChanged,
      ) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: DropdownButtonFormField<String?>(
        value: value,
        isExpanded: true,
        items: [
          DropdownMenuItem<String?>(
              value: null,
              child: Text('Chọn giá trị',
                  style: TextStyle(color: cs.onSurfaceVariant))),
          ...items.map(
                (e) => DropdownMenuItem<String?>(
              value: e['id'] as String?,
              child: Text(e['name'] ?? ''),
            ),
          ),
        ],
        onChanged: onChanged,
        decoration: _inputDeco(context, label),
      ),
    );
  }
}

class _VariantCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String? imageUrl;
  final VoidCallback? onDelete;
  final VoidCallback? onTap; // ✅ thêm onTap để mở bottom-sheet edit

  const _VariantCard({
    required this.title,
    required this.subtitle,
    this.imageUrl,
    this.onDelete,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.black.withOpacity(.30)
                : Colors.black.withOpacity(.06),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ListTile(
        onTap: onTap, // ✅ tap để sửa
        leading: _VariantImagePreview(url: imageUrl),
        title: Text(title,
            style:
            TextStyle(fontWeight: FontWeight.w700, color: cs.onSurface)),
        subtitle:
        Text(subtitle, style: TextStyle(color: cs.onSurfaceVariant)),
        trailing: (onDelete == null)
            ? null
            : IconButton(
          tooltip: 'Xoá biến thể',
          icon:
          const Icon(Icons.delete_outline, color: Colors.redAccent),
          onPressed: onDelete,
        ),
      ),
    );
  }
}

class _VariantImagePreview extends StatelessWidget {
  final String? url;
  const _VariantImagePreview({this.url});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    const size = 48.0;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: cs.surfaceVariant.withOpacity(.4),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: cs.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: (url != null && url!.isNotEmpty)
          ? Image.network(
        url!,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) =>
            Icon(Icons.broken_image_outlined, color: cs.onSurfaceVariant),
      )
          : Icon(Icons.image_outlined, color: cs.onSurfaceVariant),
    );
  }
}

class _VariantDraft {
  final String? size;
  final String? color;
  final double price;
  final int stock;
  final String? imageUrl;
  _VariantDraft({
    this.size,
    this.color,
    required this.price,
    required this.stock,
    this.imageUrl,
  });
}
