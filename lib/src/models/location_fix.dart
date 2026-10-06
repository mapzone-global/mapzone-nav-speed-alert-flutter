/// One GPS sample forwarded to the engine with `NavSpeedAlert.onLocation`.
///
/// Feed fixes at about 1 Hz; faster fixes are dropped by the engine.
class LocationFix {
  /// Creates a fix. [fixTimeMillis] defaults to the current time.
  LocationFix({
    required this.lat,
    required this.lng,
    required this.bearing,
    required this.speedKmh,
    this.accuracy = 0,
    int? fixTimeMillis,
  }) : fixTimeMillis = fixTimeMillis ?? DateTime.now().millisecondsSinceEpoch;

  /// Latitude in degrees (WGS84).
  final double lat;

  /// Longitude in degrees (WGS84).
  final double lng;

  /// Heading in degrees, `0` = north, `90` = east.
  final double bearing;

  /// Current speed in km/h.
  final double speedKmh;

  /// Horizontal accuracy radius in metres.
  final double accuracy;

  /// Fix timestamp in milliseconds since the epoch (UTC).
  final int fixTimeMillis;

  /// Serialises this fix for the platform channel.
  Map<String, Object?> toMap() => {
    'lat': lat,
    'lng': lng,
    'bearing': bearing,
    'speedKmh': speedKmh,
    'accuracy': accuracy,
    'fixTimeMillis': fixTimeMillis,
  };
}
