import 'package:flutter/services.dart';

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
/// await alert.configure(AlertViewConfig(...)); // every launch, signed-in user
/// alert.onSigns.listen((e) => setState(() => _signs = e));
/// await alert.start(routePolyline);          // encoded polyline, precision 1e6
/// // every GPS fix (~1 Hz):
/// await alert.onLocation(LocationFix(lat: .., lng: .., bearing: .., speedKmh: ..));
/// // navigation finished:
/// await alert.reset();
/// // the user signs out of your app:
/// await alert.logout();
/// ```
///
/// The native engine is process-wide: use it from a single Flutter engine.
class NavSpeedAlert {
  NavSpeedAlert._();

  /// The shared instance.
  static final NavSpeedAlert instance = NavSpeedAlert._();

  NavSpeedAlertPlatform get _platform => NavSpeedAlertPlatform.instance;

  /// Sets credentials and the vehicle profile, and signs
  /// [AlertViewConfig.identity] in on this device. Call it before [start] on
  /// every sign-in and on every app launch with a user already signed in;
  /// call it again to switch identity or vehicle.
  ///
  /// Throws a [PlatformException]:
  /// * `INVALID_CONFIGURATION` — the SDK rejected an input (identity, vehicle
  ///   type, seats, weight, snap distance, metadata), or
  ///   [AlertViewConfig.metadata] holds a value `jsonEncode` cannot encode.
  ///   The message says why. Nothing was applied: the previous configuration
  ///   stays in effect.
  /// * `CONFIGURE_FAILED` — `baseUrl` is not `https://`, or the SDK could not
  ///   start in this process.
  ///
  /// The sign-in itself runs in the background; its failures arrive on
  /// [onResult] (see `AlertViewError`).
  Future<void> configure(AlertViewConfig config) async {
    // The only check made here rather than in the SDK, so both platforms
    // report it with the same code before anything reaches native.
    final url = config.baseUrl;
    if (url.length <= 8 || url.substring(0, 8).toLowerCase() != 'https://') {
      throw PlatformException(
        code: 'CONFIGURE_FAILED',
        message: 'baseUrl must start with https://',
      );
    }
    await _platform.configure(config);
  }

  /// Signs the identity out of this device: call it when the user signs out,
  /// and after `AlertViewError.sessionMoved`.
  ///
  /// Requests already queued finish first. Route data already loaded keeps
  /// alerting; later fetches report `AlertViewError.notLoggedIn` until the
  /// next [configure]. The result is `success == true` when signed out, also
  /// when nothing was configured in this process (no request is sent then).
  /// On failure (e.g. offline) the identity is kept: call [logout] again to
  /// retry. [reset] does not sign out.
  Future<ResultEvent> logout() => _platform.logout();

  /// Overrides the URL of the segment request only (must be `https://`). An
  /// empty string restores the default derived from `baseUrl`. Persists
  /// across routes.
  ///
  /// Throws `PlatformException(INVALID_CONFIGURATION)` with the reason when
  /// the URL is rejected; the previous URL is kept.
  Future<void> setSegmentUrl(String url) => _platform.setSegmentUrl(url);

  /// Adds HTTP headers to segment requests; call after [configure] and before
  /// [start]. Pass `{}` to clear. Persists across routes.
  ///
  /// Throws `PlatformException(INVALID_CONFIGURATION)` with the reason when a
  /// key is reserved, empty or a key/value spans lines; the previous headers
  /// are kept.
  Future<void> setExtraHeaders(Map<String, String> headers) =>
      _platform.setExtraHeaders(headers);

  /// Adds string fields to segment request bodies. Same timing and error
  /// contract as [setExtraHeaders]; SDK-owned fields cannot be overridden.
  Future<void> setExtraBodyFields(Map<String, String> fields) =>
      _platform.setExtraBodyFields(fields);

  /// Starts alerting along [routePolyline] (encoded polyline, precision 1e6).
  /// Call again with the new route after a reroute.
  Future<void> start(String routePolyline) => _platform.start(routePolyline);

  /// Feeds one GPS fix. Expected cadence is about 1 Hz.
  Future<void> onLocation(LocationFix fix) => _platform.onLocation(fix);

  /// Releases route and voice state, e.g. when navigation ends. Keeps the
  /// signed-in identity.
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

  /// Outcome of each failed sign-in and each route-segment fetch (see
  /// `AlertViewError`).
  Stream<ResultEvent> get onResult => _platform.onResult;

  /// The route was lost; compute a new one and call [start] again.
  Stream<RerouteEvent> get onReroute => _platform.onReroute;
}
