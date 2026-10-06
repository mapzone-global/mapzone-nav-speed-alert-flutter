import 'dart:typed_data';

import 'map_read.dart';
import 'speed_status.dart';

/// Speed-limit, camera and toll signs for one GPS tick, from
/// `NavSpeedAlert.onSigns`.
///
/// Each image is a PNG ready for `Image.memory`; `null` means nothing to show
/// in that slot. Images are re-rendered every tick, so pass
/// `gaplessPlayback: true` to avoid flicker.
class SignsEvent {
  /// Creates an event.
  const SignsEvent({
    required this.current,
    required this.speedStatus,
    required this.next,
    required this.nextDistMeters,
    required this.camera,
    required this.cameraDistMeters,
    required this.toll,
    required this.tollDistMeters,
  });

  /// Decodes the platform-channel payload.
  factory SignsEvent.fromMap(Map<Object?, Object?> m) => SignsEvent(
    current: m.bytes('current'),
    speedStatus: SpeedStatus.fromCode(m.integer('speedStatus')),
    next: m.bytes('next'),
    nextDistMeters: m.integer('nextDistMeters'),
    camera: m.bytes('camera'),
    cameraDistMeters: m.integer('cameraDistMeters'),
    toll: m.bytes('toll'),
    tollDistMeters: m.integer('tollDistMeters'),
  );

  /// Current speed-limit sign, or `null` when no road is matched.
  final Uint8List? current;

  /// Current speed against the current limit.
  final SpeedStatus speedStatus;

  /// Next speed-limit sign ahead.
  final Uint8List? next;

  /// Distance to [next] in metres.
  final int nextDistMeters;

  /// Nearest camera ahead; the artwork shows the camera kind.
  final Uint8List? camera;

  /// Distance to [camera] in metres.
  final int cameraDistMeters;

  /// Nearest toll booth ahead.
  final Uint8List? toll;

  /// Distance to [toll] in metres.
  final int tollDistMeters;
}
