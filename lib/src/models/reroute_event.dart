import 'map_read.dart';

/// The engine lost the loaded route and could not re-acquire it (a real
/// detour), from `NavSpeedAlert.onReroute`.
///
/// Compute a new route from [lat]/[lng] and call `NavSpeedAlert.start` again.
class RerouteEvent {
  /// Creates an event.
  const RerouteEvent({required this.lat, required this.lng});

  /// Decodes the platform-channel payload.
  factory RerouteEvent.fromMap(Map<Object?, Object?> m) =>
      RerouteEvent(lat: m.float('lat'), lng: m.float('lng'));

  /// Latitude where the route was lost.
  final double lat;

  /// Longitude where the route was lost.
  final double lng;
}
