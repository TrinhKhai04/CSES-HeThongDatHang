// lib/views/admin/warehouse/warehouse_admin_page.dart
import 'dart:ui' as ui; // 👈 để dùng blur cho legend

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:latlong2/latlong.dart';

import '../widgets/admin_drawer.dart';
import 'warehouse_location_picker_page.dart'; // enum WarehouseKind + màn thêm kho


import 'package:intl/intl.dart';

import '../../../models/app_order.dart';
import '../../../routes/app_routes.dart';

/* ====================================================================
 *  MODEL + REPOSITORY
 * ====================================================================*/

class WarehouseDoc {
  final String id;
  final String code;
  final String name;
  final String address;
  final double lat;
  final double lng;
  final String kind; // 'main' hoặc 'transit'
  final List<String> keywords;
  final bool isActive; // true: đang hoạt động, false: tạm ngưng / đã đóng

  const WarehouseDoc({
    required this.id,
    required this.code,
    required this.name,
    required this.address,
    required this.lat,
    required this.lng,
    required this.kind,
    required this.keywords,
    required this.isActive,
  });

  factory WarehouseDoc.fromSnapshot(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    final lat = (data['lat'] as num?)?.toDouble() ?? 0;
    final lng = (data['lng'] as num?)?.toDouble() ?? 0;

    // Ưu tiên field 'kind', fallback từ isMainHub cũ
    final bool isMainHub = (data['isMainHub'] as bool?) ?? true;
    final String kind =
        (data['kind'] as String?) ?? (isMainHub ? 'main' : 'transit');

    // keywords
    List<String> keywords = [];
    final rawKeywords = data['keywords'];
    if (rawKeywords is Iterable) {
      keywords = rawKeywords.map((e) => e.toString()).toList();
    }

    // Ưu tiên field 'status', fallback từ isActive cũ
    final String? statusStr = data['status'] as String?;
    bool isActive;
    if (statusStr != null) {
      isActive = statusStr == 'active';
    } else {
      isActive = (data['isActive'] as bool?) ?? true;
    }

    return WarehouseDoc(
      id: doc.id,
      code: (data['code'] ?? '') as String,
      name: (data['name'] ?? '') as String,
      address: (data['address'] ?? '') as String,
      lat: lat,
      lng: lng,
      kind: kind,
      keywords: keywords,
      isActive: isActive,
    );
  }
}

class WarehouseRepository {
  const WarehouseRepository._();

  static const instance = WarehouseRepository._();

  CollectionReference<Map<String, dynamic>> get _col =>
      FirebaseFirestore.instance.collection('warehouses');

  Stream<List<WarehouseDoc>> watchAll() {
    return _col.snapshots().map(
          (snap) => snap.docs.map(WarehouseDoc.fromSnapshot).toList(),
    );
  }

  Future<void> update(WarehouseDoc w, Map<String, dynamic> data) {
    return _col.doc(w.id).update(data);
  }

  Future<void> delete(String id) {
    return _col.doc(id).delete();
  }
}

/// Helper: 3 kho “đầu não” để highlight
bool _isMegaHub(WarehouseDoc w) {
  const megaCodes = {'HCM_MAIN', 'HN_MAIN', 'DN_MAIN'};
  return megaCodes.contains(w.code.toUpperCase());
}

/* ====================================================================
 *  PAGE: KHO & HUB
 * ====================================================================*/

class WarehouseAdminPage extends StatefulWidget {
  const WarehouseAdminPage({super.key});

  @override
  State<WarehouseAdminPage> createState() => _WarehouseAdminPageState();
}

class _WarehouseAdminPageState extends State<WarehouseAdminPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final ValueNotifier<WarehouseDoc?> _flyToWarehouse =
  ValueNotifier<WarehouseDoc?>(null);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _flyToWarehouse.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Stream<List<WarehouseDoc>> _warehouseStream() {
    return WarehouseRepository.instance.watchAll();
  }

  int _sortByCode(WarehouseDoc a, WarehouseDoc b) =>
      a.code.toLowerCase().compareTo(b.code.toLowerCase());

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bg = CupertinoColors.systemGroupedBackground.resolveFrom(context);

    // TODO: nối với AuthController của bạn để check quyền thật sự
    const bool isAdmin = true;

    return Scaffold(
      backgroundColor: bg,
      drawer: const AdminDrawer(),
      appBar: AppBar(
        backgroundColor: cs.surface,
        foregroundColor: cs.onSurface,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'Kho & Hub',
          style: TextStyle(
            color: cs.primary,
            fontWeight: FontWeight.w700,
            fontSize: 20,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(54),
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
            color: cs.surface,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: cs.surfaceVariant.withOpacity(.35),
                borderRadius: BorderRadius.circular(999),
              ),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                  color: cs.surface,
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(.06),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                labelPadding: EdgeInsets.zero,
                indicatorSize: TabBarIndicatorSize.tab,
                labelStyle: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
                labelColor: cs.primary,
                unselectedLabelColor: cs.onSurfaceVariant,
                tabs: const [
                  Tab(text: 'Danh sách'),
                  Tab(text: 'Bản đồ'),
                ],
              ),
            ),
          ),
        ),
      ),
      body: StreamBuilder<List<WarehouseDoc>>(
        stream: _warehouseStream(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Lỗi khi tải danh sách kho'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CupertinoActivityIndicator());
          }

          final all = snapshot.data!;
          final main =
          all.where((w) => w.kind == 'main').toList()..sort(_sortByCode);
          final transit =
          all.where((w) => w.kind == 'transit').toList()..sort(_sortByCode);

          return TabBarView(
            controller: _tabController,
            children: [
              _WarehouseListTab(
                main: main,
                transit: transit,
                isAdmin: isAdmin,
                onSelectWarehouse: (w) {
                  _flyToWarehouse.value = w;
                  _tabController.animateTo(1);
                },
              ),
              _WarehouseMapTab(
                main: main,
                transit: transit,
                isAdmin: isAdmin,
                flyToWarehouseListenable: _flyToWarehouse,
              ),
            ],
          );
        },
      ),
    );
  }
}

