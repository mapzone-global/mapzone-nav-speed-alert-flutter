import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:vietmap_flutter_navigation/models/direction_route.dart';
import 'package:vietmap_flutter_navigation/vietmap_flutter_navigation.dart';

import '../env.dart';

/// Produces the precision-1e6 encoded polyline that `NavSpeedAlert.start`
/// expects, from whatever the navigation SDK hands us.
///
/// * Android: `DirectionRoute.geometry` carries the full route polyline.
/// * iOS: `vietmap_flutter_navigation` sends an empty `geometry`, so the route
///   is fetched again from the VietMap route API for the same waypoints.
///
/// The precision of a source polyline is not documented per platform, so it is
/// detected from the decoded coordinates instead of assumed.
class RoutePolyline {
  /// Resolves the alert polyline for a built route, or `null` on failure.
  static Future<String?> resolve(
    DirectionRoute route, {
    required LatLng origin,
    required LatLng destination,
  }) async {
    final geometry = route.geometry ?? '';
    final source = geometry.isNotEmpty
        ? geometry
        : await fetchRoute(origin, destination);
    if (source == null || source.isEmpty) return null;
    final points = decodeAnyPrecision(source);
    return points.length < 2 ? null : encode(points, 1e6);
  }

  /// Route geometry from the VietMap route API (precision 1e5).
  static Future<String?> fetchRoute(LatLng from, LatLng to) async {
    final uri = Uri.parse('https://maps.vietmap.vn/api/route').replace(
      queryParameters: {
        'api-version': '1.1',
        'apikey': Env.vietmapApiKey,
        'point': [
          '${from.latitude},${from.longitude}',
          '${to.latitude},${to.longitude}',
        ],
        'vehicle': 'car',
        'points_encoded': 'true',
      },
    );
    try {
      final res = await http.get(uri).timeout(const Duration(seconds: 12));
      if (res.statusCode != 200) return null;
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final paths = body['paths'] as List<dynamic>?;
      if (paths == null || paths.isEmpty) return null;
      return (paths.first as Map<String, dynamic>)['points'] as String?;
    } catch (_) {
      return null;
    }
  }

  /// Decodes at 1e6, falling back to 1e5 when the result is not inside Vietnam.
  static List<LatLng> decodeAnyPrecision(String encoded) {
    final at6 = decode(encoded, 1e6);
    return at6.isNotEmpty && _inVietnam(at6.first) ? at6 : decode(encoded, 1e5);
  }

  static bool _inVietnam(LatLng p) =>
      p.latitude >= 8 &&
      p.latitude <= 24 &&
      p.longitude >= 102 &&
      p.longitude <= 110;

  /// Google encoded-polyline decoder.
  static List<LatLng> decode(String encoded, double precision) {
    final points = <LatLng>[];
    var index = 0, lat = 0, lng = 0;
    int next() {
      var result = 0, shift = 0, b = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20 && index < encoded.length);
      return (result & 1) != 0 ? ~(result >> 1) : result >> 1;
    }

    while (index < encoded.length) {
      lat += next();
      if (index >= encoded.length) break;
      lng += next();
      points.add(LatLng(lat / precision, lng / precision));
    }
    return points;
  }

  /// Google encoded-polyline encoder.
  static String encode(List<LatLng> points, double precision) {
    final out = StringBuffer();
    var prevLat = 0, prevLng = 0;
    void put(int v) {
      var x = v < 0 ? ~(v << 1) : v << 1;
      while (x >= 0x20) {
        out.writeCharCode((0x20 | (x & 0x1f)) + 63);
        x >>= 5;
      }
      out.writeCharCode(x + 63);
    }

    for (final p in points) {
      final lat = (p.latitude * precision).round();
      final lng = (p.longitude * precision).round();
      put(lat - prevLat);
      put(lng - prevLng);
      prevLat = lat;
      prevLng = lng;
    }
    return out.toString();
  }
}
