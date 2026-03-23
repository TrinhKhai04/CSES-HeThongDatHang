// lib/views/orders/order_route_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../config/warehouse_config.dart';
import '../../models/app_order.dart';
import '../../services/route_service.dart';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_polyline_algorithm/google_polyline_algorithm.dart'
as poly;

/// Cho phép mở phần vận chuyển khi trạng thái từ processing trở lên
bool openShippingByStatus(String s) {
  return s == 'processing' ||
      s == 'shipping' ||
      s == 'delivered' ||
      s == 'done' ||
      s == 'completed';
}

/// Kiểu bản đồ: thường / địa hình / vệ tinh
enum _MapStyle { standard, terrain, satellite }

/// Loại hub để đổi icon
enum _HubKind { main, province, pickup, other }

/// Hub point giữ thêm code / label để đoán loại icon
class _HubPoint {
  final LatLng point;
  final String code;
  final String label;

  const _HubPoint({
    required this.point,
    required this.code,
    required this.label,
  });
}

bool _looksSwappedLatLng(List<LatLng> pts) {
  if (pts.isEmpty) return false;

  // Khung VN (ước lượng)
  const vnLatMin = 8.0, vnLatMax = 24.5;
  const vnLngMin = 102.0, vnLngMax = 110.0;

  int okAsIs = 0;
  int okIfSwap = 0;

  final sampleCount = pts.length < 50 ? pts.length : 50;
  for (int i = 0; i < sampleCount; i++) {
    final p = pts[i];

    // Trường hợp toạ độ đang đúng (lat, lng)
    if (p.latitude >= vnLatMin &&
        p.latitude <= vnLatMax &&
        p.longitude >= vnLngMin &&
        p.longitude <= vnLngMax) {
      okAsIs++;
    }

    // Trường hợp nếu đổi chỗ (lng, lat) thì lại rơi vào VN
    final slat = p.longitude;
    final slng = p.latitude;
    if (slat >= vnLatMin &&
        slat <= vnLatMax &&
        slng >= vnLngMin &&
        slng <= vnLngMax) {
      okIfSwap++;
    }
  }

  // Nếu “đúng khi swap” nhiều hơn “đúng hiện tại” → coi như đang bị đảo
  return okIfSwap > okAsIs;
}

/// ───────────────────── 🗺️ Page: Bản đồ & tuyến đường + bottom sheet ─────────────────────
class OrderRoutePage extends StatefulWidget {
  final AppOrder order;
  final String? productImageUrl;

  const OrderRoutePage({
    super.key,
    required this.order,
    this.productImageUrl,
  });

  @override
  State<OrderRoutePage> createState() => _OrderRoutePageState();
}

class _OrderRoutePageState extends State<OrderRoutePage> {
  /// Controller điều khiển camera / zoom / move của flutter_map
  final _mapCtrl = MapController();

  /// Lưu trạng thái camera hiện tại
  LatLng? _lastCenter;
  double? _lastZoom;

  /// Style bản đồ hiện tại
  _MapStyle _mapStyle = _MapStyle.standard;

  /// Label hiển thị tên style cho user
  String _styleLabel = 'Bản đồ thường';

  /// Khi true: map sẽ tự động follow vị trí xe (truck)
  bool _followTruck = true;

  /// Đang đổi style map → hiện overlay
  bool _styleSwitching = false;

  // ===================== Route fetched from RouteService (ORS proxy/OSRM fallback) =====================
  List<LatLng> _routePoints = const <LatLng>[];
  bool _routeLoading = true;
  String? _routeErr;
  double? _routeKm;
  double? _routeMin;

  @override
  void initState() {
    super.initState();
    _ensureRouteFetched();
  }

  // ===== Helpers xử lý toạ độ =====

  /// Fix toạ độ bị nhân lên 1e6 (lưu micro-degree)
  LatLng _fixMicro(LatLng p) {
    var lat = p.latitude, lng = p.longitude;
    if (lat.abs() > 180) lat /= 1e6;
    if (lng.abs() > 360) lng /= 1e6;
    return LatLng(lat, lng);
  }

  /// Toạ độ hợp lệ (trong range lat/lng thế giới)
  bool _valid(LatLng p) =>
      p.latitude >= -90 &&
          p.latitude <= 90 &&
          p.longitude >= -180 &&
          p.longitude <= 180;

  /// Toạ độ nằm trong biên giới VN (lọc bậy bạ)
  bool _inVN(LatLng p) =>
      p.latitude >= 8.0 &&
          p.latitude <= 24.5 &&
          p.longitude >= 102.0 &&
          p.longitude <= 110.0;

  /// Đưa 1 điểm (vd: kho trung chuyển) dính sát vào tuyến đường planned
  LatLng _snapToPolyline(LatLng p, List<LatLng> polyline) {
    if (polyline.length < 2) return p;
    final dist = Distance();
    LatLng best = polyline.first;
    double bestD = double.infinity;

    for (final q in polyline) {
      final d = dist.distance(p, q); // mét
      if (d < bestD) {
        bestD = d;
        best = q;
      }
    }
    return best;
  }

  /// Tìm index điểm gần nhất trên polyline so với target
  int _nearestPointIndex(List<LatLng> polyline, LatLng target) {
    if (polyline.isEmpty) return 0;
    final dist = Distance();
    double best = double.infinity;
    int bestIdx = 0;
    for (int i = 0; i < polyline.length; i++) {
      final d = dist.distance(target, polyline[i]);
      if (d < best) {
        best = d;
        bestIdx = i;
      }
    }
    return bestIdx;
  }

  /// Tách route thành 2 đoạn: đã đi (done) & còn lại (todo)
  Map<String, List<LatLng>> _splitRouteByTruck(
      List<LatLng> route, LatLng truck) {
    if (route.length < 2) {
      return {
        'done': <LatLng>[],
        'todo': route,
      };
    }
    final idx = _nearestPointIndex(route, truck).clamp(0, route.length - 1);
    final done = route.sublist(0, idx + 1);
    final todo = route.sublist(idx);
    return {
      'done': done,
      'todo': todo,
    };
  }