/* ====================================================================
 *  TAB 1: DANH SÁCH + SEARCH + FILTER + COUNT + FAB
 * ====================================================================*/

enum _WarehouseFilter { all, main, transit }

class _WarehouseListTab extends StatefulWidget {
  final List<WarehouseDoc> main;
  final List<WarehouseDoc> transit;
  final bool isAdmin;
  final void Function(WarehouseDoc) onSelectWarehouse;

  const _WarehouseListTab({
    required this.main,
    required this.transit,
    required this.isAdmin,
    required this.onSelectWarehouse,
  });

  @override
  State<_WarehouseListTab> createState() => _WarehouseListTabState();
}

class _WarehouseListTabState extends State<_WarehouseListTab> {
  final _searchController = TextEditingController();
  _WarehouseFilter _filter = _WarehouseFilter.all;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _matchesQuery(WarehouseDoc w, String q) {
    if (q.isEmpty) return true;
    final text =
    '${w.code} ${w.name} ${w.address} ${w.keywords.join(' ')}'.toLowerCase();
    return text.contains(q);
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchController.text.trim().toLowerCase();

    List<WarehouseDoc> main = widget.main;
    List<WarehouseDoc> transit = widget.transit;

    // filter theo loại
    if (_filter == _WarehouseFilter.main) {
      transit = [];
    } else if (_filter == _WarehouseFilter.transit) {
      main = [];
    }

    // filter theo text
    main = main.where((w) => _matchesQuery(w, query)).toList();
    transit = transit.where((w) => _matchesQuery(w, query)).toList();

    final bool hasAnyData =
        widget.main.isNotEmpty || widget.transit.isNotEmpty;
    final bool hasResult = main.isNotEmpty || transit.isNotEmpty;
    final int totalVisible = main.length + transit.length;

    // header thống kê (tổng kho + số kho tạm ngưng)
    final int totalAll = widget.main.length + widget.transit.length;
    final int paused = widget.main.where((w) => !w.isActive).length +
        widget.transit.where((w) => !w.isActive).length;

    return Stack(
      children: [
        if (!hasAnyData)
          const Center(
            child: Text(
              'Chưa có kho nào.\nHãy bấm "Thêm kho" để tạo.',
              textAlign: TextAlign.center,
            ),
          )
        else
          Column(
            children: [
              // header thống kê nhỏ
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                child: Row(
                  children: [
                    Icon(
                      CupertinoIcons.cube_box,
                      size: 16,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '$totalAll kho ( $paused tạm ngưng )',
                      style: TextStyle(
                        fontSize: 12,
                        color:
                        Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),

              // search + filter card
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .surface
                        .withOpacity(.98),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(.04),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      CupertinoSearchTextField(
                        controller: _searchController,
                        placeholder: 'Tìm theo mã, tên, địa chỉ...',
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 8),
                      // ✅ Cuộn ngang filter chips để không bị tràn màn nhỏ
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _FilterChip(
                              label: 'Tất cả',
                              selected: _filter == _WarehouseFilter.all,
                              onTap: () => setState(
                                      () => _filter = _WarehouseFilter.all),
                            ),
                            const SizedBox(width: 8),
                            _FilterChip(
                              label: 'Kho chính',
                              selected: _filter == _WarehouseFilter.main,
                              onTap: () => setState(
                                      () => _filter = _WarehouseFilter.main),
                            ),
                            const SizedBox(width: 8),
                            _FilterChip(
                              label: 'Kho trung chuyển',
                              selected: _filter == _WarehouseFilter.transit,
                              onTap: () => setState(
                                      () => _filter = _WarehouseFilter.transit),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // dòng "Đang hiển thị X kho"
              if (hasResult)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Đang hiển thị $totalVisible kho',
                      style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurfaceVariant
                            .withOpacity(.8),
                      ),
                    ),
                  ),
                ),

              Expanded(
                child: !hasResult && query.isNotEmpty
                    ? const Center(
                  child: Text('Không tìm thấy kho phù hợp'),
                )
                    : ListView(
                  padding:
                  const EdgeInsets.fromLTRB(16, 4, 16, 96),
                  children: [
                    if (main.isNotEmpty) ...[
                      const _SectionHeader(
                        icon: CupertinoIcons.cube_box_fill,
                        title: 'Kho chính toàn quốc',
                      ),
                      _CardGroup(
                        children: [
                          for (final w in main)
                            _WarehouseTile(
                              icon: CupertinoIcons.cube_box_fill,
                              color: Theme.of(context)
                                  .colorScheme
                                  .primary,
                              title: '${w.code} — ${w.name}',
                              subtitle: w.address,
                              highlight: _isMegaHub(w),
                              isMain: true,
                              isActive: w.isActive,
                              onTap: () =>
                                  widget.onSelectWarehouse(w),
                              onEdit: widget.isAdmin
                                  ? () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        WarehouseEditPage(
                                            warehouse: w),
                                  ),
                                );
                              }
                                  : null,
                            ),
                        ],
                      ),
                      const SizedBox(height: 18),
                    ],
                    if (transit.isNotEmpty) ...[
                      const _SectionHeader(
                        icon: CupertinoIcons.building_2_fill,
                        title:
                        'Kho trung chuyển (tỉnh / khu vực)',
                      ),
                      _CardGroup(
                        children: [
                          for (final w in transit)
                            _WarehouseTile(
                              icon: CupertinoIcons.building_2_fill,
                              color: Colors.amber,
                              title: '${w.code} — ${w.name}',
                              subtitle: w.address,
                              highlight: _isMegaHub(w),
                              isMain: false,
                              isActive: w.isActive,
                              onTap: () =>
                                  widget.onSelectWarehouse(w),
                              onEdit: widget.isAdmin
                                  ? () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        WarehouseEditPage(
                                            warehouse: w),
                                  ),
                                );
                              }
                                  : null,
                            ),
                        ],
                      ),
                      const SizedBox(height: 24),
                    ],
                  ],
                ),
              ),
            ],
          ),

        // FAB Thêm kho (chỉ admin)
        if (widget.isAdmin)
          const Positioned(
            right: 16,
            bottom: 24,
            child: _AddWarehouseFab(heroTag: 'fab_add_warehouse_list'),
          ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding:
        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? cs.primary.withOpacity(.12)
              : cs.surfaceVariant.withOpacity(.25),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected
                ? cs.primary
                : cs.outlineVariant.withOpacity(.4),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected ? cs.primary : cs.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class _WarehouseTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final bool isMain;
  final bool highlight;
  final bool isActive;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;

  const _WarehouseTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.isMain,
    this.highlight = false,
    required this.isActive,
    this.onTap,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final statusColor = isActive ? Colors.green : Colors.redAccent;
    final statusText = isActive ? 'Đang hoạt động' : 'Tạm ngưng';
    final typeLabel = isMain ? 'Kho chính' : 'Kho trung chuyển';
    final typeColor = isMain ? cs.primary : Colors.amber.shade800;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Container(
          decoration: highlight
              ? BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                cs.primary.withOpacity(.05),
                cs.primary.withOpacity(.01),
              ],
            ),
          )
              : null,
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 6),
            leading: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: highlight
                    ? [
                  BoxShadow(
                    color: color.withOpacity(.45),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
                    : null,
              ),
              child: CircleAvatar(
                radius: highlight ? 22 : 20,
                backgroundColor: color.withOpacity(.08),
                child: Icon(icon, color: color, size: highlight ? 22 : 20),
              ),
            ),
            title: Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: cs.onSurface,
              ),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: cs.onSurfaceVariant,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 4),

                  // 🔧 ĐỔI Row -> Wrap ĐỂ KHÔNG BỊ TRÀN NGANG
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      // chip loại kho
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: typeColor.withOpacity(.12),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          typeLabel,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: typeColor,
                          ),
                        ),
                      ),
                      // chip trạng thái
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(.12),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: statusColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              statusText,
                              style: TextStyle(
                                fontSize: 11,
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            trailing: onEdit == null
                ? null
                : IconButton(
              icon: Icon(
                CupertinoIcons.pencil,
                size: 18,
                color: cs.onSurfaceVariant.withOpacity(.8),
              ),
              onPressed: onEdit,
            ),
          ),
        ),
      ),
    );
  }
}

