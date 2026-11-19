import 'dart:convert';

import 'alert_vehicle_type.dart';

/// Credentials, signed-in identity and vehicle profile for the native engine.
///
/// Passing it to `NavSpeedAlert.configure` signs [identity] in on this
/// device. Call `configure` on every sign-in **and** on every app launch with a
/// user already signed in: the SDK does not remember the identity across
/// launches.
///
/// The application id (Android package name / iOS bundle id) is resolved
/// natively and must match the id registered for [apiKeyId] exactly — builds
/// with an id suffix such as `.debug` are rejected by the service.
class AlertViewConfig {
  /// Creates a configuration.
  const AlertViewConfig({
    required this.baseUrl,
    required this.apiKeyId,
    required this.apiKey,
    required this.identity,
    required this.vehicleType,
    this.seats = 0,
    this.weightTons = 0,
    this.maxSnapMeters = 0,
    this.metadata,
  });

  /// Service base URL: the gateway address issued by MapZone. Must be
  /// `https://`.
  final String baseUrl;

  /// API key id issued for this application.
  final String apiKeyId;

  /// API key secret issued for this application.
  final String apiKey;

  /// Who is signed in on this device — typically the account's phone number
  /// or driver code. Sent verbatim and matched exactly: `"0901234567"` and
  /// `"+84901234567"` are two different users, so pick one format and keep
  /// it. Non-empty, at most 128 characters, no `"` and no control characters.
  ///
  /// One identity is active on one device at a time: signing it in elsewhere
  /// moves the session there and this device receives
  /// `AlertViewError.sessionMoved`.
  final String identity;

  /// Vehicle type; also picks the vehicle-restricted sign artwork.
  final AlertVehicleType vehicleType;

  /// Number of seats, 0 or more; `0` uses the default for [vehicleType].
  final int seats;

  /// Vehicle gross weight in **tonnes** (e.g. `15`), 0 or more; `0` uses the
  /// default for [vehicleType].
  final double weightTons;

  /// Maximum distance (m) a GPS fix may be from the route and still snap to
  /// it; `<= 0` uses the service default (about 25 m).
  final double maxSnapMeters;

  /// Optional information about this device / user (app version, your
  /// internal vehicle id, …), stored with the session when it is opened.
  /// Agree the key names with Vietmap. The SDK adds `"model"` and `"os"`
  /// unless you set them.
  ///
  /// Encoded as one JSON object, at most 2048 UTF-8 bytes, nesting depth at
  /// most 16. Recorded only when a session opens (first sign-in on the device,
  /// or a new identity): configuring again with the same identity keeps the
  /// metadata stored at sign-in.
  final Map<String, Object?>? metadata;

  /// Serialises this configuration for the platform channel. [metadata]
  /// travels as its JSON text, which the native SDK validates; `null` means
  /// none. Throws `JsonUnsupportedObjectError` when [metadata] holds a value
  /// `jsonEncode` cannot encode.
  Map<String, Object?> toMap() => {
    'baseUrl': baseUrl,
    'apiKeyId': apiKeyId,
    'apiKey': apiKey,
    'identity': identity,
    'vehicleType': vehicleType.value,
    'seats': seats,
    'weightTons': weightTons,
    'maxSnapMeters': maxSnapMeters,
    'metadata': metadata == null ? null : jsonEncode(metadata),
  };
}
