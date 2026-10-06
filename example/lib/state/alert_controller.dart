import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:mapzone_nav_speed_alert/mapzone_nav_speed_alert.dart';

import '../env.dart';
import '../models/vehicle_profile.dart';
import '../voice_queue.dart';

/// State holder for [NavSpeedAlert]: configuration, the latest signs, route
/// lifecycle and voice settings.
class AlertController extends ChangeNotifier {
  final NavSpeedAlert _engine = NavSpeedAlert.instance;
  final VoiceQueue _voiceQueue = VoiceQueue();
  final List<StreamSubscription<dynamic>> _subs = [];
  StreamSubscription<VoiceEvent>? _voiceSub;

  bool initialized = false;
  bool running = false;

  /// Latest tick from each sign stream (`null` until the first tick).
  SignsEvent? signs;
  RestrictionEvent? restrictions;

  /// Last failed segment fetch, shown once then cleared.
  ResultEvent? lastError;

  /// Number of segments loaded since [startRoute].
  int loadedSegments = 0;

  /// Called when the engine lost the route; the screen builds a new one.
  void Function(RerouteEvent)? onReroute;

  final Set<VoiceAlertType> mutedTypes = <VoiceAlertType>{};
  VoiceMode voiceMode = VoiceMode.full;
  double voiceSpeed = 1;

  /// When true the app plays clips itself from `onVoice`; otherwise the SDK's
  /// built-in player does.
  bool appPlaysVoice = false;

  VehicleProfile vehicle = Env.defaultVehicle;

  // The engine does not echo the speed back, so keep the last one we sent.
  double speedKmh = 0;

  Future<void> init() async {
    if (initialized) return;
    _subs
      ..add(
        _engine.onSigns.listen((e) {
          signs = e;
          notifyListeners();
        }),
      )
      ..add(
        _engine.onRestriction.listen((e) {
          restrictions = e;
          notifyListeners();
        }),
      )
      ..add(
        _engine.onResult.listen((e) {
          debugPrint('[alert] segment: ok=${e.success} code=${e.errorCode}');
          if (e.success) {
            loadedSegments++;
          } else {
            lastError = e;
          }
          notifyListeners();
        }),
      )
      ..add(_engine.onReroute.listen((e) => onReroute?.call(e)));

    await _configure();
    initialized = true;
    notifyListeners();
  }

  /// Why the last `configure` failed, or `null` when it succeeded.
  String? configureError;

  // init() runs fire-and-forget from the provider, so failures are kept here
  // for the screen to report instead of surfacing as unhandled errors.
  Future<void> _configure() async {
    if (!Env.hasAlertCredentials) return;
    try {
      await _engine.configure(Env.configFor(vehicle));
      configureError = null;
    } catch (e) {
      configureError = '$e';
      debugPrint('[alert] configure failed: $e');
    }
  }

  // ── Route lifecycle ─────────────────────────────────────────────────────────

  /// Start (or restart after a reroute) alerting along [polyline] (1e6).
  Future<void> startRoute(String polyline) async {
    loadedSegments = 0;
    lastError = null;
    await _engine.start(polyline);
    running = true;
    notifyListeners();
  }

  Future<void> stopRoute() async {
    await _engine.reset();
    await _voiceQueue.clear();
    running = false;
    speedKmh = 0;
    signs = null;
    restrictions = null;
    notifyListeners();
  }

  Future<void> onLocation({
    required double lat,
    required double lng,
    required double bearing,
    required double speedKmh,
    double accuracy = 5,
  }) {
    if (speedKmh != this.speedKmh) {
      this.speedKmh = speedKmh;
      notifyListeners();
    }
    return _engine.onLocation(
      LocationFix(
        lat: lat,
        lng: lng,
        bearing: bearing,
        speedKmh: speedKmh,
        accuracy: accuracy,
      ),
    );
  }

  /// Re-configure for another vehicle. Takes effect from the next [startRoute].
  Future<void> applyVehicle(VehicleProfile v) async {
    if (v == vehicle) return;
    vehicle = v;
    await _configure();
    notifyListeners();
  }

  // ── Voice ───────────────────────────────────────────────────────────────────

  bool isMuted(VoiceAlertType type) => mutedTypes.contains(type);

  Future<void> toggleMute(VoiceAlertType type) {
    if (!mutedTypes.remove(type)) mutedTypes.add(type);
    return _applyMutes();
  }

  Future<void> muteAll() {
    mutedTypes
      ..clear()
      ..addAll(VoiceAlertType.values);
    return _applyMutes();
  }

  Future<void> unmuteAll() {
    mutedTypes.clear();
    return _applyMutes();
  }

  Future<void> _applyMutes() async {
    await _engine.setMutedAlertTypes(mutedTypes);
    notifyListeners();
  }

  Future<void> setVoiceMode(VoiceMode mode) async {
    voiceMode = mode;
    await _engine.setVoiceMode(mode);
    notifyListeners();
  }

  Future<void> setVoiceSpeed(double speed) async {
    voiceSpeed = speed;
    await _engine.setVoiceSpeed(speed);
    notifyListeners();
  }

  /// Listening to `onVoice` silences the built-in player; cancelling restores it.
  Future<void> setAppPlaysVoice(bool value) async {
    appPlaysVoice = value;
    if (value) {
      _voiceSub ??= _engine.onVoice.listen(_voiceQueue.enqueue);
    } else {
      await _voiceSub?.cancel();
      _voiceSub = null;
      await _voiceQueue.clear();
    }
    notifyListeners();
  }

  void clearError() {
    lastError = null;
    notifyListeners();
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    _voiceSub?.cancel();
    _voiceQueue.dispose();
    _engine.reset();
    super.dispose();
  }
}
