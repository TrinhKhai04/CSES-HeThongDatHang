// lib/services/route_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

/// Kết quả từng chặng (leg) giữa 2 điểm liên tiếp
class RouteLegResult {
  final double distanceKm; // km cho chặng
  final double durationMin; // phút cho chặng
  const RouteLegResult(this.distanceKm, this.durationMin);
}

/// Kết quả route tổng (giữ tương thích với code cũ)
class RouteResult {
  /// Encoded polyline toàn tuyến (OSRM trả về). Với ORS GeoJSON thì để rỗng.
  final String polyline;

  /// Tổng quãng đường (km)
  final double distanceKm;

  /// Tổng thời gian (phút)
  final double durationMin;

  /// Danh sách từng chặng (OSRM có legs). ORS proxy có thể để rỗng.
  final List<RouteLegResult> legs;

  /// Danh sách điểm bám đường (rất quan trọng để vẽ trên WEB)
  final List<LatLng> points;

  const RouteResult(
      this.polyline,
      this.distanceKm,
      this.durationMin, {
        this.legs = const [],
        this.points = const [],
      });
}

class RouteService {
  // =========================================================
  // A) ORS Proxy (Cloudflare Worker) - khuyên dùng cho WEB
  // =========================================================
  // URL worker của bạn (đổi nếu bạn đổi domain worker)
  static const String _orsProxyBase =
      'https://cses-route-proxy.trinhquangkhai2010.workers.dev';

  // Endpoint bạn đã làm trong worker: POST /ors/route
  static const String _orsProxyRoutePath = '/ors/route';

  // =========================================================
  // B) OSRM Public (fallback) - dùng tốt cho MOBILE / test
  // =========================================================
  static const String _osrmBaseUrl =
      'https://router.project-osrm.org/route/v1/driving';

  // =========================================================
  // 1) API fromTo giữ tương thích
  // =========================================================
  static Future<RouteResult> fromTo({
    required double fromLat,
    required double fromLng,
    required double toLat,
    required double toLng,
  }) {
    return fromToVia(
      fromLat: fromLat,
      fromLng: fromLng,
      toLat: toLat,
      toLng: toLng,
      waypoints: const [],
    );
  }

  // =========================================================
  // 2) API mới (giữ tên fromToVia) nhưng ưu tiên ORS Proxy:
  //    from → [waypoints...] → to
  //
  //  - Trả về RouteResult.points để vẽ bám đường (WEB)
  //  - Nếu ORS lỗi thì fallback OSRM để app không “chết”
  // =========================================================
  static Future<RouteResult> fromToVia({
    required double fromLat,
    required double fromLng,
    required double toLat,
    required double toLng,
    List<Map<String, double>> waypoints = const [],
  }) async {
    try {
      return await _fromToViaORSProxy(
        fromLat: fromLat,
        fromLng: fromLng,
        toLat: toLat,
        toLng: toLng,
        waypoints: waypoints,
      );
    } catch (_) {
      // Fallback OSRM (để vẫn chạy được nếu ORS quá quota / lỗi mạng)
      return await _fromToViaOSRM(
        fromLat: fromLat,
        fromLng: fromLng,
        toLat: toLat,
        toLng: toLng,
        waypoints: waypoints,
      );
    }
  }

  // =========================================================
  // ORS Proxy implementation
  // =========================================================
  static Future<RouteResult> _fromToViaORSProxy({
    required double fromLat,
    required double fromLng,
    required double toLat,
    required double toLng,
    List<Map<String, double>> waypoints = const [],
  }) async {
    // 1) Gom điểm theo thứ tự: from → waypoints → to
    final pts = <Map<String, double>>[
      {'lat': fromLat, 'lng': fromLng},
      ...waypoints,
      {'lat': toLat, 'lng': toLng},
    ];

    // 2) ORS nhận coordinates theo format [lng, lat]
    final coords = pts
        .map((p) => [p['lng']!, p['lat']!])
        .toList(growable: false);

    final uri = Uri.parse('$_orsProxyBase$_orsProxyRoutePath');

    final payload = <String, dynamic>{
      'coordinates': coords,
      // format có thể có hoặc không - worker của bạn vẫn xử lý được
      'format': 'geojson',
      'instructions': false,
    };

    final res = await http
        .post(
      uri,
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    )
        .timeout(const Duration(seconds: 20));

    if (res.statusCode != 200) {
      throw Exception('ORS proxy error: HTTP ${res.statusCode} :: ${res.body}');
    }

    final data = jsonDecode(res.body);

    // ORS geojson thường là FeatureCollection
    // { type: "FeatureCollection", features:[ { geometry:{coordinates:[...]}, properties:{summary:{distance,duration}} } ] }
    if (data is! Map<String, dynamic>) {
      throw Exception('ORS proxy returned invalid JSON');
    }

    final features = (data['features'] as List?) ?? const [];
    if (features.isEmpty || features.first is! Map<String, dynamic>) {
      throw Exception('ORS proxy: no features in response');
    }

    final f0 = features.first as Map<String, dynamic>;
    final geometry = (f0['geometry'] as Map?)?.cast<String, dynamic>();
    final props = (f0['properties'] as Map?)?.cast<String, dynamic>();

    final coordsRaw = (geometry?['coordinates'] as List?) ?? const [];
    final points = <LatLng>[];

    for (final c in coordsRaw) {
      if (c is List && c.length >= 2) {
        final lng = (c[0] as num).toDouble();
        final lat = (c[1] as num).toDouble();
        points.add(LatLng(lat, lng));
      }
    }

    // distance(m), duration(s)
    final summary = (props?['summary'] as Map?)?.cast<String, dynamic>() ?? {};
    final distM = (summary['distance'] as num?)?.toDouble() ?? 0.0;
    final durS = (summary['duration'] as num?)?.toDouble() ?? 0.0;

    return RouteResult(
      '', // ORS geojson không cần polyline
      distM / 1000.0,
      durS / 60.0,
      legs: const [],
      points: points,
    );
  }

