import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import '../models/alert_view_config.dart';
import '../models/location_fix.dart';
import '../models/reroute_event.dart';
import '../models/restriction_event.dart';
import '../models/result_event.dart';
import '../models/signs_event.dart';
import '../models/voice_alert_type.dart';
import '../models/voice_event.dart';
import '../models/voice_mode.dart';
import 'method_channel_nav_speed_alert.dart';

/// Platform contract behind `NavSpeedAlert`. Replace [instance] in tests.
abstract class NavSpeedAlertPlatform extends PlatformInterface {
  /// Constructs a platform implementation.
  NavSpeedAlertPlatform() : super(token: _token);

  static final Object _token = Object();

  static NavSpeedAlertPlatform _instance = MethodChannelNavSpeedAlert();

  /// The active implementation; defaults to [MethodChannelNavSpeedAlert].
  static NavSpeedAlertPlatform get instance => _instance;

  static set instance(NavSpeedAlertPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  /// See `NavSpeedAlert.configure`.
  Future<void> configure(AlertViewConfig config);

  /// See `NavSpeedAlert.setSegmentUrl`.
  Future<void> setSegmentUrl(String url);

  /// See `NavSpeedAlert.setExtraHeaders`.
  Future<String?> setExtraHeaders(Map<String, String> headers);

  /// See `NavSpeedAlert.setExtraBodyFields`.
  Future<String?> setExtraBodyFields(Map<String, String> fields);

  /// See `NavSpeedAlert.start`.
  Future<void> start(String routePolyline);

  /// See `NavSpeedAlert.onLocation`.
  Future<void> onLocation(LocationFix fix);

  /// See `NavSpeedAlert.reset`.
  Future<void> reset();

  /// See `NavSpeedAlert.setMutedAlertTypes`.
  Future<void> setMutedAlertTypes(Set<VoiceAlertType> muted);

  /// See `NavSpeedAlert.setVoiceMode`.
  Future<void> setVoiceMode(VoiceMode mode);

  /// See `NavSpeedAlert.setVoiceSpeed`.
  Future<void> setVoiceSpeed(double speed);

  /// See `NavSpeedAlert.onSigns`.
  Stream<SignsEvent> get onSigns;

  /// See `NavSpeedAlert.onRestriction`.
  Stream<RestrictionEvent> get onRestriction;

  /// See `NavSpeedAlert.onVoice`.
  Stream<VoiceEvent> get onVoice;

  /// See `NavSpeedAlert.onResult`.
  Stream<ResultEvent> get onResult;

  /// See `NavSpeedAlert.onReroute`.
  Stream<RerouteEvent> get onReroute;
}
