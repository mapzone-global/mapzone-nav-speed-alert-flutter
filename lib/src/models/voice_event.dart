import 'dart:typed_data';

import 'map_read.dart';

/// A voice clip to play, from `NavSpeedAlert.onVoice`.
///
/// Delivered only while `onVoice` has a listener; the built-in player is
/// silent for that time and the host owns playback.
class VoiceEvent {
  /// Creates an event.
  const VoiceEvent({
    required this.wav,
    required this.trigger,
    required this.priority,
  });

  /// Decodes the platform-channel payload.
  factory VoiceEvent.fromMap(Map<Object?, Object?> m) => VoiceEvent(
    wav: m.bytes('wav') ?? Uint8List(0),
    trigger: m.integer('trigger'),
    priority: m.integer('priority'),
  );

  /// WAV clip, PCM 16-bit mono 22050 Hz.
  final Uint8List wav;

  /// Native trigger code of the announcement.
  final int trigger;

  /// Playback priority: `0` current speed (lowest), `1` normal, `2` speeding.
  final int priority;
}
