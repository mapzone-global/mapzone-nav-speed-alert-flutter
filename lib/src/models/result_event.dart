import 'map_read.dart';

/// Outcome reported by the native engine: each segment fetch and each failed
/// sign-in on `NavSpeedAlert.onResult`, and the result of
/// `NavSpeedAlert.logout`.
///
/// Branch on [errorCode] (see `AlertViewError`); [errorMessage] is a short
/// English sentence derived from the code alone, meant for logs and fallback
/// UI. Whatever the code, route data already loaded keeps alerting.
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

  /// Whether the segment loaded, or the identity was signed out.
  final bool success;

  /// `0` on success, otherwise an `AlertViewError` code.
  final int errorCode;

  /// Human-readable error, empty on success.
  final String errorMessage;
}