  // =========================================================
  // OSRM fallback implementation (giữ logic cũ của bạn)
  // =========================================================
  static Future<RouteResult> _fromToViaOSRM({
    required double fromLat,
    required double fromLng,
    required double toLat,
    required double toLng,
    List<Map<String, double>> waypoints = const [],
  }) async {
    // 1) Gom điểm theo thứ tự: from → waypoints → to
    final points = <Map<String, double>>[
      {'lat': fromLat, 'lng': fromLng},
      ...waypoints,
      {'lat': toLat, 'lng': toLng},
    ];

    // 2) Build chuỗi toạ độ cho OSRM: "lng,lat;lng,lat;..."
    final coordStr = points
        .map((p) =>
    '${p['lng']!.toStringAsFixed(6)},${p['lat']!.toStringAsFixed(6)}')
        .join(';');

    final url =
        '$_osrmBaseUrl/$coordStr?overview=full&geometries=polyline&steps=false';

    final res = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 20));

    if (res.statusCode != 200) {
      throw Exception('OSRM routing error: HTTP ${res.statusCode}');
    }

    final data = json.decode(res.body) as Map<String, dynamic>;

    final routes = data['routes'] as List? ?? [];
    if (routes.isEmpty) {
      throw Exception('OSRM: Không tìm thấy tuyến đường phù hợp');
    }

    final r0 = routes.first as Map<String, dynamic>;

    // 3) Polyline toàn tuyến (encoded)
    final poly = (r0['geometry'] as String?) ?? '';

    // 4) Tổng distance / duration
    final totalKm = ((r0['distance'] as num?)?.toDouble() ?? 0.0) / 1000.0;
    final totalMin = ((r0['duration'] as num?)?.toDouble() ?? 0.0) / 60.0;

    // 5) Parse từng leg OSRM
    final legs = <RouteLegResult>[];
    final rawLegs = r0['legs'] as List? ?? [];
    for (final lg in rawLegs) {
      if (lg is Map<String, dynamic>) {
        final distM = (lg['distance'] as num?)?.toDouble() ?? 0.0;
        final durS = (lg['duration'] as num?)?.toDouble() ?? 0.0;
        legs.add(RouteLegResult(distM / 1000.0, durS / 60.0));
      }
    }

    // Decode polyline luôn để trả points (dùng cho web nếu cần)
    final decoded = poly.isNotEmpty ? decodePolyline(poly) : <LatLng>[];

    return RouteResult(
      poly,
      totalKm,
      totalMin,
      legs: legs,
      points: decoded,
    );
  }

  // =========================================================
  // 3) Decode polyline → danh sách LatLng bám đường
  // =========================================================
  static List<LatLng> decodePolyline(String encoded) {
    final List<LatLng> coords = [];
    int index = 0;
    int lat = 0;
    int lng = 0;

    while (index < encoded.length) {
      int b;
      int shift = 0;
      int result = 0;

      // latitude
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1F) << shift;
        shift += 5;
      } while (b >= 0x20);
      final dlat = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lat += dlat;

      // longitude
      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1F) << shift;
        shift += 5;
      } while (b >= 0x20);
      final dlng = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lng += dlng;

      coords.add(LatLng(lat / 1e5, lng / 1e5));
    }

    return coords;
  }
}
