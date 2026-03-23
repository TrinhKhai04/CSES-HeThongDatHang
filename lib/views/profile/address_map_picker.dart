// lib/views/profile/address_map_picker.dart
// -----------------------------------------------------------------------------
// Address Map Picker (FREE) — OpenStreetMap + Nominatim + GPS (Apple-Style)
// -----------------------------------------------------------------------------

import 'dart:async';
import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map/flutter_map.dart'
    show RichAttributionWidget, TextSourceAttribution;
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

/// Kết quả trả về cho form địa chỉ
class AddressPickResult {
  final double lat, lng;
  final String street; // Số nhà + đường
  final String ward; // Phường/Xã
  final String district; // Quận/Huyện/TP thuộc tỉnh (VD: TP Thủ Đức)
  final String province; // Tỉnh/TP trực thuộc TW (VD: TP Hồ Chí Minh)
  final String full; // display_name

  AddressPickResult({
    required this.lat,
    required this.lng,
    required this.street,
    required this.ward,
    required this.district,
    required this.province,
    required this.full,
  });
}

/// Kiểu map
enum _MapStyle { standard, satellite, terrain }

/// Màn chọn địa chỉ kiểu Apple Store
class AddressMapPicker extends StatefulWidget {
  final LatLng? initial; // toạ độ mở đầu (mặc định Q1, HCM)
  const AddressMapPicker({super.key, this.initial});

  @override
  State<AddressMapPicker> createState() => _AddressMapPickerState();
}

class _AddressMapPickerState extends State<AddressMapPicker> {
  // ------------------------ Config ------------------------
  static const _ua = 'CSES-AddressPicker/1.0 (contact: your-email@domain.com)';
  static const _searchLimit = 8;
  static const _debounceMs = 350;
  static const _httpTimeout = Duration(seconds: 10);
  // Viewbox Việt Nam: lonW,latN,lonE,latS
  static const _vnViewbox = '102.144,23.393,109.469,8.179';

  // Tâm mặc định (Q1, HCM)
  LatLng _center = const LatLng(10.776889, 106.700806);

  // State/UI
  final _mapCtl = MapController();
  final _searchCtl = TextEditingController();
  final _focusNode = FocusNode();

  LatLng? _picked; // luôn = tâm map hiện tại
  List<Map<String, dynamic>> _suggestions = [];
  Timer? _debounce;
  bool _locating = false;
  Timer? _moveEndThrottle;

  // 🔎 Preview địa chỉ dưới dạng card
  AddressPickResult? _preview;
  bool _loadingPreview = false;
  Timer? _previewDebounce;

  // Kiểu map hiện tại
  _MapStyle _mapStyle = _MapStyle.standard;