class _CardGroup extends StatelessWidget {
  final List<Widget> children;

  const _CardGroup({required this.children});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: cs.outlineVariant.withOpacity(.5)),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.black.withOpacity(.25)
                : Colors.black.withOpacity(.06),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          for (int i = 0; i < children.length; i++) ...[
            if (i > 0)
              Divider(
                height: 1,
                indent: 16,
                endIndent: 16,
                color: cs.outlineVariant.withOpacity(.35),
              ),
            children[i],
          ],
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;

  const _SectionHeader({
    required this.title,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final gold = Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFFE9C46A)
        : const Color(0xFFB98B15);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: gold.withOpacity(.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: gold),
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              color: gold,
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }
}

/* ====================================================================
 *  TAB 2: BẢN ĐỒ — LEGEND + ZOOM + CLUSTER + FLY-TO + POLYGON VN
 * ====================================================================*/

class _WarehouseMapTab extends StatefulWidget {
  final List<WarehouseDoc> main;
  final List<WarehouseDoc> transit;
  final bool isAdmin;
  final ValueListenable<WarehouseDoc?> flyToWarehouseListenable;

  const _WarehouseMapTab({
    required this.main,
    required this.transit,
    required this.isAdmin,
    required this.flyToWarehouseListenable,
  });

  @override
  State<_WarehouseMapTab> createState() => _WarehouseMapTabState();
}

class _WarehouseMapTabState extends State<_WarehouseMapTab> {
  static const LatLng _vnCenter = LatLng(16.047199, 107.0);

  bool _showMain = true;
  bool _showTransit = true;

  final MapController _mapController = MapController();

  // Polygon vùng Việt Nam (khung gần đúng)
  final List<LatLng> _vnPolygon = [
    LatLng(23.3920, 102.1440), // Tây Bắc
    LatLng(23.3920, 109.4690), // Đông Bắc
    LatLng(8.1790, 109.4690), // Đông Nam
    LatLng(8.1790, 102.1440), // Tây Nam
  ];

  // Kho đang focus (chọn từ list hoặc tap marker)
  WarehouseDoc? _selected;

  void _zoomIn() {
    final currentZoom = _mapController.camera.zoom;
    final double newZoom = (currentZoom + 1).clamp(4.0, 12.0).toDouble();
    _mapController.move(_mapController.camera.center, newZoom);
  }

