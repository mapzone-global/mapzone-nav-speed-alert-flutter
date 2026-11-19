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

  const config = AlertViewConfig(
    baseUrl: 'https://example.test',
    apiKeyId: 'id',
    apiKey: 'key',
    identity: '+84901234567',
    vehicleType: AlertVehicleType.truck,
    weightTons: 15,
    maxSnapMeters: 25,
  );

  setUp(() {
    calls.clear();
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return switch (call.method) {
        'setExtraHeaders' => throw PlatformException(
          code: 'INVALID_CONFIGURATION',
          message: 'reserved key: Content-Type',
        ),
        'logout' => {
          'success': false,
          'errorCode': AlertViewError.networkFailed,
          'errorMessage': 'Could not reach the server',
        },
        _ => null,
      };
    });
  });

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  Matcher platformError(String code) =>
      throwsA(isA<PlatformException>().having((e) => e.code, 'code', code));

  test('configure sends every field with metadata as JSON text', () async {
    await alert.configure(
      const AlertViewConfig(
        baseUrl: 'https://example.test',
        apiKeyId: 'id',
        apiKey: 'key',
        identity: '+84901234567',
        vehicleType: AlertVehicleType.truck,
        seats: 2,
        weightTons: 15,
        maxSnapMeters: 25,
        metadata: {'vehicleId': '29A-12345', 'axles': 3},
      ),
    );
    expect(calls.single.method, 'configure');
    expect(calls.single.arguments, {
      'baseUrl': 'https://example.test',
      'apiKeyId': 'id',
      'apiKey': 'key',
      'identity': '+84901234567',
      'vehicleType': 5,
      'seats': 2,
      'weightTons': 15.0,
      'maxSnapMeters': 25.0,
      'metadata': '{"vehicleId":"29A-12345","axles":3}',
    });
  });

  test('configure without metadata sends null', () async {
    await alert.configure(config);
    expect((calls.single.arguments as Map)['metadata'], isNull);
  });

  test('configure rejects a non-https baseUrl before reaching native', () async {
    await expectLater(
      alert.configure(
        const AlertViewConfig(
          baseUrl: 'http://example.test',
          apiKeyId: 'id',
          apiKey: 'key',
          identity: 'u',
          vehicleType: AlertVehicleType.car,
        ),
      ),
      platformError('CONFIGURE_FAILED'),
    );
    await expectLater(
      alert.configure(
        const AlertViewConfig(
          baseUrl: 'https://',
          apiKeyId: 'id',
          apiKey: 'key',
          identity: 'u',
          vehicleType: AlertVehicleType.car,
        ),
      ),
      platformError('CONFIGURE_FAILED'),
    );
    expect(calls, isEmpty);

    // Same rule as the SDK: the scheme is case-insensitive.
    await alert.configure(
      const AlertViewConfig(
        baseUrl: 'HTTPS://example.test',
        apiKeyId: 'id',
        apiKey: 'key',
        identity: 'u',
        vehicleType: AlertVehicleType.car,
      ),
    );
    expect(calls.single.method, 'configure');
  });

  test('configure rejects metadata jsonEncode cannot encode', () async {
    await expectLater(
      alert.configure(
        AlertViewConfig(
          baseUrl: 'https://example.test',
          apiKeyId: 'id',
          apiKey: 'key',
          identity: 'u',
          vehicleType: AlertVehicleType.car,
          metadata: {'when': DateTime(2026)},
        ),
      ),
      platformError('INVALID_CONFIGURATION'),
    );
    expect(calls, isEmpty);
  });

  test('configure forwards a native rejection', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      throw PlatformException(
        code: 'INVALID_CONFIGURATION',
        message: 'identity must not be empty',
      );
    });
    await expectLater(
      alert.configure(config),
      throwsA(
        isA<PlatformException>()
            .having((e) => e.code, 'code', 'INVALID_CONFIGURATION')
            .having((e) => e.message, 'message', 'identity must not be empty'),
      ),
    );
  });

  test('logout returns the native result', () async {
    final r = await alert.logout();
    expect(calls.single.method, 'logout');
    expect(r.success, isFalse);
    expect(r.errorCode, AlertViewError.networkFailed);
    expect(r.errorMessage, 'Could not reach the server');
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

  test('request extras complete, or throw the native rejection', () async {
    await expectLater(
      alert.setExtraHeaders({'Content-Type': 'x'}),
      platformError('INVALID_CONFIGURATION'),
    );
    await alert.setExtraBodyFields({'tripId': '42'});
    expect(calls[0].arguments, {
      'map': {'Content-Type': 'x'},
    });
    expect(calls[1].arguments, {
      'map': {'tripId': '42'},
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
    expect(events.single.errorCode, AlertViewError.ok);
  });
}