  @override
  void initState() {
    super.initState();
    if (widget.initial != null) _center = widget.initial!;
    _picked = _center; // auto chọn theo tâm ngay khi mở

    // Lấy preview lần đầu sau khi build xong
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _schedulePreviewUpdate(_center);
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _moveEndThrottle?.cancel();
    _previewDebounce?.cancel();
    _searchCtl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  // -------------------- Helpers VN -----------------------
  bool _isTW(String name) {
    final n = name.toLowerCase();
    return n.contains('hồ chí minh') ||
        n.contains('hà nội') ||
        n.contains('đà nẵng') ||
        n.contains('hải phòng') ||
        n.contains('cần thơ');
  }

  String _shortenDistrict(String d) {
    if (d.startsWith('Thành phố Thủ Đức')) return 'TP Thủ Đức';
    return d;
  }

  String _normalizeWard(String w) {
    var s = w.trim();
    // P.7 / P7 → Phường 7
    s = s.replaceAllMapped(
      RegExp(r'^\s*P\.?\s*(\d+)\s*$', caseSensitive: false),
          (m) => 'Phường ${m.group(1)}',
    );
    // P / Ph / Phường → Phường
    s = s.replaceAllMapped(
      RegExp(r'^\s*P(hường)?\s*', caseSensitive: false),
          (_) => 'Phường ',
    );
    // Xa. / Xa → Xã
    s = s.replaceAllMapped(
      RegExp(r'^\s*Xa?\.?\s*', caseSensitive: false),
          (_) => 'Xã ',
    );
    return s.replaceAll(RegExp(r'\s{2,}'), ' ').trim();
  }

  String _guessDistrictFromDisplay(String display) {
    final reg = RegExp(
      r'(Quận\s+[^\.,;]+|Huyện\s+[^\.,;]+|Thị\s*xã\s+[^\.,;]+|Thành\s*phố\s+[^\.,;]+)',
      caseSensitive: false,
    );
    return reg.firstMatch(display)?.group(0)?.trim() ?? '';
  }

  String _guessWardFromDisplay(String display) {
    final reg = RegExp(
      r'(Phường\s*\d+|Phường\s+[^\.,;]+|Xã\s+[^\.,;]+|Thị\s*trấn\s+[^\.,;]+|Khu\s*phố\s*\d+|Ấp\s*\d+)',
      caseSensitive: false,
    );
    return reg.firstMatch(display)?.group(0)?.trim() ?? '';
  }

  // -------------------- HTTP helpers --------------------
  Future<http.Response> _safeGet(Uri uri) async {
    Future<http.Response> go() =>
        http.get(uri, headers: {'User-Agent': _ua}).timeout(_httpTimeout);

    var res = await go();
    if (res.statusCode == 429 || res.statusCode == 503) {
      await Future.delayed(const Duration(seconds: 1));
      res = await go();
    }
    return res;
  }

  // -------------------- Nominatim: Search ----------------
  Future<List<Map<String, dynamic>>> _search(String q) async {
    if (q.trim().isEmpty) return [];
    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/search'
            '?format=jsonv2'
            '&q=${Uri.encodeQueryComponent(q)}'
            '&countrycodes=vn'
            '&accept-language=vi'
            '&addressdetails=1'
            '&bounded=1'
            '&viewbox=$_vnViewbox'
            '&limit=$_searchLimit',
      );
      final res = await _safeGet(uri);
      if (res.statusCode != 200) return [];
      final list = jsonDecode(res.body) as List;
      return list.cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  // ------------------- Nominatim: Reverse ----------------
  Future<AddressPickResult?> _reverse(LatLng p) async {
    // Caller nhỏ để đổi zoom linh hoạt
    Future<Map<String, dynamic>?> _callReverse({int zoom = 18}) async {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse'
            '?format=jsonv2&lat=${p.latitude}&lon=${p.longitude}'
            '&accept-language=vi&addressdetails=1&zoom=$zoom',
      );
      final res = await _safeGet(uri);
      if (res.statusCode != 200) return null;
      return jsonDecode(res.body) as Map<String, dynamic>;
    }

    Map<String, dynamic>? data = await _callReverse(zoom: 18);
    if (data == null) return null;
    Map<String, dynamic> addr =
    (data['address'] ?? {}) as Map<String, dynamic>;

    // pick key đầu có giá trị
    String pick(List<String> keys) {
      for (final k in keys) {
        final v = addr[k];
        if (v != null && v.toString().trim().isNotEmpty) return v.toString();
      }
      return '';
    }

    final houseNo = pick(['house_number']);
    final road = pick(['road', 'residential', 'pedestrian', 'footway']);
    final street =
    [houseNo, road].where((e) => e.isNotEmpty).join(' ').trim();

    String ward = pick([
      'ward',
      'suburb',
      'quarter',
      'neighbourhood',
      'city_subdivision',
      'locality',
      'borough',
      'village',
      'town',
      'hamlet',
    ]);

    String state = pick(['state', 'province', 'region']);
    String city = pick(['city', 'municipality']);
    String district =
    pick(['city_district', 'district', 'state_district', 'county']);

    String province = state.isNotEmpty ? state : (_isTW(city) ? city : '');

    // TP trực thuộc TW: nếu district rỗng nhưng có city → dùng city
    if (district.isEmpty &&
        province.isNotEmpty &&
        _isTW(province) &&
        city.isNotEmpty) {
      district = city;
    }

    // Fallback theo các mức zoom 16 → 14 → 12
    Future<void> rescue(int zoom) async {
      final dataZ = await _callReverse(zoom: zoom);
      if (dataZ == null) return;
      final a2 = (dataZ['address'] ?? {}) as Map<String, dynamic>;
      String pick2(List<String> keys) {
        for (final k in keys) {
          final v = a2[k];
          if (v != null && v.toString().trim().isNotEmpty) return v.toString();
        }
        return '';
      }

      district = district.isEmpty
          ? pick2(['city_district', 'district', 'state_district', 'county'])
          : district;
      if (province.isEmpty) {
        province = pick2(['state', 'province', 'region', 'city']);
      }
      if (ward.isEmpty) {
        ward = pick2([
          'ward',
          'suburb',
          'quarter',
          'neighbourhood',
          'city_subdivision',
          'locality',
          'borough',
          'village',
          'town',
          'hamlet',
        ]);
      }
    }

    if (district.isEmpty || ward.isEmpty) {
      await rescue(16);
      if (district.isEmpty || ward.isEmpty) await rescue(14);
      if (district.isEmpty || ward.isEmpty) await rescue(12);
    }

    // Fallback regex từ display_name
    final display = (data['display_name'] ?? '').toString();
    if (district.isEmpty) district = _guessDistrictFromDisplay(display);
    if (ward.isEmpty) ward = _guessWardFromDisplay(display);

    // 🔁 Fallback cuối cho district/province
    if (district.isEmpty && city.isNotEmpty && !_isTW(city)) {
      district = city;
    }

    if (district.isEmpty) {
      district =
          pick(['city_district', 'district', 'county', 'town', 'municipality']);
    }

    if (province.isEmpty) {
      province = pick(['state', 'city', 'province', 'region']);
    }

    ward = _normalizeWard(ward);
    district = _shortenDistrict(district);

    return AddressPickResult(
      lat: p.latitude,
      lng: p.longitude,
      street: street.isNotEmpty ? street : display,
      ward: ward,
      district: district,
      province: province,
      full: display,
    );
  }

