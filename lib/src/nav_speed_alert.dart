import 'models/alert_view_config.dart';
import 'models/location_fix.dart';
import 'models/reroute_event.dart';
import 'models/restriction_event.dart';
import 'models/result_event.dart';
import 'models/signs_event.dart';
import 'models/voice_alert_type.dart';
import 'models/voice_event.dart';
import 'models/voice_mode.dart';
import 'platform/nav_speed_alert_platform.dart';

/// Speed and sign alerts along a route given by the host navigation app.
///
/// ```dart
/// final alert = NavSpeedAlert.instance;
/// await alert.configure(AlertViewConfig(...));
/// alert.onSigns.listen((e) => setState(() => _signs = e));
/// await alert.start(routePolyline);          // encoded polyline, precision 1e6
/// // every GPS fix (~1 Hz):
/// await alert.onLocation(LocationFix(lat: .., lng: .., bearing: .., speedKmh: ..));
/// // navigation finished:
/// await alert.reset();
/// ```
///
/// The native engine is process-wide: use it from a single Flutter engine.
class NavSpeedAlert {
  NavSpeedAlert._();

  /// The shared instance.
  static final NavSpeedAlert instance = NavSpeedAlert._();

  NavSpeedAlertPlatform get _platform => NavSpeedAlertPlatform.instance;

  /// Sets credentials and the vehicle profile. Call before [start].
  ///
  /// Completes with an [ArgumentError] when `vehicleType` is outside `1..9`,
  /// and a `PlatformException` when the native SDK cannot initialise.
  Future<void> configure(AlertViewConfig config) async {
    if (config.vehicleType < 1 || config.vehicleType > 9) {
      throw ArgumentError.value(
        config.vehicleType,
        'vehicleType',
        'must be in 1..9',
      );
    }
    return _platform.configure(config);
  }

  /// Overrides the URL of the segment request only. An empty string restores
  /// the default derived from `baseUrl`. Persists across routes.
  Future<void> setSegmentUrl(String url) => _platform.setSegmentUrl(url);

  /// Adds HTTP headers to segment requests; call after [configure] and before
  /// [start]. Returns `null` on success, otherwise an error message (reserved,
  /// empty or multi-line key/value) and the previous headers are kept.
  /// Pass `{}` to clear. Persists across routes.
  Future<String?> setExtraHeaders(Map<String, String> headers) =>
      _platform.setExtraHeaders(headers);

  /// Adds string fields to segment request bodies. Same timing and return
  /// contract as [setExtraHeaders]; SDK-owned fields cannot be overridden.
  Future<String?> setExtraBodyFields(Map<String, String> fields) =>
      _platform.setExtraBodyFields(fields);

  /// Starts alerting along [routePolyline] (encoded polyline, precision 1e6).
  /// Call again with the new route after a reroute.
  Future<void> start(String routePolyline) => _platform.start(routePolyline);

  /// Feeds one GPS fix. Expected cadence is about 1 Hz.
  Future<void> onLocation(LocationFix fix) => _platform.onLocation(fix);

  /// Releases route and voice state, e.g. when navigation ends.
  Future<void> reset() => _platform.reset();

  /// Mutes the given voice categories; an empty set announces everything.
  /// See [VoiceAlertType] for which categories also hide their sign.
  /// Persists across routes.
  Future<void> setMutedAlertTypes(Set<VoiceAlertType> muted) =>
      _platform.setMutedAlertTypes(muted);

  /// Chooses full sentences or chimes. Muted categories stay silent in both
  /// modes. Persists across routes.
  Future<void> setVoiceMode(VoiceMode mode) => _platform.setVoiceMode(mode);

  /// Sets the built-in player's playback speed (`1.0` = recorded speed,
  /// clamped to `0.5..2.0`, pitch kept). No effect while [onVoice] has a
  /// listener. Persists across routes.
  Future<void> setVoiceSpeed(double speed) => _platform.setVoiceSpeed(speed);

  /// Speed-limit, camera and toll signs, once per GPS tick after [start].
  Stream<SignsEvent> get onSigns => _platform.onSigns;

  /// Road-restriction signs, once per GPS tick while this stream has a
  /// listener. On Android the images are not rendered at all without one.
  Stream<RestrictionEvent> get onRestriction => _platform.onRestriction;

  /// Voice clips for the host to play. While this stream has a listener the
  /// built-in player is silent; cancel every subscription to restore it.
  Stream<VoiceEvent> get onVoice => _platform.onVoice;

  /// Outcome of each route-segment fetch.
  Stream<ResultEvent> get onResult => _platform.onResult;

  /// The route was lost; compute a new one and call [start] again.
  Stream<RerouteEvent> get onReroute => _platform.onReroute;
}
