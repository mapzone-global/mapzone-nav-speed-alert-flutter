import 'package:flutter_test/flutter_test.dart';
import 'package:mapzone_nav_speed_alert_example/services/route_polyline.dart';
import 'package:vietmap_flutter_navigation/vietmap_flutter_navigation.dart';

void main() {
  const route = [
    LatLng(10.759222, 106.675902),
    LatLng(10.760101, 106.677315),
    LatLng(10.776000, 106.700000),
  ];

  void expectClose(List<LatLng> actual, double tolerance) {
    expect(actual.length, route.length);
    for (var i = 0; i < route.length; i++) {
      expect(actual[i].latitude, closeTo(route[i].latitude, tolerance));
      expect(actual[i].longitude, closeTo(route[i].longitude, tolerance));
    }
  }

  test('round-trips at precision 1e6', () {
    final encoded = RoutePolyline.encode(route, 1e6);
    expectClose(RoutePolyline.decode(encoded, 1e6), 1e-6);
  });

  test('detects a 1e5 polyline and re-encodes it at 1e6', () {
    final at5 = RoutePolyline.encode(route, 1e5);
    final points = RoutePolyline.decodeAnyPrecision(at5);
    expectClose(points, 1e-5);
    final at6 = RoutePolyline.encode(points, 1e6);
    expectClose(RoutePolyline.decode(at6, 1e6), 1e-5);
  });

  test('keeps a 1e6 polyline at 1e6', () {
    final at6 = RoutePolyline.encode(route, 1e6);
    expectClose(RoutePolyline.decodeAnyPrecision(at6), 1e-6);
  });

  test('decodes the canonical Google sample', () {
    // https://developers.google.com/maps/documentation/utilities/polylinealgorithm
    final p = RoutePolyline.decode('_p~iF~ps|U_ulLnnqC_mqNvxq`@', 1e5);
    expect(p.first.latitude, closeTo(38.5, 1e-9));
    expect(p.first.longitude, closeTo(-120.2, 1e-9));
    expect(p.last.latitude, closeTo(43.252, 1e-9));
    expect(p.last.longitude, closeTo(-126.453, 1e-9));
  });
}
