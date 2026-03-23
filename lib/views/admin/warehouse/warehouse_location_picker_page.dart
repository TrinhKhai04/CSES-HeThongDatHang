// lib/views/admin/warehouse/warehouse_location_picker_page.dart
import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

/// Loại kho: kho chính / kho trung chuyển
enum WarehouseKind { main, transit }

/// Model local dùng cho map picker (chỉ cần lat/lng/kind)
class _WarehouseDocLocal {
  final double lat;
  final double lng;
  final String kind;

  _WarehouseDocLocal({
    required this.lat,
    required this.lng,
    required this.kind,
  });

  factory _WarehouseDocLocal.fromSnapshot(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    final bool isMainHub = (data['isMainHub'] as bool?) ?? true;
    final String kind =
        (data['kind'] as String?) ?? (isMainHub ? 'main' : 'transit');

    return _WarehouseDocLocal(
      lat: (data['lat'] as num?)?.toDouble() ?? 0,
      lng: (data['lng'] as num?)?.toDouble() ?? 0,
      kind: kind,
    );
  }
}

/* ====================================================================
 *  MÀN 1: MAP ĐỂ PING VỊ TRÍ
 * ====================================================================*/

class WarehouseLocationPickerPage extends StatefulWidget {
  const WarehouseLocationPickerPage({super.key});

  @override
  State<WarehouseLocationPickerPage> createState() =>
      _WarehouseLocationPickerPageState();
}