  /// Decode polyline (Google/OSRM)
  List<LatLng> _decodePolylineFlexible(String str) {
    if (str.isEmpty) return <LatLng>[];

    try {
      final raw = poly.decodePolyline(str);
      final pts = raw
          .map((p) => LatLng(
        (p[0] as num).toDouble(),
        (p[1] as num).toDouble(),
      ))
          .toList();

      return pts;
    } catch (e) {
      debugPrint('⚠️ decodePolyline error: $e');
      return <LatLng>[];
    }
  }

  /// Lấy danh sách waypoint HUB từ legs (unique theo lat/lng)
  List<Map<String, double>> _buildWaypointsFromLegs(AppOrder o) {
    final legs = o.legs ?? const <OrderRouteLeg>[];
    if (legs.isEmpty) return const [];

    final wps = <Map<String, double>>[];
    final seen = <String>{};

    void addIfHub(String code, double lat, double lng) {
      final c = (code).toUpperCase();
      if (!c.contains('HUB')) return;

      final p = _fixMicro(LatLng(lat, lng));
      if (!_valid(p)) return;

      // Key unique
      final key = '${p.latitude.toStringAsFixed(6)},${p.longitude.toStringAsFixed(6)}';
      if (seen.contains(key)) return;
      seen.add(key);

      wps.add({'lat': p.latitude, 'lng': p.longitude});
    }

    for (final l in legs) {
      addIfHub(l.toCode ?? '', l.toLat, l.toLng);
      addIfHub(l.fromCode ?? '', l.fromLat, l.fromLng);
    }

    return wps;
  }

  Future<void> _ensureRouteFetched() async {
    try {
      setState(() {
        _routeLoading = true;
        _routeErr = null;
      });

      final o = widget.order;

      final wh = _fixMicro(
        LatLng(
          o.whLat ?? WarehouseConfig.pos.latitude,
          o.whLng ?? WarehouseConfig.pos.longitude,
        ),
      );

      final dest = _fixMicro(
        LatLng(
          o.toLat ?? 0,
          o.toLng ?? 0,
        ),
      );

      // Nếu dest chưa hợp lệ thì bỏ
      if (!_valid(wh) || !_valid(dest)) {
        setState(() {
          _routeLoading = false;
          _routeErr = 'Toạ độ kho/đích không hợp lệ';
        });
        return;
      }

      // Waypoints từ legs (HUB)
      final wps = _buildWaypointsFromLegs(o);

      final rr = await RouteService.fromToVia(
        fromLat: wh.latitude,
        fromLng: wh.longitude,
        toLat: dest.latitude,
        toLng: dest.longitude,
        waypoints: wps,
      );

      var pts = rr.points;
      pts = pts.map(_fixMicro).where(_valid).toList();

      if (pts.length >= 2 && _looksSwappedLatLng(pts)) {
        pts = pts
            .map((p) => LatLng(p.longitude, p.latitude))
            .map(_fixMicro)
            .where(_valid)
            .toList();
      }

      // lọc VN nếu đủ
      final vnPts = pts.where(_inVN).toList();
      if (vnPts.length >= 2) pts = vnPts;

      if (!mounted) return;

      if (pts.length >= 2) {
        setState(() {
          _routePoints = pts;
          _routeKm = rr.distanceKm;
          _routeMin = rr.durationMin;
          _routeLoading = false;
          _routeErr = null;
        });
      } else {
        setState(() {
          _routeLoading = false;
          _routeErr = 'Route trả về không đủ điểm để vẽ';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _routeLoading = false;
        _routeErr = e.toString();
      });
    }
  }

  /// Lấy tuyến đường dự kiến (planned)
  ///
  /// Ưu tiên:
  /// 0) _routePoints (từ RouteService)
  /// 1) routeCoords
  /// 2) routePolyline (decode)
  /// 3) legs (điểm thẳng)
  /// 4) wh → dest
  List<LatLng> _planned() {
    // 0) Nếu đã fetch được points từ ORS/OSRM → ưu tiên tuyệt đối
    if (_routePoints.length >= 2) {
      return _routePoints;
    }

    final o = widget.order;
    var pts = <LatLng>[];

    // 1) routeCoords
    final rc = o.routeCoords;
    if (rc != null && rc.isNotEmpty) {
      for (final m in rc) {
        final lat = m['lat'];
        final lng = m['lng'];
        if (lat == null || lng == null) continue;
        pts.add(LatLng(lat.toDouble(), lng.toDouble()));
      }
    }

    // 2) polyline
    final polyStr = (o.routePolyline ?? '').trim();
    if (pts.isEmpty && polyStr.isNotEmpty) {
      final decoded = _decodePolylineFlexible(polyStr);
      if (decoded.length >= 2) pts.addAll(decoded);
    }

    // 3) legs
    final legs = o.legs ?? const <OrderRouteLeg>[];
    if (pts.isEmpty && legs.isNotEmpty) {
      pts.add(LatLng(legs.first.fromLat, legs.first.fromLng));
      for (final l in legs) {
        pts.add(LatLng(l.toLat, l.toLng));
      }
    }

    // 4) fallback wh → dest
    if (pts.isEmpty) {
      final wh = LatLng(
        o.whLat ?? WarehouseConfig.pos.latitude,
        o.whLng ?? WarehouseConfig.pos.longitude,
      );
      final dest = LatLng(
        o.toLat ?? 0,
        o.toLng ?? 0,
      );
      pts..add(wh)..add(dest);
    }

    // normalize
    pts = pts.map(_fixMicro).where(_valid).toList();

    if (pts.length >= 2 && _looksSwappedLatLng(pts)) {
      pts = pts
          .map((p) => LatLng(p.longitude, p.latitude))
          .map(_fixMicro)
          .where(_valid)
          .toList();
    }

    final vnPts = pts.where(_inVN).toList();
    if (vnPts.length >= 2) pts = vnPts;

    // final fallback guarantee
    if (pts.length < 2) {
      final wh = _fixMicro(
        LatLng(
          o.whLat ?? WarehouseConfig.pos.latitude,
          o.whLng ?? WarehouseConfig.pos.longitude,
        ),
      );
      final dest = _fixMicro(
        LatLng(
          o.toLat ?? 0,
          o.toLng ?? 0,
        ),
      );
      pts = [wh, dest].where(_valid).toList();
    }

    return pts;
  }

  /// URL tile map theo style + theme (dark/light)
  String _tileUrl(bool isDark) {
    switch (_mapStyle) {
      case _MapStyle.standard:
        return isDark
            ? 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png'
            : 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png';
      case _MapStyle.terrain:
        return 'https://{s}.tile.opentopomap.org/{z}/{x}/{y}.png';
      case _MapStyle.satellite:
        return 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}';
    }
  }

