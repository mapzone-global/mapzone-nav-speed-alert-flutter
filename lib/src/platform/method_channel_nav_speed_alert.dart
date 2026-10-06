import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/alert_view_config.dart';
import '../models/location_fix.dart';
import '../models/reroute_event.dart';
import '../models/restriction_event.dart';
import '../models/result_event.dart';
import '../models/signs_event.dart';
import '../models/voice_alert_type.dart';
import '../models/voice_event.dart';
import '../models/voice_mode.dart';
import 'nav_speed_alert_platform.dart';

/// [NavSpeedAlertPlatform] over one method channel and five event channels.
///
/// Each event channel is a broadcast stream created once: every Dart listener
/// shares a single native subscription, which is opened on the first listen
/// and closed on the last cancel. The native side registers its callback only
/// while that subscription is open.
class MethodChannelNavSpeedAlert extends NavSpeedAlertPlatform {
  /// Channel name shared with the native plugins.
  static const String channelName = 'mapzone_nav_speed_alert';

  /// Method channel used for commands.
  @visibleForTesting
  final MethodChannel methodChannel = const MethodChannel(channelName);

  late final Stream<SignsEvent> _signs = _events('signs', SignsEvent.fromMap);
  late final Stream<RestrictionEvent> _restriction = _events(
    'restriction',
    RestrictionEvent.fromMap,
  );
  late final Stream<VoiceEvent> _voice = _events('voice', VoiceEvent.fromMap);
  late final Stream<ResultEvent> _result = _events(
    'result',
    ResultEvent.fromMap,
  );
  late final Stream<RerouteEvent> _reroute = _events(
    'reroute',
    RerouteEvent.fromMap,
  );

  static Stream<T> _events<T>(
    String name,
    T Function(Map<Object?, Object?>) decode,
  ) => EventChannel(
    '$channelName/$name',
  ).receiveBroadcastStream().map((e) => decode(e as Map<Object?, Object?>));

  @override
  Future<void> configure(AlertViewConfig config) =>
      methodChannel.invokeMethod<void>('configure', config.toMap());

  @override
  Future<void> setSegmentUrl(String url) =>
      methodChannel.invokeMethod<void>('setSegmentUrl', {'url': url});

  @override
  Future<String?> setExtraHeaders(Map<String, String> headers) =>
      methodChannel.invokeMethod<String>('setExtraHeaders', {'map': headers});

  @override
  Future<String?> setExtraBodyFields(Map<String, String> fields) =>
      methodChannel.invokeMethod<String>('setExtraBodyFields', {'map': fields});

  @override
  Future<void> start(String routePolyline) =>
      methodChannel.invokeMethod<void>('start', {'polyline': routePolyline});

  @override
  Future<void> onLocation(LocationFix fix) =>
      methodChannel.invokeMethod<void>('onLocation', fix.toMap());

  @override
  Future<void> reset() => methodChannel.invokeMethod<void>('reset');

  @override
  Future<void> setMutedAlertTypes(Set<VoiceAlertType> muted) =>
      methodChannel.invokeMethod<void>('setMutedAlertTypes', {
        'codes': [for (final t in muted) t.triggerValue],
      });

  @override
  Future<void> setVoiceMode(VoiceMode mode) => methodChannel.invokeMethod<void>(
    'setVoiceMode',
    {'mode': mode.nativeValue},
  );

  @override
  Future<void> setVoiceSpeed(double speed) =>
      methodChannel.invokeMethod<void>('setVoiceSpeed', {'speed': speed});

  @override
  Stream<SignsEvent> get onSigns => _signs;

  @override
  Stream<RestrictionEvent> get onRestriction => _restriction;

  @override
  Stream<VoiceEvent> get onVoice => _voice;

  @override
  Stream<ResultEvent> get onResult => _result;

  @override
  Stream<RerouteEvent> get onReroute => _reroute;
}