  void _zoomOut() {
    final currentZoom = _mapController.camera.zoom;
    final double newZoom = (currentZoom - 1).clamp(4.0, 12.0).toDouble();
    _mapController.move(_mapController.camera.center, newZoom);
  }

  void _resetView() {
    _mapController.move(_vnCenter, 5.8);
  }

  @override
  void initState() {
    super.initState();
    widget.flyToWarehouseListenable.addListener(_handleFlyTo);
  }

  @override
  void didUpdateWidget(covariant _WarehouseMapTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.flyToWarehouseListenable !=
        widget.flyToWarehouseListenable) {
      oldWidget.flyToWarehouseListenable.removeListener(_handleFlyTo);
      widget.flyToWarehouseListenable.addListener(_handleFlyTo);
    }
  }

  @override
  void dispose() {
    widget.flyToWarehouseListenable.removeListener(_handleFlyTo);
    super.dispose();
  }

  void _handleFlyTo() {
    final w = widget.flyToWarehouseListenable.value;
    if (w == null) return;

    setState(() {
      _selected = w; // đánh dấu kho đang focus
    });

    final center = LatLng(w.lat, w.lng);
    _mapController.move(center, 9.5);
    _showWarehouseSheet(w);
  }

  void _showWarehouseSheet(WarehouseDoc w) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _WarehousePreviewSheet(
        warehouse: w,
        isAdmin: widget.isAdmin,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    // Chỉ hiển thị kho đang hoạt động trên bản đồ
    final activeMain = widget.main.where((w) => w.isActive).toList();
    final activeTransit = widget.transit.where((w) => w.isActive).toList();

    final mainMarkers = _showMain
        ? activeMain.map((w) {
      final bool isSelected = _selected?.id == w.id;
      final bool highlightMega = _isMegaHub(w);
      final bool highlight = highlightMega || isSelected;
      final markerColor = cs.primary;
      return Marker(
        width: highlight ? 44 : 34,
        height: highlight ? 44 : 34,
        point: LatLng(w.lat, w.lng),
        child: GestureDetector(
          onTap: () {
            setState(() => _selected = w);
            _showWarehouseSheet(w);
          },
          child: _LegendDot(
            icon: CupertinoIcons.cube_box_fill,
            color: markerColor,
            highlight: highlight,
          ),
        ),
      );
    }).toList()
        : <Marker>[];

    final transitMarkers = _showTransit
        ? activeTransit.map((w) {
      final bool isSelected = _selected?.id == w.id;
      final bool highlightMega = _isMegaHub(w);
      final bool highlight = highlightMega || isSelected;
      final markerColor = Colors.amber.shade800;
      return Marker(
        width: highlight ? 40 : 30,
        height: highlight ? 40 : 30,
        point: LatLng(w.lat, w.lng),
        child: GestureDetector(
          onTap: () {
            setState(() => _selected = w);
            _showWarehouseSheet(w);
          },
          child: _LegendDot(
            icon: CupertinoIcons.building_2_fill,
            color: markerColor,
            highlight: highlight,
          ),
        ),
      );
    }).toList()
        : <Marker>[];

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Container(
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: cs.outlineVariant.withOpacity(.4)),
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
                options: const MapOptions(
                  initialCenter: _vnCenter,
                  initialZoom: 5.8,
                  minZoom: 4.0,
                  maxZoom: 12.0,
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                    'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                    subdomains: const ['a', 'b', 'c'],
                    userAgentPackageName: 'com.cses.store',
                  ),
                  // Polygon vùng Việt Nam
                  PolygonLayer(
                    polygons: [
                      Polygon(
                        points: _vnPolygon,
                        color: cs.primary.withOpacity(.03),
                        borderColor: cs.primary.withOpacity(.25),
                        borderStrokeWidth: 1.2,
                      ),
                    ],
                  ),

                  // 🌐 Cluster KHO CHÍNH (xanh)
                  if (_showMain && mainMarkers.isNotEmpty)
                    MarkerClusterLayerWidget(
                      options: MarkerClusterLayerOptions(
                        maxClusterRadius: 45,
                        size: const Size(44, 44),
                        alignment: Alignment.center,
                        padding: const EdgeInsets.all(32),
                        markers: mainMarkers,
                        builder: (context, markers) {
                          return Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  cs.primary,
                                  cs.primaryContainer,
                                ],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(.3),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Center(
                              child: Text(
                                markers.length.toString(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                  // 🟧 Cluster KHO TRUNG CHUYỂN (cam)
                  // 🟧 Cluster KHO TRUNG CHUYỂN (cam - nhẹ hơn)
                  if (_showTransit && transitMarkers.isNotEmpty)
                    MarkerClusterLayerWidget(
                      options: MarkerClusterLayerOptions(
                        maxClusterRadius: 40,
                        size: const Size(34, 34), // nhỏ hơn kho chính
                        alignment: Alignment.center,
                        padding: const EdgeInsets.all(32),
                        markers: transitMarkers,
                        builder: (context, markers) {
                          final amber = Colors.amber.shade800;
                          return Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: cs.surface.withOpacity(.98), // nền trắng / gần trắng
                              border: Border.all(
                                color: amber,
                                width: 2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(.15),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Center(
                              child: Text(
                                markers.length.toString(),
                                style: TextStyle(
                                  color: amber,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                ],
              ),

              // Legend
              Positioned(
                left: 16,
                right: 16,
                top: 14,
                child: _MapLegendBar(
                  showMain: _showMain,
                  showTransit: _showTransit,
                  mainCount: activeMain.length,
                  transitCount: activeTransit.length,
                  onToggleMain: () {
                    setState(() => _showMain = !_showMain);
                  },
                  onToggleTransit: () {
                    setState(() => _showTransit = !_showTransit);
                  },
                ),
              ),

              // Zoom + reset buttons
              Positioned(
                right: 16,
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

              // Hint / info pill dưới
              Positioned(
                left: 16,
                right: 16,
                bottom: 14,
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: _selected == null
                      ? Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(.35),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Text(
                      'Bản đồ chỉ xem, không chọn tọa độ tại đây',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white,
                      ),
                    ),
                  )
                      : GestureDetector(
                    onTap: () => _showWarehouseSheet(_selected!),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: cs.surface.withOpacity(.96),
                        borderRadius: BorderRadius.circular(999),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(.15),
                            blurRadius: 14,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _selected!.kind == 'main'
                                ? CupertinoIcons.cube_box_fill
                                : CupertinoIcons.building_2_fill,
                            size: 16,
                            color: cs.primary,
                          ),
                          const SizedBox(width: 8),
                          // ✅ Tên kho co giãn, tránh tràn ngang
                          Flexible(
                            child: Text(
                              _selected!.name,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '(${_selected!.code})',
                            style: TextStyle(
                              fontSize: 11,
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(
                            CupertinoIcons.chevron_up,
                            size: 14,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MapLegendBar extends StatelessWidget {
  final bool showMain;
  final bool showTransit;
  final int mainCount;
  final int transitCount;
  final VoidCallback onToggleMain;
  final VoidCallback onToggleTransit;

  const _MapLegendBar({
    required this.showMain,
    required this.showTransit,
    required this.mainCount,
    required this.transitCount,
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
      required int count,
    }) {
      return GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding:
          const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: selected
                ? cs.primary.withOpacity(.16)
                : cs.surfaceVariant.withOpacity(.20),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected
                  ? cs.primary
                  : cs.outlineVariant.withOpacity(.5),
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
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: selected ? cs.primary : cs.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: selected
                      ? cs.primary
                      : cs.outlineVariant.withOpacity(.7),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$count',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
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
          padding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
          // ✅ Nếu thiếu chỗ thì cho cuộn ngang, không bị overflow
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisSize: MainAxisSize.min,
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
                  count: mainCount,
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
                  count: transitCount,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final IconData icon;
  final Color color;
  final bool highlight;

  const _LegendDot({
    required this.icon,
    required this.color,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: highlight
          ? BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(.55),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      )
          : null,
      child: CircleAvatar(
        radius: highlight ? 12 : 10,
        backgroundColor: color.withOpacity(.12),
        child: Icon(
          icon,
          size: highlight ? 16 : 14,
          color: color,
        ),
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
      elevation: 6,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
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

/* ====================================================================
 *  BOTTOM SHEET PREVIEW KHI TAP MARKER
 * ====================================================================*/

class _WarehousePreviewSheet extends StatelessWidget {
  final WarehouseDoc warehouse;
  final bool isAdmin;

  const _WarehousePreviewSheet({
    required this.warehouse,
    required this.isAdmin,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isMain = warehouse.kind == 'main';

    final statusColor =
    warehouse.isActive ? Colors.green : Colors.redAccent;
    final statusText =
    warehouse.isActive ? 'Đang hoạt động' : 'Tạm ngưng';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            alignment: Alignment.center,
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: cs.outlineVariant,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor:
                (isMain ? cs.primary : Colors.amber)
                    .withOpacity(.12),
                child: Icon(
                  isMain
                      ? CupertinoIcons.cube_box_fill
                      : CupertinoIcons.building_2_fill,
                  color:
                  isMain ? cs.primary : Colors.amber.shade800,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      warehouse.name,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: cs.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      warehouse.code,
                      style: TextStyle(
                        fontSize: 12,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              // chip code
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: cs.primary.withOpacity(.08),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  warehouse.code,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: cs.primary,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              // chip loại kho
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color:
                  (isMain ? cs.primary : Colors.amber.shade800)
                      .withOpacity(.10),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  isMain ? 'Kho chính' : 'Kho trung chuyển',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color:
                    isMain ? cs.primary : Colors.amber.shade800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(
                CupertinoIcons.location_solid,
                size: 16,
                color: cs.primary,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  warehouse.address,
                  style: TextStyle(
                    fontSize: 13,
                    color: cs.onSurface,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: statusColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                statusText,
                style: TextStyle(
                  fontSize: 11,
                  color: cs.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${warehouse.lat.toStringAsFixed(6)}, ${warehouse.lng.toStringAsFixed(6)}',
            style: TextStyle(
              fontSize: 11,
              color: cs.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 14),
          if (isAdmin)
            Column(
              children: [
                // Nút xem luồng đơn
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => WarehouseOrderFlowsPage(
                            warehouse: warehouse,
                          ),
                        ),
                      );
                    },
                    child: const Text('Xem luồng đơn qua kho'),
                  ),
                ),
                const SizedBox(height: 8),
                // Nút chỉnh sửa kho
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              WarehouseEditPage(warehouse: warehouse),
                        ),
                      );
                    },
                    child: const Text('Chỉnh sửa kho'),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

//-----------------------------------------


enum _WarehouseFlowFilter {
  all,
  inbound,            // Đơn đến kho
  outboundToWarehouse,
  outboundToCustomer,
}

class WarehouseOrderFlowsPage extends StatefulWidget {
  final WarehouseDoc warehouse;

  const WarehouseOrderFlowsPage({super.key, required this.warehouse});

  @override
  State<WarehouseOrderFlowsPage> createState() =>
      _WarehouseOrderFlowsPageState();
}

class _WarehouseOrderFlowsPageState extends State<WarehouseOrderFlowsPage> {
  _WarehouseFlowFilter _filter = _WarehouseFlowFilter.all;

  Stream<List<AppOrder>> _ordersStream() {
    final col = FirebaseFirestore.instance.collection('orders');

    return col
        .orderBy('createdAt', descending: true)
        .limit(200)
        .snapshots()
        .map((snap) {
      final result = <AppOrder>[];
      for (final d in snap.docs) {
        try {
          result.add(AppOrder.fromDoc(d));
        } catch (e, st) {
          if (kDebugMode) {
            print('❌ Lỗi parse AppOrder ${d.id}: $e\n$st');
          }
        }
      }
      return result;
    });
  }



  List<_OrderLegView> _buildItems(List<AppOrder> orders) {
    final wh = widget.warehouse;
    final items = <_OrderLegView>[];

    // Helper: kiểm tra 1 điểm (label + lat/lng + code) có phải chính kho này không
    bool _pointMatchWarehouse({
      String? code,
      required String label,
      required double lat,
      required double lng,
    }) {
      final nameMatch =
          label.trim().toLowerCase() == wh.name.trim().toLowerCase();

      // Nếu sau này anh lưu đúng code kho trong fromCode/toCode thì vẫn hỗ trợ
      final codeMatch = code != null &&
          code.toString().trim().toUpperCase() == wh.code.toUpperCase();

      // So gần theo toạ độ (vì anh lưu lat/lng kho vào leg)
      const eps = 0.0001;
      final coordMatch =
          (lat - wh.lat).abs() < eps && (lng - wh.lng).abs() < eps;

      return nameMatch || codeMatch || coordMatch;
    }

    for (final order in orders) {
      final legs = order.legs ?? const <OrderRouteLeg>[];

      for (final leg in legs) {
        final fromHere = _pointMatchWarehouse(
          code: leg.fromCode,
          label: leg.fromLabel,
          lat: leg.fromLat,
          lng: leg.fromLng,
        );

        final toHere = _pointMatchWarehouse(
          code: leg.toCode,
          label: leg.toLabel,
          lat: leg.toLat,
          lng: leg.toLng,
        );

        // Nếu chặng này không liên quan tới kho hiện tại thì bỏ
        if (!fromHere && !toHere) continue;

        // Phân loại chặng
        final bool isInbound = toHere && !fromHere;
        final bool isOutboundToCus =
            fromHere && (leg.toCode == 'CUS' || leg.toWhCode == 'CUS');
        final bool isOutboundToWh =
            fromHere && !toHere && !isOutboundToCus; // đi kho khác

        // Lọc theo filter
        bool match = false;
        switch (_filter) {
          case _WarehouseFlowFilter.all:
            match = true;
            break;
          case _WarehouseFlowFilter.inbound:
            match = isInbound;
            break;
          case _WarehouseFlowFilter.outboundToWarehouse:
            match = isOutboundToWh;
            break;
          case _WarehouseFlowFilter.outboundToCustomer:
            match = isOutboundToCus;
            break;
        }

        if (!match) continue;

        items.add(
          _OrderLegView(
            order: order,
            leg: leg,
            isInbound: isInbound,
            isOutboundToCustomer: isOutboundToCus,
          ),
        );
      }
    }

    items.sort(
          (a, b) => b.order.createdAt.compareTo(a.order.createdAt),
    );
    return items;
  }


  String _filterLabel(_WarehouseFlowFilter f) {
    switch (f) {
      case _WarehouseFlowFilter.all:
        return 'Tất cả';
      case _WarehouseFlowFilter.inbound:
        return 'Đơn đến kho';
      case _WarehouseFlowFilter.outboundToWarehouse:
        return 'Đi tới kho khác';
      case _WarehouseFlowFilter.outboundToCustomer:
        return 'Giao khách từ kho';
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final wh = widget.warehouse;

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: cs.surface,
        foregroundColor: cs.onSurface,
        elevation: 0,
        title: Text(
          'Luồng đơn • ${wh.code}',
          style: TextStyle(
            color: cs.primary,
            fontWeight: FontWeight.w700,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(44),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                wh.name,
                style: TextStyle(
                  fontSize: 13,
                  color: cs.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ),
      ),
      body: StreamBuilder<List<AppOrder>>(
        stream: _ordersStream(),
        builder: (context, snap) {
          if (snap.hasError) {
            if (kDebugMode) {
              print('❌ WarehouseOrderFlowsPage stream error: ${snap.error}');
            }
            return Center(
              child: Text(
                'Lỗi khi tải đơn hàng:\n${snap.error}',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13),
              ),
            );
          }

          if (!snap.hasData) {
            return const Center(child: CupertinoActivityIndicator());
          }

          final items = _buildItems(snap.data!);

          return Column(
            children: [
              // filter chips
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _WarehouseFlowFilter.values.map((f) {
                      final selected = _filter == f;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: GestureDetector(
                          onTap: () => setState(() => _filter = f),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 160),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: selected
                                  ? cs.primary.withOpacity(.12)
                                  : cs.surfaceVariant.withOpacity(.25),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: selected
                                    ? cs.primary
                                    : cs.outlineVariant.withOpacity(.4),
                              ),
                            ),
                            child: Text(
                              _filterLabel(f),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: selected
                                    ? cs.primary
                                    : cs.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),

              if (items.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Có ${items.length} chặng đơn qua kho này',
                      style: TextStyle(
                        fontSize: 11,
                        color: cs.onSurfaceVariant.withOpacity(.85),
                      ),
                    ),
                  ),
                ),

              Expanded(
                child: items.isEmpty
                    ? const Center(
                  child: Text(
                    'Chưa có đơn nào đi qua kho này.\nHãy thử chọn filter khác hoặc tạo thêm đơn.',
                    textAlign: TextAlign.center,
                  ),
                )
                    : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final it = items[index];
                    return _OrderLegCard(view: it);
                  },
                ),
              ),
            ],
          );
        },
      ),

    );
  }
}

class _OrderLegView {
  final AppOrder order;
  final OrderRouteLeg leg;
  final bool isInbound;
  final bool isOutboundToCustomer;

  _OrderLegView({
    required this.order,
    required this.leg,
    required this.isInbound,
    required this.isOutboundToCustomer,
  });
}

class _OrderLegCard extends StatelessWidget {
  final _OrderLegView view;

  const _OrderLegCard({required this.view});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final order = view.order;
    final leg = view.leg;

    final df = DateFormat('dd/MM HH:mm');
    final created = df.format(order.createdAt.toDate());

    final String directionText;
    if (view.isInbound) {
      directionText = '${leg.fromLabel} → ${leg.toLabel} (đến kho)';
    } else if (view.isOutboundToCustomer) {
      directionText = '${leg.fromLabel} → Khách hàng';
    } else {
      directionText = '${leg.fromLabel} → ${leg.toLabel}';
    }

    String statusLabel;
    Color statusColor;
    switch (order.status) {
      case 'done':
      case 'completed':
      case 'delivered':
        statusLabel = 'Đã giao';
        statusColor = Colors.green;
        break;
      case 'shipping':
        statusLabel = 'Đang giao';
        statusColor = Colors.orange;
        break;
      case 'processing':
        statusLabel = 'Đang xử lý';
        statusColor = cs.primary;
        break;
      case 'cancelled':
        statusLabel = 'Đã huỷ';
        statusColor = cs.error;
        break;
      default:
        statusLabel = order.status;
        statusColor = cs.onSurfaceVariant;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Container(
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: cs.outlineVariant.withOpacity(.5)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () {
            Navigator.of(context).pushNamed(
              AppRoutes.orderRoute,
              arguments: order,
            );
          },
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Mã đơn + trạng thái + thời gian
                Row(
                  children: [
                    Text(
                      order.orderCode,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(.12),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        statusLabel,
                        style: TextStyle(
                          fontSize: 11,
                          color: statusColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      created,
                      style: TextStyle(
                        fontSize: 11,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                // Hướng chặng
                Text(
                  directionText,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface,
                  ),
                ),
                const SizedBox(height: 4),

                // Tóm tắt khách
                Text(
                  order.customerSummary,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: cs.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 6),

                // Km/phút của CHẶNG + nút xem map (tổng tuyến)
                Row(
                  children: [
                    Icon(
                      CupertinoIcons.location_north_line,
                      size: 14,
                      color: cs.primary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Chặng này: ${leg.distanceKm.toStringAsFixed(1)} km • '
                          '${leg.durationMin.toStringAsFixed(0)} phút',
                      style: TextStyle(
                        fontSize: 11,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      'Xem tuyến (tổng)',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: cs.primary,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      CupertinoIcons.chevron_right,
                      size: 14,
                      color: cs.primary,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}



/* ====================================================================
 *  FAB THÊM KHO
 * ====================================================================*/

class _AddWarehouseFab extends StatelessWidget {
  final Object heroTag;

  const _AddWarehouseFab({super.key, required this.heroTag});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return FloatingActionButton.extended(
      heroTag: heroTag,
      elevation: 4,
      backgroundColor: cs.primaryContainer,
      foregroundColor: cs.onPrimaryContainer,
      icon: const Icon(Icons.add_location_alt_rounded),
      label: const Text('Thêm kho'),
      onPressed: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const WarehouseLocationPickerPage(),
          ),
        );
      },
    );
  }
}

/* ====================================================================
 *  MÀN CHI TIẾT / SỬA / XOÁ KHO
 * ====================================================================*/

class WarehouseEditPage extends StatefulWidget {
  final WarehouseDoc warehouse;

  const WarehouseEditPage({super.key, required this.warehouse});

  @override
  State<WarehouseEditPage> createState() => _WarehouseEditPageState();
}

class _WarehouseEditPageState extends State<WarehouseEditPage> {
  late final TextEditingController _codeController;
  late final TextEditingController _nameController;
  late final TextEditingController _addressController;
  late final TextEditingController _keywordsController;

  late WarehouseKind _kind;
  late bool _isActive;

  bool _saving = false;
  bool _deleting = false;

  @override
  void initState() {
    super.initState();
    _codeController = TextEditingController(text: widget.warehouse.code);
    _nameController = TextEditingController(text: widget.warehouse.name);
    _addressController = TextEditingController(text: widget.warehouse.address);
    _keywordsController =
        TextEditingController(text: widget.warehouse.keywords.join(', '));

    _kind = widget.warehouse.kind == 'transit'
        ? WarehouseKind.transit
        : WarehouseKind.main;

    _isActive = widget.warehouse.isActive;
  }

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

  Future<void> _saveChanges() async {
    final code = _codeController.text.trim().isEmpty
        ? 'NEW'
        : _codeController.text.trim();
    final name = _nameController.text.trim().isEmpty
        ? 'Kho mới...'
        : _nameController.text.trim();
    final address = _addressController.text.trim().isEmpty
        ? 'Địa chỉ...'
        : _addressController.text.trim();
    final keywords = _keywordTokens();

    setState(() => _saving = true);
    try {
      await WarehouseRepository.instance.update(
        widget.warehouse,
        {
          'code': code,
          'name': name,
          'address': address,
          'kind': _kind == WarehouseKind.main ? 'main' : 'transit',
          'isMainHub': _kind == WarehouseKind.main,
          'isActive': _isActive,
          'status': _isActive ? 'active' : 'paused',
          'keywords': keywords,
          'updatedAt': FieldValue.serverTimestamp(),
        },
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã cập nhật kho')),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi khi cập nhật kho: $e')),
      );
      setState(() => _saving = false);
    }
  }

  Future<void> _deleteWarehouse() async {
    final cs = Theme.of(context).colorScheme;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Xoá kho?'),
          content: const Text(
              'Bạn có chắc chắn muốn xoá kho này? Hành động này không thể hoàn tác.'),
          actions: [
            TextButton(
              child: const Text('Huỷ'),
              onPressed: () => Navigator.pop(context, false),
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: cs.error),
              child: const Text('Xoá'),
              onPressed: () => Navigator.pop(context, true),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    setState(() => _deleting = true);
    try {
      await WarehouseRepository.instance.delete(widget.warehouse.id);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã xoá kho')),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi khi xoá kho: $e')),
      );
      setState(() => _deleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bg =
    CupertinoColors.systemGroupedBackground.resolveFrom(context);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: cs.surface,
        foregroundColor: cs.onSurface,
        elevation: 0,
        title: Text(
          'Chi tiết kho',
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
              padding:
              const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _EditSectionCard(
                    title: 'VỊ TRÍ & LOẠI KHO',
                    children: [
                      _EditInfoRowTile(
                        icon: CupertinoIcons.location_solid,
                        label: 'Toạ độ',
                        value:
                        '${widget.warehouse.lat.toStringAsFixed(6)}, ${widget.warehouse.lng.toStringAsFixed(6)}',
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
                      _EditTypeSegmented(
                        kind: _kind,
                        onChanged: (k) {
                          setState(() => _kind = k);
                        },
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: _isActive
                                  ? Colors.green
                                  : Colors.redAccent,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _isActive
                                  ? 'Kho đang hoạt động'
                                  : 'Kho đang tạm ngưng',
                              style: TextStyle(
                                fontSize: 13,
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                          ),
                          Switch.adaptive(
                            value: _isActive,
                            activeColor: Colors.green,
                            onChanged: (v) {
                              setState(() => _isActive = v);
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _EditSectionCard(
                    title: 'THÔNG TIN KHO',
                    children: [
                      _EditInputTile(
                        icon: CupertinoIcons.number,
                        hint: 'Mã kho (code)',
                        controller: _codeController,
                        helperText: 'VD: HCM_MAIN',
                      ),
                      const SizedBox(height: 10),
                      _EditInputTile(
                        icon: CupertinoIcons.cube_box_fill,
                        hint: 'Tên kho (name)',
                        controller: _nameController,
                        helperText: 'VD: Kho chính Hồ Chí Minh',
                      ),
                      const SizedBox(height: 10),
                      _EditInputTile(
                        icon: CupertinoIcons.building_2_fill,
                        hint: 'Địa chỉ (address)',
                        controller: _addressController,
                        helperText: 'VD: Quận Tân Bình, TP.HCM',
                      ),
                      const SizedBox(height: 10),
                      _EditInputTile(
                        icon: CupertinoIcons.tag,
                        hint: 'Keywords (phân tách bằng dấu phẩy)',
                        controller: _keywordsController,
                        helperText: 'VD: HCM, HCM_MAIN, kho chính',
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Center(
                    child: TextButton.icon(
                      onPressed:
                      _deleting ? null : _deleteWarehouse,
                      icon: _deleting
                          ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2),
                      )
                          : Icon(
                        CupertinoIcons.trash,
                        color: cs.error,
                        size: 18,
                      ),
                      label: Text(
                        'Xoá kho này',
                        style: TextStyle(
                          color: cs.error,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding:
              const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton(
                  onPressed: _saving ? null : _saveChanges,
                  child: _saving
                      ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2),
                  )
                      : const Text('Lưu thay đổi'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EditSectionCard extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _EditSectionCard({
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
          padding:
          const EdgeInsets.fromLTRB(12, 10, 12, 12),
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
                color: cs.outlineVariant.withOpacity(.5)),
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

class _EditInputTile extends StatelessWidget {
  final IconData icon;
  final String hint;
  final String? helperText;
  final TextEditingController controller;

  const _EditInputTile({
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
          padding: const EdgeInsets.symmetric(
              horizontal: 12, vertical: 6),
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
                  decoration: const InputDecoration(
                    hintText: '',
                    border: InputBorder.none,
                    isDense: true,
                  ).copyWith(hintText: hint),
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

class _EditInfoRowTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _EditInfoRowTile({
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
      padding: const EdgeInsets.symmetric(
          horizontal: 12, vertical: 10),
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

class _EditTypeSegmented extends StatelessWidget {
  final WarehouseKind kind;
  final ValueChanged<WarehouseKind> onChanged;

  const _EditTypeSegmented({
    required this.kind,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    Widget buildChip(WarehouseKind k, String label) {
      final bool selected = kind == k;
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
                color: selected
                    ? cs.primary
                    : cs.outlineVariant.withOpacity(.5),
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