  /// Subdomain tile server (OSM / OpenTopo dùng a,b,c)
  List<String> _tileSubdomains() {
    switch (_mapStyle) {
      case _MapStyle.standard:
      case _MapStyle.terrain:
        return const ['a', 'b', 'c'];
      case _MapStyle.satellite:
        return const [];
    }
  }

  /// Tên style để show lên UI
  String _styleName(_MapStyle s) {
    switch (s) {
      case _MapStyle.standard:
        return 'Bản đồ thường';
      case _MapStyle.terrain:
        return 'Bản đồ địa hình';
      case _MapStyle.satellite:
        return 'Ảnh vệ tinh';
    }
  }

  /// Chuyển style bản đồ tuần tự
  void _cycleMapStyle() {
    setState(() {
      final values = _MapStyle.values;
      _mapStyle = values[(_mapStyle.index + 1) % values.length];
      _styleLabel = _styleName(_mapStyle);
      _styleSwitching = true;
    });

    Future.delayed(const Duration(milliseconds: 900), () {
      if (!mounted) return;
      setState(() => _styleSwitching = false);
    });
  }

  /// Đoán loại hub dựa vào code + label
  _HubKind _detectHubKind(String code, String label) {
    final c = code.toUpperCase();
    final l = label.toLowerCase();

    if (l.contains('trung tâm') || l.contains('kho chính') || c.contains('MAIN')) {
      return _HubKind.main;
    }
    if (l.contains('kho tỉnh') || l.contains('chi nhánh') || c.contains('PROV')) {
      return _HubKind.province;
    }
    if (l.contains('điểm gom') ||
        l.contains('điểm tập kết') ||
        l.contains('hub') ||
        c.contains('HUB')) {
      return _HubKind.pickup;
    }
    return _HubKind.other;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    // Guard: nếu status chưa tới processing mà cũng chưa có tracks
    if (!openShippingByStatus(widget.order.status)) {
      final q = FirebaseFirestore.instance
          .collection('orders')
          .doc(widget.order.id)
          .collection('tracks')
          .limit(1);

      return FutureBuilder<QuerySnapshot<Map<String, dynamic>>>(
        future: q.get(),
        builder: (context, s) {
          final hasTrack = s.data?.docs.isNotEmpty ?? false;
          if (!hasTrack) {
            return Scaffold(
              appBar: AppBar(
                automaticallyImplyLeading: false,
                backgroundColor: cs.surface,
                elevation: 0,
                titleSpacing: 0,
                leading: IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                title: const Text(
                  'Tuyến đường giao hàng',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                foregroundColor: const Color(0xFF007AFF),
              ),
              body: Center(
                child: Text(
                  'Theo dõi sẽ mở khi đơn rời kho hoặc đang xử lý.',
                  style: TextStyle(color: cs.onSurfaceVariant),
                ),
              ),
            );
          }
          return _buildMap(cs);
        },
      );
    }

    return _buildMap(cs);
  }

  /// Xây giao diện chính gồm: map + control + bottom sheet
  Widget _buildMap(ColorScheme cs) {
    final planned = _planned();

    if (planned.length < 2) {
      return Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          backgroundColor: cs.surface,
          elevation: 0,
          titleSpacing: 0,
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: const Text(
            'Tuyến đường giao hàng',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          foregroundColor: const Color(0xFF007AFF),
        ),
        body: Center(
          child: Text(
            'Chưa đủ toạ độ để hiển thị bản đồ',
            style: TextStyle(color: cs.onSurfaceVariant),
          ),
        ),
      );
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    final status = widget.order.status;
    final isCompletedStatus =
        status == 'delivered' || status == 'done' || status == 'completed';

    // Bounds để fitCamera toàn tuyến
    final bounds = LatLngBounds.fromPoints(planned);

    // Thông tin quãng đường & thời gian (ETA) - ưu tiên route vừa fetch
    final showKm = (_routeKm ?? widget.order.routeDistanceKm ?? 0);
    final showMin = (_routeMin ?? widget.order.routeDurationMin ?? 0);

    final distance = showKm.toStringAsFixed(1);
    final mins = showMin.round();
    final timeStr = mins >= 60
        ? '${mins ~/ 60}g${(mins % 60).toString().padLeft(2, '0')}'
        : '${mins}p';

    // Điểm kho
    final wh = _fixMicro(
      LatLng(
        widget.order.whLat ?? WarehouseConfig.pos.latitude,
        widget.order.whLng ?? WarehouseConfig.pos.longitude,
      ),
    );

    // Điểm nhận
    final dest = _fixMicro(
      LatLng(
        widget.order.toLat ?? planned.last.latitude,
        widget.order.toLng ?? planned.last.longitude,
      ),
    );

    // Điểm kho trung chuyển (nếu có legs có HUB) – snap lên tuyến planned
    final hubPoints = <_HubPoint>[];
    final legs = widget.order.legs ?? const <OrderRouteLeg>[];
    for (final leg in legs) {
      final fromCode = (leg.fromCode ?? '').toUpperCase();
      final toCode = (leg.toCode ?? '').toUpperCase();

      final fromLabel = leg.fromLabel;
      final toLabel = leg.toLabel;

      final bool fromIsHub = fromCode.contains('HUB');
      final bool toIsHub = toCode.contains('HUB');

      if (toIsHub) {
        var p = _fixMicro(LatLng(leg.toLat, leg.toLng));
        if (_valid(p) && _inVN(p)) {
          p = _snapToPolyline(p, planned);
          hubPoints.add(_HubPoint(point: p, code: toCode, label: toLabel));
        }
      }

      if (fromIsHub) {
        var p = _fixMicro(LatLng(leg.fromLat, leg.fromLng));
        if (_valid(p) && _inVN(p)) {
          p = _snapToPolyline(p, planned);
          hubPoints.add(_HubPoint(point: p, code: fromCode, label: fromLabel));
        }
      }
    }

    // Stream vị trí thực tế (real-time track) của đơn
    final trackStream = FirebaseFirestore.instance
        .collection('orders')
        .doc(widget.order.id)
        .collection('tracks')
        .orderBy('ts')
        .snapshots();

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: cs.surface,
        elevation: 0,
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Tuyến đường giao hàng',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        foregroundColor: const Color(0xFF007AFF),
        actions: [
          // refresh route
          IconButton(
            tooltip: 'Tải lại tuyến đường',
            onPressed: _ensureRouteFetched,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Stack(
        children: [
          // MAP bo góc + bóng đổ (card nổi)
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      blurRadius: 22,
                      offset: const Offset(0, 12),
                      color: Colors.black.withOpacity(0.18),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: trackStream,
                    builder: (context, snap) {
                      // vệt đường đi thực tế
                      final trail = <LatLng>[];
                      if (snap.hasData) {
                        for (final d in snap.data!.docs) {
                          final lat = (d.data()['lat'] ?? 0).toDouble();
                          final lng = (d.data()['lng'] ?? 0).toDouble();
                          final p = _fixMicro(LatLng(lat, lng));
                          if (_valid(p) && _inVN(p)) trail.add(p);
                        }
                      }

                      final hasTrail = trail.isNotEmpty;
                      late LatLng truck;

                      if (status == 'shipping') {
                        if (hubPoints.isNotEmpty) {
                          truck = hubPoints.first.point;
                        } else if (hasTrail) {
                          truck = trail.last;
                        } else {
                          truck = planned[planned.length ~/ 2];
                        }
                      } else if (hasTrail) {
                        truck = trail.last;
                      } else {
                        truck = planned.first;
                      }

                      // Nếu đang follow → tự move camera theo vị trí xe
                      if (_followTruck &&
                          snap.connectionState == ConnectionState.active &&
                          hasTrail) {
                        Future.microtask(() {
                          final zoom = _lastZoom ?? 13.0;
                          _mapCtrl.move(truck, zoom);
                          _lastCenter = truck;
                          _lastZoom = zoom;
                        });
                      }

                      // Tách route done / todo
                      List<LatLng> doneRoute = const <LatLng>[];
                      List<LatLng> todoRoute = planned;

                      if (!isCompletedStatus) {
                        final splitted = _splitRouteByTruck(planned, truck);
                        doneRoute = splitted['done'] ?? const <LatLng>[];
                        todoRoute = splitted['todo'] ?? const <LatLng>[];
                      }

                      return Stack(
                        children: [
                          FlutterMap(
                            mapController: _mapCtrl,
                            options: MapOptions(
                              initialCameraFit: CameraFit.bounds(
                                bounds: bounds,
                                padding: const EdgeInsets.all(24),
                              ),
                              onPositionChanged: (pos, hasGesture) {
                                _lastCenter = pos.center;
                                _lastZoom = pos.zoom;

                                if (hasGesture && _followTruck) {
                                  setState(() => _followTruck = false);
                                }
                              },
                            ),
                            children: [
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 280),
                                switchInCurve: Curves.easeOut,
                                switchOutCurve: Curves.easeIn,
                                child: TileLayer(
                                  key: ValueKey('$_mapStyle-$isDark'),
                                  urlTemplate: _tileUrl(isDark),
                                  subdomains: _tileSubdomains(),
                                  userAgentPackageName: 'vn.cses.app',
                                  maxZoom: 19,
                                  retinaMode: true,
                                ),
                              ),

                              // Tuyến planned – base nhạt
                              PolylineLayer(
                                polylines: [
                                  Polyline(
                                    points: planned,
                                    strokeWidth: 8,
                                    color: Colors.black.withOpacity(0.13),
                                  ),
                                ],
                              ),

                              if (isCompletedStatus)
                                PolylineLayer(
                                  polylines: [
                                    Polyline(
                                      points: planned,
                                      strokeWidth: 5.5,
                                      color: cs.primary,
                                    ),
                                  ],
                                )
                              else ...[
                                if (doneRoute.length >= 2)
                                  PolylineLayer(
                                    polylines: [
                                      Polyline(
                                        points: doneRoute,
                                        strokeWidth: 5.5,
                                        color: cs.primary,
                                      ),
                                    ],
                                  ),
                                if (todoRoute.length >= 2)
                                  PolylineLayer(
                                    polylines: [
                                      Polyline(
                                        points: todoRoute,
                                        strokeWidth: 4,
                                        color: cs.primary.withOpacity(0.3),
                                      ),
                                    ],
                                  ),
                              ],

                              // Vệt đường đi thực tế (trail)
                              if (trail.length >= 2)
                                PolylineLayer(
                                  polylines: [
                                    Polyline(
                                      points: trail,
                                      strokeWidth: 5,
                                      color: Colors.redAccent,
                                    ),
                                  ],
                                ),

                              // Markers
                              MarkerLayer(
                                markers: [
                                  // kho
                                  Marker(
                                    point: wh,
                                    width: 36,
                                    height: 36,
                                    child: const DecoratedBox(
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        Icons.store_mall_directory_rounded,
                                        color: Colors.blue,
                                        size: 22,
                                      ),
                                    ),
                                  ),

                                  // hubs
                                  ...hubPoints.map(
                                        (hub) => Marker(
                                      point: hub.point,
                                      width: 36,
                                      height: 36,
                                      child: DecoratedBox(
                                        decoration: const BoxDecoration(
                                          color: Colors.white,
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                              () {
                                            final kind =
                                            _detectHubKind(hub.code, hub.label);
                                            switch (kind) {
                                              case _HubKind.main:
                                                return Icons.home_work_rounded;
                                              case _HubKind.province:
                                                return Icons.store_mall_directory_rounded;
                                              case _HubKind.pickup:
                                                return Icons.hub_rounded;
                                              case _HubKind.other:
                                                return Icons.warehouse_rounded;
                                            }
                                          }(),
                                          color: () {
                                            final kind =
                                            _detectHubKind(hub.code, hub.label);
                                            switch (kind) {
                                              case _HubKind.main:
                                                return Colors.deepPurple;
                                              case _HubKind.province:
                                                return Colors.orange;
                                              case _HubKind.pickup:
                                                return Colors.blueAccent;
                                              case _HubKind.other:
                                                return Colors.teal;
                                            }
                                          }(),
                                          size: 22,
                                        ),
                                      ),
                                    ),
                                  ),

                                  // dest
                                  Marker(
                                    point: dest,
                                    width: 36,
                                    height: 36,
                                    child: const DecoratedBox(
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        Icons.location_pin,
                                        color: Colors.redAccent,
                                        size: 22,
                                      ),
                                    ),
                                  ),

                                  // truck
                                  if (!isCompletedStatus)
                                    Marker(
                                      point: truck,
                                      width: 44,
                                      height: 44,
                                      child: TweenAnimationBuilder<double>(
                                        tween: Tween(begin: 0.0, end: 1.0),
                                        duration:
                                        const Duration(milliseconds: 900),
                                        curve: Curves.easeInOut,
                                        builder: (context, value, child) {
                                          final dy = -2 * ((value - 0.5).abs());
                                          return Transform.translate(
                                            offset: Offset(0, dy),
                                            child: child,
                                          );
                                        },
                                        child: const DecoratedBox(
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(
                                            Icons.local_shipping_rounded,
                                            color: Colors.green,
                                            size: 24,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),

                          // Overlay gradient
                          IgnorePointer(
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.white.withOpacity(0.03),
                                    cs.surface.withOpacity(0.02),
                                  ],
                                ),
                              ),
                            ),
                          ),

                          // Overlay đổi style
                          AnimatedOpacity(
                            opacity: _styleSwitching ? 1 : 0,
                            duration: const Duration(milliseconds: 220),
                            child: IgnorePointer(
                              ignoring: !_styleSwitching,
                              child: Align(
                                alignment: const Alignment(0, 0.7),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.78),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor: AlwaysStoppedAnimation<Color>(
                                            Colors.white,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Đang chuyển sang $_styleLabel…',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),

                          // Overlay trạng thái route fetch (loading/error) - nhỏ gọn
                          Positioned(
                            left: 16,
                            right: 16,
                            top: 14,
                            child: IgnorePointer(
                              ignoring: true,
                              child: AnimatedOpacity(
                                opacity: (_routeLoading || _routeErr != null) ? 1 : 0,
                                duration: const Duration(milliseconds: 220),
                                child: Align(
                                  alignment: Alignment.topCenter,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.55),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (_routeLoading)
                                          const SizedBox(
                                            width: 14,
                                            height: 14,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              valueColor: AlwaysStoppedAnimation<Color>(
                                                Colors.white,
                                              ),
                                            ),
                                          )
                                        else
                                          const Icon(
                                            Icons.warning_rounded,
                                            size: 16,
                                            color: Colors.amber,
                                          ),
                                        const SizedBox(width: 8),
                                        Flexible(
                                          child: Text(
                                            _routeLoading
                                                ? 'Đang tải tuyến đường…'
                                                : (_routeErr ?? ''),
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ),

          // Cụm nút control map
          Positioned(
            right: 24,
            top: 24,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  margin: const EdgeInsets.only(bottom: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.55),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    _styleLabel,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                _MapStyleToggle(
                  style: _mapStyle,
                  onTap: _cycleMapStyle,
                ),
                const SizedBox(height: 12),
                _MapControlButton(
                  icon: Icons.add,
                  onTap: () {
                    final center = _lastCenter ?? planned[planned.length ~/ 2];
                    final zoom = (_lastZoom ?? 13.0) + 1;
                    _mapCtrl.move(center, zoom);
                    _lastCenter = center;
                    _lastZoom = zoom;
                  },
                ),
                const SizedBox(height: 8),
                _MapControlButton(
                  icon: Icons.remove,
                  onTap: () {
                    final center = _lastCenter ?? planned[planned.length ~/ 2];
                    final zoom = (_lastZoom ?? 13.0) - 1;
                    _mapCtrl.move(center, zoom);
                    _lastCenter = center;
                    _lastZoom = zoom;
                  },
                ),
                const SizedBox(height: 8),
                _MapControlButton(
                  icon: Icons.my_location_rounded,
                  onTap: () {
                    _mapCtrl.fitCamera(
                      CameraFit.bounds(
                        bounds: bounds,
                        padding: const EdgeInsets.all(24),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 8),
                _MapControlButton(
                  icon: _followTruck
                      ? Icons.directions_bus_filled_rounded
                      : Icons.pan_tool_alt_rounded,
                  color: _followTruck ? Colors.green : cs.onSurface,
                  onTap: () {
                    setState(() => _followTruck = !_followTruck);
                    if (_followTruck) {
                      _mapCtrl.fitCamera(
                        CameraFit.bounds(
                          bounds: bounds,
                          padding: const EdgeInsets.all(24),
                        ),
                      );
                    }
                  },
                ),
              ],
            ),
          ),

          // Gradient mờ ở đáy
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 24,
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withOpacity(0.08),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Bottom sheet
          _BottomInfoSheet(
            order: widget.order,
            distanceKm: distance,
            etaText: timeStr,
            productImageUrl: widget.productImageUrl,
          ),
        ],
      ),
    );
  }
}

// ───────────────────── Bottom sheet + Progress + Timeline ─────────────────────

class _BottomInfoSheet extends StatelessWidget {
  final AppOrder order;
  final String distanceKm;
  final String etaText;
  final String? productImageUrl;

  const _BottomInfoSheet({
    required this.order,
    required this.distanceKm,
    required this.etaText,
    this.productImageUrl,
  });

  String _addr(AppOrder o) {
    final parts = <String>[];
    if ((o.toAddress ?? '').trim().isNotEmpty) parts.add(o.toAddress!.trim());
    if ((o.toWard ?? '').trim().isNotEmpty) parts.add(o.toWard!.trim());
    if ((o.toDistrict ?? '').trim().isNotEmpty) parts.add(o.toDistrict!.trim());
    if ((o.toProvince ?? '').trim().isNotEmpty) parts.add(o.toProvince!.trim());
    return parts.join(', ');
  }

  int _statusStep(String s) {
    switch (s) {
      case 'processing':
        return 1;
      case 'shipping':
        return 2;
      case 'delivered':
      case 'done':
      case 'completed':
        return 3;
      default:
        return 0;
    }
  }

  String _buildRouteSummary(AppOrder o) {
    final legs = o.legs ?? const <OrderRouteLeg>[];
    final labels = <String>[];

    if (legs.isNotEmpty) {
      final firstFrom = legs.first.fromLabel.trim();
      if (firstFrom.isNotEmpty) labels.add(firstFrom);

      for (final l in legs) {
        final to = l.toLabel.trim();
        if (to.isNotEmpty && (labels.isEmpty || labels.last != to)) {
          labels.add(to);
        }
      }
    } else {
      final from = (o.whName ?? '').trim();
      if (from.isNotEmpty) labels.add(from);
      labels.add('Khách hàng');
    }

    return labels.join(' → ');
  }

  void _showEventDetailBottomSheet(
      BuildContext context,
      String title,
      String subtitle,
      String time,
      ) {
    final cs = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      isScrollControlled: false,
      backgroundColor: cs.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 46,
                  height: 4,
                  decoration: BoxDecoration(
                    color: cs.outlineVariant,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                title,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              if (subtitle.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: cs.onSurfaceVariant,
                    fontSize: 14,
                  ),
                ),
              ],
              if (time.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.access_time, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      time,
                      style: TextStyle(
                        fontSize: 13,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final step = _statusStep(order.status);
    final isCompleted = step == 3;

    final fullAddr = _addr(order);
    final routeSummary = _buildRouteSummary(order);

    final eventsStream = FirebaseFirestore.instance
        .collection('orders')
        .doc(order.id)
        .collection('events')
        .orderBy('ts', descending: true)
        .snapshots();

    final methodName = (order.shippingMethodName ?? '').trim();
    final subtitleParts = <String>[
      '#${order.id.substring(0, 6).toUpperCase()}',
    ];
    if (methodName.isNotEmpty) subtitleParts.add(methodName);
    final subtitle = subtitleParts.join(' • ');

    return SafeArea(
      top: false,
      bottom: false,
      child: DraggableScrollableSheet(
        initialChildSize: 0.45,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        snap: true,
        snapSizes: const [0.3, 0.6, 0.9],
        builder: (context, scrollController) {
          return Container(
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              boxShadow: const [
                BoxShadow(
                  blurRadius: 24,
                  offset: Offset(0, -10),
                  color: Color(0x33000000),
                ),
              ],
            ),
            clipBehavior: Clip.hardEdge,
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: eventsStream,
              builder: (context, snap) {
                final tiles = <Widget>[];

                if (snap.hasData && snap.data!.docs.isNotEmpty) {
                  final legsForEvents = order.legs ?? const <OrderRouteLeg>[];
                  final OrderRouteLeg? firstLegForEvents =
                  legsForEvents.isNotEmpty ? legsForEvents.first : null;
                  final OrderRouteLeg? lastLegForEvents =
                  legsForEvents.isNotEmpty ? legsForEvents.last : null;

                  final docs = snap.data!.docs;

                  for (var i = 0; i < docs.length; i++) {
                    final d = docs[i];
                    final m = d.data();
                    final ts = (m['ts'] as Timestamp?)?.toDate();
                    final timeStr = ts != null
                        ? DateFormat('dd/MM HH:mm').format(ts)
                        : '';

                    final rawTitle = (m['title'] ?? 'Cập nhật trạng thái') as String;
                    final loc = (m['location'] ?? '') as String;
                    final note = (m['note'] ?? '') as String;

                    String title = rawTitle;
                    String subtitleText;

                    if (loc.trim().isNotEmpty || note.trim().isNotEmpty) {
                      subtitleText = [loc, note]
                          .where((s) => s.trim().isNotEmpty)
                          .join(' · ');
                    } else {
                      final addr = fullAddr;
                      final name = (order.toName ?? '').trim();
                      final phone = (order.toPhone ?? '').trim();
                      final lower = rawTitle.toLowerCase();

                      final fromLeg0 =
                      (firstLegForEvents?.fromLabel ?? '').trim();
                      final toLeg0 = (firstLegForEvents?.toLabel ?? '').trim();
                      final fromLast =
                      (lastLegForEvents?.fromLabel ?? '').trim();
                      final toLast = (lastLegForEvents?.toLabel ?? '').trim();

                      if (lower.contains('giao') && lower.contains('thành công')) {
                        title = 'Giao hàng thành công';
                        subtitleText = [
                          if (name.isNotEmpty) name,
                          if (phone.isNotEmpty) phone,
                          if (addr.isNotEmpty) addr,
                        ].join(' • ');
                      } else if (lower.contains('đang giao') ||
                          lower.contains('dang giao')) {
                        title = 'Đang giao hàng';
                        if (fromLast.isNotEmpty && toLast.isNotEmpty) {
                          subtitleText = 'Từ $fromLast → $toLast';
                        } else {
                          subtitleText = addr.isNotEmpty
                              ? 'Đang giao đến: $addr'
                              : 'Đơn vị vận chuyển đang giao đến địa chỉ nhận';
                        }
                      } else if (lower.contains('rời kho') ||
                          lower.contains('roi kho')) {
                        title = 'Đã rời kho';
                        if (fromLeg0.isNotEmpty && toLeg0.isNotEmpty) {
                          subtitleText = 'Từ $fromLeg0 → $toLeg0';
                        } else {
                          final wh = (order.whName ?? '').trim();
                          subtitleText =
                          wh.isNotEmpty ? 'Rời kho: $wh' : 'Kho xử lý đơn hàng';
                        }
                      } else {
                        subtitleText = '';
                      }
                    }

                    tiles.add(
                      _EventTile(
                        title: title,
                        subtitle: subtitleText,
                        time: timeStr,
                        isCurrent: i == 0,
                        isFirst: i == 0,
                        isLast: i == docs.length - 1,
                        onTap: () => _showEventDetailBottomSheet(
                          context,
                          title,
                          subtitleText,
                          timeStr,
                        ),
                      ),
                    );
                  }
                } else {
                  String fmtTs(String key) {
                    final t = order.statusTs?[key];
                    if (t == null) return '';
                    return DateFormat('dd/MM HH:mm').format(t.toDate());
                  }

                  final addr = fullAddr;
                  final legs = order.legs ?? const <OrderRouteLeg>[];

                  final createdTime = fmtTs('created');
                  final processingTime = fmtTs('processing');
                  final shippingTime = fmtTs('shipping');
                  final deliveredTime = fmtTs('delivered').isNotEmpty
                      ? fmtTs('delivered')
                      : (fmtTs('done').isNotEmpty
                      ? fmtTs('done')
                      : fmtTs('completed'));

                  final eventsFallback = <Map<String, String>>[];

                  eventsFallback.add({
                    'title': 'Đơn hàng đã được đặt',
                    'subtitle': '',
                    'time': createdTime,
                  });

                  eventsFallback.add({
                    'title': 'Người gửi đang chuẩn bị hàng',
                    'subtitle': '',
                    'time': processingTime.isNotEmpty ? processingTime : createdTime,
                  });

                  eventsFallback.add({
                    'title': 'Đơn vị vận chuyển đã nhận hàng từ người gửi',
                    'subtitle': '',
                    'time': processingTime,
                  });

                  for (var i = 0; i < legs.length; i++) {
                    final l = legs[i];
                    final fromLabel = l.fromLabel.trim();
                    final toLabel = l.toLabel.trim();
                    if (fromLabel.isEmpty && toLabel.isEmpty) continue;

                    final isLastLeg = i == legs.length - 1;
                    final legTime =
                    processingTime.isNotEmpty ? processingTime : createdTime;

                    if (fromLabel.isNotEmpty) {
                      eventsFallback.add({
                        'title': 'Đơn hàng đã rời $fromLabel',
                        'subtitle': toLabel.isNotEmpty ? 'Đi đến: $toLabel' : '',
                        'time': legTime,
                      });
                    }

                    if (!isLastLeg && toLabel.isNotEmpty) {
                      eventsFallback.add({
                        'title': 'Đơn hàng đã đến $toLabel',
                        'subtitle': '',
                        'time': legTime,
                      });
                    }
                  }

                  eventsFallback.add({
                    'title': 'Đơn hàng đang được giao đến địa chỉ nhận',
                    'subtitle': addr.isNotEmpty
                        ? 'Đang giao đến: $addr'
                        : 'Đơn vị vận chuyển đang giao đến địa chỉ nhận',
                    'time': shippingTime,
                  });

                  eventsFallback.add({
                    'title': 'Giao hàng thành công',
                    'subtitle': [
                      if ((order.toName ?? '').trim().isNotEmpty) order.toName!.trim(),
                      if ((order.toPhone ?? '').trim().isNotEmpty) order.toPhone!.trim(),
                      if (addr.isNotEmpty) addr,
                    ].join(' • '),
                    'time': deliveredTime,
                  });

                  final ordered = eventsFallback.reversed.toList();

                  for (var i = 0; i < ordered.length; i++) {
                    final e = ordered[i];
                    final title = e['title'] ?? '';
                    final sub = e['subtitle'] ?? '';
                    final time = e['time'] ?? '';

                    tiles.add(
                      _EventTile(
                        title: title,
                        subtitle: sub,
                        time: time,
                        isCurrent: i == 0,
                        isFirst: i == 0,
                        isLast: i == ordered.length - 1,
                        onTap: () => _showEventDetailBottomSheet(
                          context,
                          title,
                          sub,
                          time,
                        ),
                      ),
                    );
                  }
                }

                return ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                  children: [
                    Center(
                      child: Container(
                        width: 48,
                        height: 5,
                        decoration: BoxDecoration(
                          color: cs.outlineVariant,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),

                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _RouteStatusChip(status: order.status),
                              if (subtitle.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    subtitle,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: cs.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        _pill(cs, Icons.route, '$distanceKm km'),
                        const SizedBox(width: 8),
                        _pill(cs, Icons.timer_outlined, etaText),
                      ],
                    ),
                    const SizedBox(height: 10),

                    _ProgressDots(
                      labels: const [
                        'Đã vận chuyển',
                        'Đang giao hàng',
                        'Đã giao hàng',
                      ],
                      active: step.clamp(0, 3),
                      isCompleted: isCompleted,
                    ),
                    const SizedBox(height: 8),

                    _OrderInfoInRouteSheet(
                      order: order,
                      productImageUrl: productImageUrl,
                    ),
                    const SizedBox(height: 12),

                    if (routeSummary.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.alt_route_rounded,
                              size: 18,
                              color: cs.onSurfaceVariant,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Lộ trình: $routeSummary',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: cs.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    ...tiles,
                  ],
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _pill(ColorScheme cs, IconData icon, String text) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: cs.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: cs.outlineVariant),
    ),
    child: Row(
      children: [
        Icon(icon, size: 16, color: cs.onSurfaceVariant),
        const SizedBox(width: 6),
        Text(text, style: TextStyle(color: cs.onSurface)),
      ],
    ),
  );
}

/// Thanh progress 3 chấm + label
class _ProgressDots extends StatelessWidget {
  final List<String> labels;
  final int active;
  final bool isCompleted;

  const _ProgressDots({
    required this.labels,
    required this.active,
    this.isCompleted = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final filledFactor = ((active - 1) / 2).clamp(0.0, 1.0);
    final filledColor = cs.primary;

    return Column(
      children: [
        SizedBox(
          height: 28,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned.fill(
                left: 16,
                right: 16,
                child: Center(
                  child: Container(height: 3, color: cs.outlineVariant),
                ),
              ),
              Positioned.fill(
                left: 16,
                right: 16,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    widthFactor: filledFactor,
                    child: Container(height: 3, color: filledColor),
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(3, (i) {
                  final on = i < active;
                  final dotColor = on ? filledColor : cs.surface;
                  final borderColor = on ? filledColor : cs.outlineVariant;

                  return Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      color: dotColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: borderColor, width: 2),
                    ),
                  );
                }),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: labels.map((t) {
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  t,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _OrderInfoInRouteSheet extends StatelessWidget {
  final AppOrder order;
  final String? productImageUrl;

  const _OrderInfoInRouteSheet({
    required this.order,
    this.productImageUrl,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final parts = <String>[];
    if ((order.toAddress ?? '').trim().isNotEmpty) parts.add(order.toAddress!.trim());
    if ((order.toWard ?? '').trim().isNotEmpty) parts.add(order.toWard!.trim());
    if ((order.toDistrict ?? '').trim().isNotEmpty) parts.add(order.toDistrict!.trim());
    if ((order.toProvince ?? '').trim().isNotEmpty) parts.add(order.toProvince!.trim());
    final addr = parts.join(', ');

    final shortId = '#${order.id.substring(0, 6).toUpperCase()}';
    final name = (order.toName ?? 'Đơn hàng').trim();
    final phone = (order.toPhone ?? '').trim();
    final imgUrl = productImageUrl ?? '';
    final methodName = (order.shippingMethodName ?? '').trim();

    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            blurRadius: 20,
            offset: const Offset(0, 10),
            color: Colors.black.withOpacity(0.16),
          ),
        ],
        border: Border.all(
          color: cs.outlineVariant.withOpacity(0.4),
          width: 0.6,
        ),
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: cs.primaryContainer,
              borderRadius: BorderRadius.circular(10),
            ),
            child: imgUrl.isNotEmpty
                ? ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.network(
                imgUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Icon(
                  Icons.local_shipping_rounded,
                  size: 22,
                  color: cs.onPrimaryContainer,
                ),
              ),
            )
                : Icon(
              Icons.local_shipping_rounded,
              size: 22,
              color: cs.onPrimaryContainer,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$shortId • $phone',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                ),
                if (addr.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    addr,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                  ),
                ],
                if (methodName.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Phương thức: $methodName',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Thông tin đơn hàng'),
          ),
        ],
      ),
    );
  }
}

class _EventTile extends StatelessWidget {
  final String title, subtitle, time;
  final bool isCurrent, isFirst, isLast;
  final VoidCallback? onTap;

  const _EventTile({
    required this.title,
    required this.subtitle,
    required this.time,
    required this.isCurrent,
    required this.isFirst,
    required this.isLast,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 90,
              child: Text(
                time,
                style: TextStyle(
                  fontSize: 11,
                  color: isCurrent ? cs.onSurface : cs.onSurfaceVariant,
                  fontWeight: isCurrent ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
            SizedBox(
              width: 26,
              child: Column(
                children: [
                  if (!isFirst) Container(height: 10, width: 2, color: cs.outlineVariant),
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: isCurrent ? Colors.green : cs.surface,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: isCurrent ? Colors.green : cs.outlineVariant,
                        width: 2,
                      ),
                    ),
                  ),
                  if (!isLast) Container(height: 40, width: 2, color: cs.outlineVariant),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
                      color: isCurrent ? Colors.green : cs.onSurface,
                    ),
                  ),
                  if (subtitle.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        subtitle,
                        style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RouteStatusChip extends StatelessWidget {
  final String status;

  const _RouteStatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    String label;
    Color bg;
    Color fg;

    switch (status) {
      case 'pending':
      case 'created':
        label = 'Chờ xác nhận';
        bg = cs.surfaceContainerHighest;
        fg = cs.onSurfaceVariant;
        break;
      case 'processing':
        label = 'Đã vận chuyển';
        bg = const Color(0xFFE3F2FD);
        fg = const Color(0xFF1565C0);
        break;
      case 'shipping':
        label = 'Đang giao hàng';
        bg = const Color(0xFFE8F5E9);
        fg = const Color(0xFF2E7D32);
        break;
      default:
        label = 'Đã giao';
        bg = const Color(0xFFE8F5E9);
        fg = const Color(0xFF1B5E20);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: fg,
        ),
      ),
    );
  }
}

class _MapControlButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color? color;

  const _MapControlButton({
    required this.icon,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      elevation: 6,
      color: cs.surface,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(9),
          child: Icon(icon, size: 18, color: color ?? cs.onSurface),
        ),
      ),
    );
  }
}

class _MapStyleToggle extends StatelessWidget {
  final _MapStyle style;
  final VoidCallback onTap;

  const _MapStyleToggle({
    required this.style,
    required this.onTap,
  });

  IconData _icon() {
    switch (style) {
      case _MapStyle.standard:
        return Icons.map_rounded;
      case _MapStyle.terrain:
        return Icons.terrain_rounded;
      case _MapStyle.satellite:
        return Icons.satellite_alt_rounded;
    }
  }

  String _tooltip() {
    switch (style) {
      case _MapStyle.standard:
        return 'Đổi sang bản đồ địa hình';
      case _MapStyle.terrain:
        return 'Đổi sang ảnh vệ tinh';
      case _MapStyle.satellite:
        return 'Đổi sang bản đồ thường';
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Tooltip(
      message: _tooltip(),
      child: Material(
        elevation: 8,
        color: cs.surface,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(9),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              transitionBuilder: (child, anim) {
                return RotationTransition(
                  turns: Tween<double>(begin: 0.8, end: 1.0).animate(anim),
                  child: FadeTransition(opacity: anim, child: child),
                );
              },
              child: Icon(
                _icon(),
                key: ValueKey(style),
                size: 18,
                color: cs.primary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
