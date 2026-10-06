/// How alerts are spoken. Detection and on-screen signs are identical in both
/// modes; only the audio changes.
enum VoiceMode {
  /// Full spoken sentences (default).
  full(0),

  /// A chime for cameras and no-parking / no-stopping signs, a distinct chime
  /// for speeding, and silence for everything else.
  ding(1);

  const VoiceMode(this.nativeValue);

  /// Native mode code.
  final int nativeValue;
}
