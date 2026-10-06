import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mapzone_nav_speed_alert/mapzone_nav_speed_alert.dart';

void main() {
  final png = Uint8List.fromList([137, 80, 78, 71]);

  test('VoiceAlertType trigger values match the native SDK', () {
    // Mirrors VoiceAlertType.java / VoiceAlertType.swift in the native SDK.
    const expected = {
      VoiceAlertType.speedCamera: 3,
      VoiceAlertType.toll: 4,
      VoiceAlertType.trafficEnforcementCamera: 6,
      VoiceAlertType.redLightCamera: 7,
      VoiceAlertType.aiCamera: 8,
      VoiceAlertType.noLeftTurn: 9,
      VoiceAlertType.noRightTurn: 10,
      VoiceAlertType.noUturn: 11,
      VoiceAlertType.noOvertaking: 12,
      VoiceAlertType.noOvertakingEnd: 13,
      VoiceAlertType.noParking: 14,
      VoiceAlertType.noStraight: 15,
      VoiceAlertType.buildupAreaStart: 16,
      VoiceAlertType.buildupAreaEnd: 17,
      VoiceAlertType.restStation: 18,
      VoiceAlertType.noStopping: 19,
      VoiceAlertType.roadClosed: 20,
      VoiceAlertType.vehicleRestricted: 21,
    };
    expect(VoiceAlertType.values.length, expected.length);
    for (final t in VoiceAlertType.values) {
      expect(t.triggerValue, expected[t], reason: t.name);
    }
  });

  test('VoiceMode and SpeedStatus codes', () {
    expect(VoiceMode.full.nativeValue, 0);
    expect(VoiceMode.ding.nativeValue, 1);
    expect(SpeedStatus.fromCode(0), SpeedStatus.safe);
    expect(SpeedStatus.fromCode(1), SpeedStatus.approaching);
    expect(SpeedStatus.fromCode(2), SpeedStatus.speeding);
    expect(SpeedStatus.fromCode(9), SpeedStatus.safe);
  });

  test('SignsEvent decodes images, empty slots and numeric types', () {
    final e = SignsEvent.fromMap({
      'current': png,
      'speedStatus': 2,
      'next': null,
      'nextDistMeters': 340.0,
      'camera': png,
      'cameraDistMeters': 0,
      'tollDistMeters': 12,
    });
    expect(e.current, png);
    expect(e.speedStatus, SpeedStatus.speeding);
    expect(e.next, isNull);
    expect(e.nextDistMeters, 340);
    expect(e.camera, png);
    expect(e.cameraDistMeters, 0);
    expect(e.toll, isNull);
    expect(e.tollDistMeters, 12);
  });

  test('RestrictionEvent decodes every slot', () {
    final e = RestrictionEvent.fromMap({
      'stop': png,
      'stopDistMeters': 50,
      'closed': null,
      'closedDistMeters': 0,
      'vehicle': png,
      'vehicleDistMeters': 120,
      'bua': png,
      'buaDistMeters': 0,
      'inBua': true,
      'turn': null,
      'turnDistMeters': 0,
    });
    expect(e.stop, png);
    expect(e.stopDistMeters, 50);
    expect(e.closed, isNull);
    expect(e.vehicle, png);
    expect(e.vehicleDistMeters, 120);
    expect(e.bua, png);
    expect(e.inBua, isTrue);
    expect(e.turn, isNull);
  });

  test('Voice, result and reroute events decode', () {
    final v = VoiceEvent.fromMap({'wav': png, 'trigger': 3, 'priority': 1});
    expect(v.wav, png);
    expect(v.trigger, 3);
    expect(v.priority, 1);

    final r = ResultEvent.fromMap({
      'success': false,
      'errorCode': 1003,
      'errorMessage': 'bad polyline',
    });
    expect(r.success, isFalse);
    expect(r.errorCode, 1003);
    expect(r.errorMessage, 'bad polyline');

    final rr = RerouteEvent.fromMap({'lat': 21.0, 'lng': 105});
    expect(rr.lat, 21.0);
    expect(rr.lng, 105.0);
  });

  test('LocationFix defaults the timestamp to now', () {
    final before = DateTime.now().millisecondsSinceEpoch;
    final fix = LocationFix(lat: 1, lng: 2, bearing: 3, speedKmh: 4);
    expect(fix.fixTimeMillis, greaterThanOrEqualTo(before));
    expect(fix.accuracy, 0);
  });
}
