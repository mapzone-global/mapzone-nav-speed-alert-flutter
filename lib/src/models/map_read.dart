import 'dart:typed_data';

/// Tolerant readers for platform-channel event maps. Not exported.
///
/// The standard codec may deliver integers as `int` or `double` depending on
/// the platform, and an absent slot as a missing key or `null`.
extension MapRead on Map<Object?, Object?> {
  /// PNG / WAV bytes, or `null` when the slot is empty.
  Uint8List? bytes(String key) {
    final v = this[key];
    return v is Uint8List ? v : null;
  }

  /// Integer value, `0` when absent.
  int integer(String key) => (this[key] as num?)?.toInt() ?? 0;

  /// Double value, `0` when absent.
  double float(String key) => (this[key] as num?)?.toDouble() ?? 0;

  /// Boolean value, `false` when absent.
  bool flag(String key) => this[key] == true;

  /// String value, empty when absent.
  String text(String key) => this[key] as String? ?? '';
}