  // -------------------------- GPS -------------------------
  Future<void> _goToMyLocation() async {
    try {
      setState(() => _locating = true);

      // 1) Dịch vụ vị trí
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (!mounted) return;
        setState(() => _locating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vui lòng bật dịch vụ vị trí (GPS).')),
        );
        return;
      }

      // 2) Quyền
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied) {
        if (!mounted) return;
        setState(() => _locating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bạn đã từ chối quyền vị trí.')),
        );
        return;
      }
      if (permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        setState(() => _locating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Quyền vị trí bị từ chối vĩnh viễn. Vào Cài đặt để cấp quyền.',
            ),
          ),
        );
        return;
      }

      // 3) Vị trí hiện tại
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 0,
        ),
      ).timeout(const Duration(seconds: 10));

      final here = LatLng(pos.latitude, pos.longitude);

      // 4) Cập nhật map
      _mapCtl.move(here, 17);
      if (mounted) {
        setState(() => _picked = here);
        _schedulePreviewUpdate(here);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã đến vị trí hiện tại.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không lấy được vị trí: $e')),
      );
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  // ----------------------- ZOOM HANDLERS ------------------------
  void _zoomIn() {
    final cam = _mapCtl.camera;
    final target = (cam.zoom + 1).clamp(4.0, 19.0);
    _mapCtl.move(cam.center, target.toDouble());
  }

  void _zoomOut() {
    final cam = _mapCtl.camera;
    final target = (cam.zoom - 1).clamp(4.0, 19.0);
    _mapCtl.move(cam.center, target.toDouble());
  }

  // --------------------- MAP STYLE TOGGLE -----------------------
  void _toggleMapStyle() {
    setState(() {
      // Standard → Satellite → Terrain → Standard
      if (_mapStyle == _MapStyle.standard) {
        _mapStyle = _MapStyle.satellite;
      } else if (_mapStyle == _MapStyle.satellite) {
        _mapStyle = _MapStyle.terrain;
      } else {
        _mapStyle = _MapStyle.standard;
      }
    });

    final text = switch (_mapStyle) {
      _MapStyle.standard => 'Đã chuyển sang kiểu bản đồ.',
      _MapStyle.satellite => 'Đã chuyển sang kiểu vệ tinh.',
      _MapStyle.terrain => 'Đã chuyển sang kiểu địa hình.',
    };
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text)),
    );
  }

  // ------------------------ UI handlers -------------------
  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: _debounceMs),
          () async {
        final items = await _search(value);
        if (!mounted) return;
        setState(() => _suggestions = items);
      },
    );
  }

  Future<void> _goToSuggestion(Map<String, dynamic> s) async {
    setState(() => _suggestions = []);
    _focusNode.unfocus();

    _searchCtl.text = s['display_name'] ?? (s['name'] ?? '');
    final lat = double.tryParse('${s['lat']}') ?? _center.latitude;
    final lon = double.tryParse('${s['lon']}') ?? _center.longitude;
    final pos = LatLng(lat, lon);

    _mapCtl.move(pos, 17);
    setState(() {
      _picked = pos;
    });
    _schedulePreviewUpdate(pos);
  }

  Future<void> _confirm() async {
    HapticFeedback.lightImpact(); // feel iOS
    final pos = _picked ?? _mapCtl.camera.center;
    final info = await _reverse(pos);
    if (!mounted) return;

    if (info == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Không lấy được địa chỉ, vui lòng thử lại.'),
        ),
      );
      return;
    }

    if (info.ward.trim().isEmpty || info.district.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Không tự nhận đủ Phường/Xã hoặc Quận/Huyện — bạn hãy kiểm tra và nhập tay ở form.',
          ),
        ),
      );
    }

    Navigator.pop(context, info);
  }

  // ----------------------- PREVIEW ADDRESS -----------------------
  void _schedulePreviewUpdate(LatLng center) {
    _previewDebounce?.cancel();
    _previewDebounce = Timer(
      const Duration(milliseconds: 700),
          () => _loadPreview(center),
    );
  }

  Future<void> _loadPreview(LatLng p) async {
    setState(() {
      _loadingPreview = true;
    });

    final info = await _reverse(p);
    if (!mounted) return;

    setState(() {
      _preview = info;
      _loadingPreview = false;
    });
  }

  // ----------------------------- UI ------------------------------
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final radius16 = BorderRadius.circular(14);

    final bottomInset = MediaQuery.of(context).padding.bottom;
    const kButtonHeight = 46.0;

    // Text phụ cho card theo trạng thái
    final String subtitleText;
    if (_loadingPreview) {
      subtitleText = 'Đang lấy địa chỉ cho vị trí này…';
    } else if (_preview != null) {
      subtitleText = [
        _preview!.ward,
        _preview!.district,
        _preview!.province,
      ].where((e) => e.trim().isNotEmpty).join(', ');
    } else {
      subtitleText =
      'Kéo bản đồ hoặc tìm kiếm, địa chỉ sẽ hiển thị tại đây.';
    }

    return Scaffold(
      backgroundColor: cs.surfaceContainerLowest,
      appBar: AppBar(
        backgroundColor: cs.surfaceContainerLowest,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, size: 18, color: cs.onSurface),
          onPressed: () => Navigator.pop(context),
          tooltip: 'Quay lại',
        ),
        title: Text(
          'Chọn trên bản đồ',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: cs.primary,
            fontSize: 18,
            letterSpacing: .2,
          ),
        ),
        actions: [
          TextButton(
            onPressed: _confirm,
            child: Text(
              'XONG',
              style: TextStyle(color: cs.primary, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          // 🗺️ Map bo góc + shadow nhẹ
          Padding(
            padding: EdgeInsets.fromLTRB(12, 8, 12, 190 + bottomInset),
            child: DecoratedBox(
              decoration: const BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    blurRadius: 18,
                    color: Color(0x1A000000),
                    offset: Offset(0, 10),
                  )
                ],
              ),
              child: ClipRRect(
                borderRadius: radius16,
                child: FlutterMap(
                  mapController: _mapCtl,
                  options: MapOptions(
                    initialCenter: _center,
                    initialZoom: 14,
                    onMapEvent: (event) {
                      if (event is MapEventMoveEnd ||
                          event is MapEventFlingAnimationEnd ||
                          event is MapEventDoubleTapZoomEnd) {
                        _moveEndThrottle?.cancel();
                        _moveEndThrottle =
                            Timer(const Duration(milliseconds: 80), () {
                              if (mounted) {
                                final center = _mapCtl.camera.center;
                                setState(() => _picked = center);
                                _schedulePreviewUpdate(center);
                              }
                            });
                      }
                    },
                  ),
                  children: [
                    // Tile theo kiểu map hiện tại
                    if (_mapStyle == _MapStyle.standard)
                      TileLayer(
                        urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'vn.cses.app',
                      )
                    else if (_mapStyle == _MapStyle.satellite)
                      TileLayer(
                        // Esri World Imagery (vệ tinh)
                        urlTemplate:
                        'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
                        userAgentPackageName: 'vn.cses.app',
                      )
                    else
                      TileLayer(
                        // OpenTopoMap – địa hình
                        urlTemplate:
                        'https://{s}.tile.opentopomap.org/{z}/{x}/{y}.png',
                        subdomains: const ['a', 'b', 'c'],
                        userAgentPackageName: 'vn.cses.app',
                      ),

                    // ✅ Attribution cho từng kiểu map
                    RichAttributionWidget(
                      attributions: [
                        if (_mapStyle == _MapStyle.standard)
                          const TextSourceAttribution(
                            '© OpenStreetMap contributors',
                          )
                        else if (_mapStyle == _MapStyle.satellite)
                          const TextSourceAttribution(
                            'Tiles © Esri — Source: Esri, Maxar, Earthstar Geographics',
                          )
                        else
                          const TextSourceAttribution(
                            '© OpenStreetMap contributors, SRTM | Map style: © OpenTopoMap (CC-BY-SA)',
                          ),
                      ],
                      alignment: AttributionAlignment.bottomLeft,
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 📍 Crosshair
          IgnorePointer(
            ignoring: true,
            child: Center(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: cs.surface.withOpacity(.98),
                  shape: BoxShape.circle,
                  boxShadow: const [
                    BoxShadow(
                      blurRadius: 12,
                      color: Color(0x33000000),
                      offset: Offset(0, 6),
                    )
                  ],
                ),
                child: const Padding(
                  padding: EdgeInsets.all(6),
                  child: Icon(
                    Icons.place_rounded,
                    size: 26,
                    color: Color(0xFF007AFF),
                  ),
                ),
              ),
            ),
          ),

          // 🔎 Search pill
          Positioned(
            left: 20,
            right: 20,
            top: 8,
            child: DecoratedBox(
              decoration: const BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    blurRadius: 12,
                    color: Color(0x14000000),
                    offset: Offset(0, 6),
                  )
                ],
              ),
              child: Material(
                color: cs.surface,
                borderRadius: BorderRadius.circular(28),
                child: Padding(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: CupertinoSearchTextField(
                    controller: _searchCtl,
                    focusNode: _focusNode,
                    onChanged: _onSearchChanged,
                    placeholder: 'Tìm địa điểm, tòa nhà… (Việt Nam)',
                  ),
                ),
              ),
            ),
          ),

          // 🔍 NÚT PHÓNG TO / THU NHỎ + GPS Ở GÓC TRÊN BÊN TRÁI
          Positioned(
            left: 20,
            top: 76,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _ZoomButton(
                  icon: Icons.add,
                  tooltip: 'Phóng to',
                  onTap: _zoomIn,
                ),
                const SizedBox(height: 8),
                _ZoomButton(
                  icon: Icons.remove,
                  tooltip: 'Thu nhỏ',
                  onTap: _zoomOut,
                ),
                const SizedBox(height: 12),
                _ZoomButton(
                  icon: _locating ? Icons.more_horiz : Icons.my_location,
                  tooltip: 'Vị trí hiện tại',
                  onTap: () {
                    if (_locating) return;
                    _goToMyLocation();
                  },
                ),
              ],
            ),
          ),

          // 🌐 NÚT KIỂU MAP Ở GÓC PHẢI
          Positioned(
            right: 20,
            top: 76,
            child: _ZoomButton(
              icon: switch (_mapStyle) {
                _MapStyle.standard => Icons.layers_outlined,
                _MapStyle.satellite => Icons.satellite_alt_outlined,
                _MapStyle.terrain => Icons.terrain_outlined,
              },
              tooltip: 'Đổi kiểu bản đồ',
              onTap: _toggleMapStyle,
            ),
          ),

          // 🔽 Gợi ý autocomplete
          if (_suggestions.isNotEmpty)
            Positioned(
              left: 20,
              right: 20,
              top: 60,
              child: Material(
                color: cs.surface,
                borderRadius: BorderRadius.circular(16),
                elevation: 6,
                shadowColor: Colors.black12,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 280),
                  child: ListView.separated(
                    shrinkWrap: true,
                    padding: EdgeInsets.zero,
                    itemCount: _suggestions.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final s = _suggestions[i];
                      final name = (s['display_name'] ??
                          s['name'] ??
                          'Kết quả không tên')
                          .toString();
                      return ListTile(
                        dense: true,
                        title: Text(
                          name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: const Icon(
                          Icons.arrow_forward_ios,
                          size: 14,
                          color: Colors.black26,
                        ),
                        onTap: () => _goToSuggestion(s),
                      );
                    },
                  ),
                ),
              ),
            ),

          // 📍 Card dưới: preview + nút confirm (Material style) + chip + copy
          Positioned(
            left: 16,
            right: 16,
            bottom: 0,
            child: SafeArea(
              top: false,
              minimum: const EdgeInsets.only(bottom: 10),
              child: Material(
                color: cs.surface,
                elevation: 14,
                shadowColor: const Color(0x26000000),
                borderRadius: BorderRadius.circular(18),
                child: Padding(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Hàng chip + nút sao chép
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: cs.primary.withOpacity(.08),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              'Địa chỉ giao hàng',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: cs.primary,
                              ),
                            ),
                          ),
                          const Spacer(),
                          if (_preview != null)
                            InkWell(
                              borderRadius: BorderRadius.circular(999),
                              onTap: () async {
                                await Clipboard.setData(
                                  ClipboardData(text: _preview!.full),
                                );
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Đã sao chép địa chỉ.'),
                                  ),
                                );
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 4),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.copy_rounded,
                                      size: 14,
                                      color: cs.primary,
                                    ),
                                    const SizedBox(width: 3),
                                    Text(
                                      'Sao chép',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                        color: cs.primary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Địa chỉ đã chọn
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 26,
                            height: 26,
                            margin: const EdgeInsets.only(top: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE5F0FF),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.radio_button_checked,
                              size: 16,
                              color: Color(0xFF007AFF),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  (_preview?.street ?? '').isNotEmpty
                                      ? _preview!.street
                                      : 'Đặt vị trí tại tâm bản đồ',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14.5,
                                    color: cs.onSurface,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  subtitleText,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: _loadingPreview
                                        ? cs.primary.withOpacity(.9)
                                        : cs.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (_loadingPreview)
                            const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      Divider(
                        height: 1,
                        thickness: 0.6,
                        color: cs.outlineVariant.withOpacity(.4),
                      ),
                      const SizedBox(height: 10),

                      // Nút confirm full width
                      SizedBox(
                        height: kButtonHeight,
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _confirm,
                          icon: const Icon(
                            Icons.check_rounded,
                            size: 18,
                          ),
                          label: const Text(
                            'Dùng vị trí này',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF007AFF),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(13),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ----------------- NÚT ZOOM / ICON PHỤ TRỢ -----------------
class _ZoomButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _ZoomButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.surface.withOpacity(.98),
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: SizedBox(
          width: 36,
          height: 36,
          child: Center(
            child: Icon(
              icon,
              size: 20,
              color: cs.onSurface,
              semanticLabel: tooltip,
            ),
          ),
        ),
      ),
    );
  }
}
