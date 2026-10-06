import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mapzone_nav_speed_alert/mapzone_nav_speed_alert.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('mapzone_nav_speed_alert');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final calls = <MethodCall>[];
  final alert = NavSpeedAlert.instance;

  setUp(() {
    calls.clear();
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return switch (call.method) {
        'setExtraHeaders' => 'reserved key: Content-Type',
        'setExtraBodyFields' => null,
        _ => null,
      };
    });
  });

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('configure sends every field and rejects a bad vehicle type', () async {
    const config = AlertViewConfig(
      baseUrl: 'https://example.test',
      apiKeyId: 'id',
      apiKey: 'key',
      vehicleId: 'car-1',
      vehicleType: 1,
      maxSnapMeters: 25,
    );
    await alert.configure(config);
    expect(calls.single.method, 'configure');
    expect(calls.single.arguments, {
      'baseUrl': 'https://example.test',
      'apiKeyId': 'id',
      'apiKey': 'key',
      'vehicleId': 'car-1',
      'vehicleType': 1,
      'seats': 0,
      'weights': 0.0,
      'maxSnapMeters': 25.0,
    });

    expect(
      () => alert.configure(
        const AlertViewConfig(
          baseUrl: '',
          apiKeyId: '',
          apiKey: '',
          vehicleId: '',
          vehicleType: 10,
        ),
      ),
      throwsArgumentError,
    );
  });

  test('route and location commands', () async {
    await alert.start('abc');
    await alert.onLocation(
      LocationFix(
        lat: 21,
        lng: 105.8,
        bearing: 90,
        speedKmh: 40,
        accuracy: 5,
        fixTimeMillis: 7,
      ),
    );
    await alert.reset();
    expect(calls.map((c) => c.method), ['start', 'onLocation', 'reset']);
    expect(calls[0].arguments, {'polyline': 'abc'});
    expect(calls[1].arguments, {
      'lat': 21.0,
      'lng': 105.8,
      'bearing': 90.0,
      'speedKmh': 40.0,
      'accuracy': 5.0,
      'fixTimeMillis': 7,
    });
  });

  test('voice settings', () async {
    await alert.setMutedAlertTypes({
      VoiceAlertType.speedCamera,
      VoiceAlertType.vehicleRestricted,
    });
    await alert.setVoiceMode(VoiceMode.ding);
    await alert.setVoiceSpeed(1.5);
    expect(calls[0].arguments, {
      'codes': [3, 21],
    });
    expect(calls[1].arguments, {'mode': 1});
    expect(calls[2].arguments, {'speed': 1.5});
  });

  test('request extras return the native error message or null', () async {
    expect(
      await alert.setExtraHeaders({'Content-Type': 'x'}),
      'reserved key: Content-Type',
    );
    expect(await alert.setExtraBodyFields({'tripId': '42'}), isNull);
    expect(calls[0].arguments, {
      'map': {'Content-Type': 'x'},
    });
    await alert.setSegmentUrl('');
    expect(calls.last.arguments, {'url': ''});
  });

  test('event channels decode native payloads', () async {
    const name = 'mapzone_nav_speed_alert/result';
    messenger.setMockStreamHandler(
      const EventChannel(name),
      MockStreamHandler.inline(
        onListen: (args, sink) {
          sink.success({'success': true, 'errorCode': 0, 'errorMessage': ''});
          sink.endOfStream();
        },
      ),
    );
    final events = await alert.onResult.toList();
    expect(events.single.success, isTrue);
    expect(events.single.errorCode, 0);
  });
}
