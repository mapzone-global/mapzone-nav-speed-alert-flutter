import 'map_read.dart';

/// Outcome of fetching one route segment, from `NavSpeedAlert.onResult`.
///
/// Error codes: `1001` point outside Vietnam, `1002` missing points, `1003`
/// malformed polyline, `2001` device clock off by more than 10 s, `3003`
/// vehicle type outside 1..9, `3004` no road matched, `5000` server error.
class ResultEvent {
  /// Creates an event.
  const ResultEvent({
    required this.success,
    required this.errorCode,
    required this.errorMessage,
  });

  /// Decodes the platform-channel payload.
  factory ResultEvent.fromMap(Map<Object?, Object?> m) => ResultEvent(
    success: m.flag('success'),
    errorCode: m.integer('errorCode'),
    errorMessage: m.text('errorMessage'),
  );

  /// Whether the segment loaded.
  final bool success;

  /// `0` on success, otherwise a service or transport error code.
  final int errorCode;

  /// Human-readable error, empty on success.
  final String errorMessage;
}
