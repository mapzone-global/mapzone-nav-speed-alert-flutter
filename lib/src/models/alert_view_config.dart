/// Credentials and vehicle profile for the native engine.
///
/// Pass to `NavSpeedAlert.configure` once before `start`. The application id
/// (Android package name / iOS bundle id) is resolved natively and must match
/// the id registered for [apiKeyId] exactly — builds with an id suffix such as
/// `.debug` are rejected by the service.
class AlertViewConfig {
  /// Creates a configuration. [vehicleType] must be in `1..9`.
  const AlertViewConfig({
    required this.baseUrl,
    required this.apiKeyId,
    required this.apiKey,
    required this.vehicleId,
    required this.vehicleType,
    this.seats = 0,
    this.weights = 0,
    this.maxSnapMeters = 0,
  });

  /// Service base URL.
  final String baseUrl;

  /// API key id issued for this application.
  final String apiKeyId;

  /// API key secret issued for this application.
  final String apiKey;

  /// Caller-defined identifier of the vehicle.
  final String vehicleId;

  /// Vehicle class code `1..9` as defined by the alert service.
  final int vehicleType;

  /// Number of seats (coaches); `0` uses the default for [vehicleType].
  final int seats;

  /// Gross weight in tonnes (trucks); `0` uses the default for [vehicleType].
  final double weights;

  /// Maximum distance (m) a GPS fix may be from the route and still snap to
  /// it; `<= 0` uses the service default (about 25 m).
  final double maxSnapMeters;

  /// Serialises this configuration for the platform channel.
  Map<String, Object?> toMap() => {
    'baseUrl': baseUrl,
    'apiKeyId': apiKeyId,
    'apiKey': apiKey,
    'vehicleId': vehicleId,
    'vehicleType': vehicleType,
    'seats': seats,
    'weights': weights,
    'maxSnapMeters': maxSnapMeters,
  };
}
