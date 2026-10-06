import 'package:mapzone_nav_speed_alert/mapzone_nav_speed_alert.dart';

import 'models/vehicle_profile.dart';

class Env {
  static const String baseUrl = "https://driving.map.zone";
  static const String apiKeyId = 'your_speed_alert_key_id';
  static const String apiKey = 'your_speed_alert_key';
  static const String vehicleId = 'your_vehicle_id';

  /// VietMap key for map display, routing and search.
  static const String vietmapApiKey = 'your_vietmap_key';

  static const String vietmapMapStyle =
      'https://maps.vietmap.vn/api/maps/light/styles.json?apikey=$vietmapApiKey';

  static bool get hasAlertCredentials =>
      baseUrl.isNotEmpty && apiKeyId.isNotEmpty && apiKey.isNotEmpty;

  static const VehicleProfile defaultVehicle = VehicleProfile();

  static AlertViewConfig configFor(VehicleProfile v) => AlertViewConfig(
    baseUrl: baseUrl,
    apiKeyId: apiKeyId,
    apiKey: apiKey,
    vehicleId: vehicleId,
    vehicleType: v.type.code,
    seats: v.seats,
    weights: v.weightKg / 1000,
  );
}
