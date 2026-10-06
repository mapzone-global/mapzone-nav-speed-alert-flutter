/// Voice alert categories that can be muted with
/// `NavSpeedAlert.setMutedAlertTypes`.
///
/// Speed-limit and speeding announcements are not listed: they cannot be
/// muted. Muting a camera or toll category also hides its sign (there is a
/// single slot for each); muting a restriction category only silences the
/// voice — the sign still shows.
enum VoiceAlertType {
  /// Speed camera.
  speedCamera(3),

  /// Toll booth.
  toll(4),

  /// Traffic-enforcement camera.
  trafficEnforcementCamera(6),

  /// Red-light camera.
  redLightCamera(7),

  /// AI camera.
  aiCamera(8),

  /// No left turn (no voice is produced for turn signs yet).
  noLeftTurn(9),

  /// No right turn (no voice is produced for turn signs yet).
  noRightTurn(10),

  /// No U-turn (no voice is produced for turn signs yet).
  noUturn(11),

  /// No overtaking.
  noOvertaking(12),

  /// End of no-overtaking zone.
  noOvertakingEnd(13),

  /// No parking.
  noParking(14),

  /// No straight ahead (no voice is produced for turn signs yet).
  noStraight(15),

  /// Start of built-up area.
  buildupAreaStart(16),

  /// End of built-up area.
  buildupAreaEnd(17),

  /// Rest station.
  restStation(18),

  /// No stopping.
  noStopping(19),

  /// Road closed ahead.
  roadClosed(20),

  /// Road restricted for the configured vehicle type.
  vehicleRestricted(21);

  const VoiceAlertType(this.triggerValue);

  /// Native trigger code; matches the native SDK's `VoiceAlertType`.
  final int triggerValue;
}
