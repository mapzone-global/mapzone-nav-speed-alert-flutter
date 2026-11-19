/// Result codes reported through `ResultEvent.errorCode` — on the `onResult`
/// stream and by `NavSpeedAlert.logout`.
///
/// The values are the native SDK 2.0.0 codes; the names follow the native
/// `AlertViewError` (Android / iOS) where it has one. Branch on the exact
/// code: ranges such as `2000`–`2999` no longer have one single meaning.
/// Whatever the code, route data already loaded keeps alerting; codes that
/// stop or pause loading are reported once per episode, not on every GPS fix.
abstract final class AlertViewError {
  /// Success — segment data loaded, or signed out.
  static const int ok = 0;

  // ── Local (negative) ──────────────────────────────────────────────────────

  /// The server response could not be verified.
  static const int verifyFailed = -1;

  /// Route data unavailable or invalid (also: the route passed to `start` has
  /// fewer than 2 points, or a proxy answered with an unexpected HTTP status).
  static const int dataInvalid = -2;

  /// The request session could not be set up yet; nothing was sent. The SDK
  /// retries on its own while GPS fixes keep arriving.
  static const int sessionFailed = -3;

  /// The server could not be reached.
  static const int networkFailed = -4;

  /// The SDK could not complete the request on this device.
  static const int bridgeFailed = -5;

  /// Nobody is signed in: `logout` ran, or `configure` never did. Loading
  /// stops until `configure`.
  static const int notLoggedIn = -6;

  /// The service has no data for this stretch of the route; the SDK retries
  /// that route after 30 / 60 / 120 s.
  static const int noRouteData = -7;

  /// The device cannot be read yet, so nothing is fetched and `logout` cannot
  /// close the session. The SDK re-reads it about once a minute; show a
  /// notice. Reported once per episode.
  static const int deviceNotReady = -8;

  // ── Server ────────────────────────────────────────────────────────────────

  /// Request rejected, or the route is outside the supported area (Vietnam).
  /// From signing in, loading stops until `configure` (check `identity` and
  /// `vehicleType`); on a route request the SDK retries that route.
  static const int invalidParameter = 1001;

  /// Missing information in the request; loading stops until `configure`.
  static const int missingParameter = 1002;

  /// The device clock is more than 10 s off the server's — fix the time.
  static const int requestExpired = 2000;

  /// The request signature was not accepted.
  static const int invalidSignature = 2002;

  /// The API key is unknown or disabled.
  static const int unauthorized = 2003;

  /// The application id is not registered for the API key.
  static const int forbidden = 2004;

  /// The service plan has expired.
  static const int planExpired = 2005;

  /// The identity is now in use on another device. Show a notice, call
  /// `logout` and send the user back to sign in; call `configure` again only
  /// after the user signs in.
  static const int sessionMoved = 2006;

  /// The device or identity was locked by an administrator.
  static const int locked = 2007;

  /// The account on this device changed too recently; loading pauses for 20
  /// minutes, then resumes on its own.
  static const int switchTooSoon = 2008;

  /// Too many new sessions for the API key right now; the SDK backs off.
  static const int tooManyNewSessions = 2009;

  /// Trial API key: the identity is not one of the key's sample identities.
  static const int trialIdentityNotAllowed = 2010;

  /// The vehicle type is not enabled for the API key.
  static const int vehicleTypeNotAllowed = 3003;

  /// Device limit of the API key reached (older servers).
  static const int enterprisePlanRequired = 3011;

  /// The API key cannot register more new devices.
  static const int newDeviceLimit = 3012;

  /// Too many requests; the SDK waits for the server's `Retry-After`.
  static const int tooManyRequests = 4000;

  /// The API key's request quota is used up.
  static const int requestQuotaExceeded = 4001;

  /// Server error; the SDK backs off.
  static const int internalError = 5000;

  /// The service is starting up; the SDK backs off.
  static const int serviceStarting = 5004;
}