class _WarehouseLocationPickerPageState
    extends State<WarehouseLocationPickerPage> {
  static const LatLng _vnCenter = LatLng(16.047199, 107.0);

  final MapController _mapController = MapController();

  // Polygon khung Việt Nam (gần đúng, đủ để tạo cảm giác vùng)
  final List<LatLng> _vnPolygon = const [
    LatLng(23.3920, 102.1440), // Tây Bắc
    LatLng(23.3920, 109.4690), // Đông Bắc
    LatLng(8.1790, 109.4690),  // Đông Nam
    LatLng(8.1790, 102.1440),  // Tây Nam
  ];

  bool _showMain = true;
  bool _showTransit = true;

  Stream<List<_WarehouseDocLocal>> _warehouseStream() {
    return FirebaseFirestore.instance
        .collection('warehouses')
        .snapshots()
        .map((snapshot) =>
        snapshot.docs.map(_WarehouseDocLocal.fromSnapshot).toList());
  }

  void _zoomIn() {
    final z = _mapController.camera.zoom;
    final newZoom = (z + 1).clamp(4.0, 18.0).toDouble();
    _mapController.move(_mapController.camera.center, newZoom);
  }

  void _zoomOut() {
    final z = _mapController.camera.zoom;
    final newZoom = (z - 1).clamp(4.0, 18.0).toDouble();
    _mapController.move(_mapController.camera.center, newZoom);
  }

  void _resetView() {
    _mapController.move(_vnCenter, 5.8);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bg = CupertinoColors.systemGroupedBackground.resolveFrom(context);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: cs.surface,
        foregroundColor: cs.onSurface,
        elevation: 0,
        title: Text(
          'Chọn vị trí kho',
          style: TextStyle(
            color: cs.primary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding:
            const EdgeInsets.only(left: 16, right: 16, top: 10, bottom: 4),
            child: Row(
              children: [
                Icon(
                  CupertinoIcons.info_circle_fill,
                  size: 16,
                  color: cs.primary,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Chạm lên bản đồ để ping vị trí kho.\nSau khi chọn, hệ thống sẽ mở form để nhập thông tin chi tiết.',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.35,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
              child: StreamBuilder<List<_WarehouseDocLocal>>(
                stream: _warehouseStream(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return const Center(
                        child: Text('Lỗi khi tải danh sách kho hiện có.'));
                  }

                  final list = snapshot.data ?? [];

                  final mainMarkers = _showMain
                      ? list
                      .where((w) => w.kind == 'main')
                      .map(
                        (w) => Marker(
                      width: 34,
                      height: 34,
                      point: LatLng(w.lat, w.lng),
                      child: _LegendDot(
                        icon: CupertinoIcons.cube_box_fill,
                        color: cs.primary,
                      ),
                    ),
                  )
                      .toList()
                      : <Marker>[];

                  final transitMarkers = _showTransit
                      ? list
                      .where((w) => w.kind == 'transit')
                      .map(
                        (w) => Marker(
                      width: 30,
                      height: 30,
                      point: LatLng(w.lat, w.lng),
                      child: _LegendDot(
                        icon: CupertinoIcons.building_2_fill,
                        color: Colors.amber.shade800,
                      ),
                    ),
                  )
                      .toList()
                      : <Marker>[];

                  return Container(
                    decoration: BoxDecoration(
                      color: cs.surface,
                      borderRadius: BorderRadius.circular(24),
                      border:
                      Border.all(color: cs.outlineVariant.withOpacity(.4)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(.08),
                          blurRadius: 18,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: Stack(
                        children: [
                          FlutterMap(
                            mapController: _mapController,
                            options: MapOptions(
                              initialCenter: _vnCenter,
                              initialZoom: 5.8,
                              minZoom: 4.0,
                              maxZoom: 18.0,
                              onTap: (tapPosition, latLng) async {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        _WarehouseCreateFormPage(picked: latLng),
                                  ),
                                );
                              },
                            ),
                            children: [
                              TileLayer(
                                urlTemplate:
                                'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                                subdomains: const ['a', 'b', 'c'],
                                userAgentPackageName: 'com.cses.store',
                              ),
                              // Polygon vùng Việt Nam cho "cảm giác địa lý"
                              PolygonLayer(
                                polygons: [
                                  Polygon(
                                    points: _vnPolygon,
                                    color: cs.primary.withOpacity(.03),
                                    borderColor:
                                    cs.primary.withOpacity(.25),
                                    borderStrokeWidth: 1.2,
                                  ),
                                ],
                              ),
                              MarkerLayer(
                                markers: [
                                  ...mainMarkers,
                                  ...transitMarkers,
                                ],
                              ),
                            ],
                          ),

                          // Legend trên cùng, blur nhẹ
                          Positioned(
                            left: 16,
                            right: 16,
                            top: 12,
                            child: _MapLegendBar(
                              showMain: _showMain,
                              showTransit: _showTransit,
                              onToggleMain: () {
                                setState(() => _showMain = !_showMain);
                              },
                              onToggleTransit: () {
                                setState(() => _showTransit = !_showTransit);
                              },
                            ),
                          ),

                          // Zoom + reset bên phải
                          Positioned(
                            right: 12,
                            bottom: 70,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _ZoomButton(
                                  icon: CupertinoIcons.location_north_fill,
                                  onTap: _resetView,
                                ),
                                const SizedBox(height: 8),
                                _ZoomButton(
                                  icon: CupertinoIcons.plus,
                                  onTap: _zoomIn,
                                ),
                                const SizedBox(height: 8),
                                _ZoomButton(
                                  icon: CupertinoIcons.minus,
                                  onTap: _zoomOut,
                                ),
                              ],
                            ),
                          ),

                          // Hint dưới
                          Positioned(
                            left: 16,
                            right: 16,
                            bottom: 14,
                            child: Align(
                              alignment: Alignment.bottomCenter,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(.35),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: const Text(
                                  'Chạm bất kỳ lên bản đồ để chọn vị trí kho mới',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/* ====================================================================
 *  MÀN 2: FORM TẠO KHO SAU KHI PING VỊ TRÍ
 * ====================================================================*/

class _WarehouseCreateFormPage extends StatefulWidget {
  final LatLng picked;

  const _WarehouseCreateFormPage({
    super.key,
    required this.picked,
  });

  @override
  State<_WarehouseCreateFormPage> createState() =>
      _WarehouseCreateFormPageState();
}

class _WarehouseCreateFormPageState extends State<_WarehouseCreateFormPage> {
  final _codeController = TextEditingController(text: 'NEW');
  final _nameController = TextEditingController(text: 'Kho mới...');
  final _addressController = TextEditingController(text: 'Địa chỉ...');
  final _keywordsController = TextEditingController(text: '');

  WarehouseKind _kind = WarehouseKind.main;
  bool _saving = false;

  @override
  void dispose() {
    _codeController.dispose();
    _nameController.dispose();
    _addressController.dispose();
    _keywordsController.dispose();
    super.dispose();
  }

  List<String> _keywordTokens() {
    final raw = _keywordsController.text.trim();
    if (raw.isEmpty) return [];
    return raw
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  Future<void> _saveToFirestoreAndClose() async {
    final code =
    _codeController.text.trim().isEmpty ? 'NEW' : _codeController.text.trim();
    final name = _nameController.text.trim().isEmpty
        ? 'Kho mới...'
        : _nameController.text.trim();
    final address = _addressController.text.trim().isEmpty
        ? 'Địa chỉ...'
        : _addressController.text.trim();
    final keywords = _keywordTokens();

    setState(() => _saving = true);
    try {
      await FirebaseFirestore.instance.collection('warehouses').add({
        'code': code,
        'name': name,
        'address': address,
        'lat': widget.picked.latitude,
        'lng': widget.picked.longitude,
        'kind': _kind == WarehouseKind.main ? 'main' : 'transit',
        'isMainHub': _kind == WarehouseKind.main,
        'keywords': keywords,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã lưu kho mới vào Firestore')),
      );
      Navigator.pop(context); // quay lại màn map
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi khi lưu kho: $e')),
      );
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bg = CupertinoColors.systemGroupedBackground.resolveFrom(context);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: cs.surface,
        foregroundColor: cs.onSurface,
        elevation: 0,
        title: Text(
          'Thêm kho',
          style: TextStyle(
            color: cs.primary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // SECTION 1: Vị trí & loại kho
                  _SectionCard(
                    title: 'VỊ TRÍ & LOẠI KHO',
                    children: [
                      _InfoRowTile(
                        icon: CupertinoIcons.location_solid,
                        label: 'Tọa độ đã chọn',
                        value:
                        '${widget.picked.latitude.toStringAsFixed(6)}, ${widget.picked.longitude.toStringAsFixed(6)}',
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Loại kho',
                        style: TextStyle(
                          fontSize: 12,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 6),
                      _TypeSegmented(
                        kind: _kind,
                        onChanged: (k) {
                          setState(() => _kind = k);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // SECTION 2: Thông tin kho
                  _SectionCard(
                    title: 'THÔNG TIN KHO',
                    children: [
                      _InputTile(
                        icon: CupertinoIcons.number,
                        hint: 'Mã kho (code)',
                        controller: _codeController,
                        helperText: 'VD: HCM_MAIN',
                      ),
                      const SizedBox(height: 10),
                      _InputTile(
                        icon: CupertinoIcons.cube_box_fill,
                        hint: 'Tên kho (name)',
                        controller: _nameController,
                        helperText: 'VD: Kho chính Đà Nẵng',
                      ),
                      const SizedBox(height: 10),
                      _InputTile(
                        icon: CupertinoIcons.building_2_fill,
                        hint: 'Địa chỉ (address)',
                        controller: _addressController,
                        helperText: 'VD: Quận Cẩm Lệ, TP. Đà Nẵng',
                      ),
                      const SizedBox(height: 10),
                      _InputTile(
                        icon: CupertinoIcons.tag,
                        hint: 'Keywords (phân tách bằng dấu phẩy)',
                        controller: _keywordsController,
                        helperText: 'VD: đà nẵng, DN_MAIN, kho chính',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Nút Lưu full width
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton(
                  onPressed: _saving ? null : _saveToFirestoreAndClose,
                  child: _saving
                      ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                      : const Text('Lưu kho'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/* ====================================================================
 *  WIDGET PHỤ CHO FORM
 * ====================================================================*/

class _SectionCard extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _SectionCard({
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 12,
            letterSpacing: 0.5,
            fontWeight: FontWeight.w600,
            color: cs.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: cs.outlineVariant.withOpacity(.5)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(.03),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: children,
          ),
        ),
      ],
    );
  }
}

class _InputTile extends StatelessWidget {
  final IconData icon;
  final String hint;
  final String? helperText;
  final TextEditingController controller;

  const _InputTile({
    required this.icon,
    required this.hint,
    required this.controller,
    this.helperText,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: cs.surfaceVariant.withOpacity(.35),
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            children: [
              Icon(icon, size: 18, color: cs.onSurfaceVariant),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: controller,
                  style: TextStyle(
                    color: cs.onSurface,
                    fontSize: 14,
                  ),
                  decoration: InputDecoration(
                    hintText: hint,
                    border: InputBorder.none,
                    isDense: true,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (helperText != null) ...[
          const SizedBox(height: 4),
          Text(
            helperText!,
            style: TextStyle(
              fontSize: 11,
              color: cs.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}

class _InfoRowTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRowTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceVariant.withOpacity(.35),
        borderRadius: BorderRadius.circular(14),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          Icon(icon, size: 18, color: cs.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: cs.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TypeSegmented extends StatelessWidget {
  final WarehouseKind kind;
  final ValueChanged<WarehouseKind> onChanged;

  const _TypeSegmented({
    required this.kind,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    Widget buildChip(WarehouseKind k, String label) {
      final selected = kind == k;
      return Expanded(
        child: GestureDetector(
          onTap: () => onChanged(k),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: selected
                  ? cs.primary.withOpacity(.12)
                  : cs.surfaceVariant.withOpacity(.3),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color:
                selected ? cs.primary : cs.outlineVariant.withOpacity(.5),
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: selected ? cs.primary : cs.onSurfaceVariant,
              ),
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        buildChip(WarehouseKind.main, 'Kho chính'),
        const SizedBox(width: 8),
        buildChip(WarehouseKind.transit, 'Kho trung chuyển'),
      ],
    );
  }
}

/* ====================================================================
 *  LEGEND + NÚT ZOOM CHO MAP
 * ====================================================================*/

class _MapLegendBar extends StatelessWidget {
  final bool showMain;
  final bool showTransit;
  final VoidCallback onToggleMain;
  final VoidCallback onToggleTransit;

  const _MapLegendBar({
    required this.showMain,
    required this.showTransit,
    required this.onToggleMain,
    required this.onToggleTransit,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    Widget buildChip({
      required bool selected,
      required VoidCallback onTap,
      required Widget avatar,
      required String label,
    }) {
      return GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: selected
                ? cs.primary.withOpacity(.16)
                : cs.surfaceVariant.withOpacity(.20),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected ? cs.primary : cs.outlineVariant.withOpacity(.5),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              avatar,
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: selected ? cs.primary : cs.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: cs.surface.withOpacity(.90),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(.12),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              buildChip(
                selected: showMain,
                onTap: onToggleMain,
                avatar: _LegendDot(
                  icon: CupertinoIcons.cube_box_fill,
                  color: cs.primary,
                ),
                label: 'Kho chính',
              ),
              const SizedBox(width: 8),
              buildChip(
                selected: showTransit,
                onTap: onToggleTransit,
                avatar: _LegendDot(
                  icon: CupertinoIcons.building_2_fill,
                  color: Colors.amber.shade800,
                ),
                label: 'Kho trung chuyển',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final IconData icon;
  final Color color;

  const _LegendDot({
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 10,
      backgroundColor: color.withOpacity(.12),
      child: Icon(
        icon,
        size: 14,
        color: color,
      ),
    );
  }
}

class _ZoomButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _ZoomButton({
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.surface.withOpacity(.96),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      elevation: 5,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(
            icon,
            size: 20,
            color: cs.onSurface,
          ),
        ),
      ),
    );
  }
}
