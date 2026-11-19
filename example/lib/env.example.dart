import 'package:mapzone_nav_speed_alert/mapzone_nav_speed_alert.dart';

import 'models/vehicle_profile.dart';

class Env {
  /// Gateway address issued by MapZone; https:// only.
  static const String baseUrl = 'https://your-gateway-from-mapzone';
  static const String apiKeyId = 'your_speed_alert_key_id';
  static const String apiKey = 'your_speed_alert_key';
  /// Who is signed in when the app starts (phone number, driver code, …).
  /// Editable from the settings dialog for the current run.
  static const String identity = 'your_signed_in_user';

  /// VietMap key for map display, routing and search.
  static const String vietmapApiKey = 'your_vietmap_key';

  static const String vietmapMapStyle =
      'https://maps.vietmap.vn/api/maps/light/styles.json?apikey=$vietmapApiKey';

  static bool get hasAlertCredentials =>
      baseUrl.isNotEmpty && apiKeyId.isNotEmpty && apiKey.isNotEmpty;

  static const VehicleProfile defaultVehicle = VehicleProfile();

  static AlertViewConfig configFor(
    VehicleProfile v, {
    required String identity,
  }) => AlertViewConfig(
    baseUrl: baseUrl,
    apiKeyId: apiKeyId,
    apiKey: apiKey,
    identity: identity,
    vehicleType: v.type.sdkType,
    seats: v.seats,
    weightTons: v.weightTons,
  );
}
