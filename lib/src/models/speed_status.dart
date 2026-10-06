/// How the current speed compares with the current speed limit.
enum SpeedStatus {
  /// Within the limit.
  safe,

  /// Within 5 km/h of the limit.
  approaching,

  /// Over the limit.
  speeding;

  /// Maps the native code (`0`, `1`, `2`) to a status; unknown codes are [safe].
  static SpeedStatus fromCode(int code) => switch (code) {
    1 => approaching,
    2 => speeding,
    _ => safe,
  };
}
