# mapzone_nav_speed_alert

Speed-limit, camera, toll and road-restriction alerts with voice
**along a route**, for Flutter navigation apps on Android and iOS.

Your app signs the user in, supplies the route polyline and feeds GPS fixes;
the plugin returns ready-to-draw sign images on every tick and plays voice
alerts.

> **Upgrading from 1.0.0?** 2.0.0 is a breaking release (native SDK 2.0.1). See [Migrating from 1.0.0 to 2.0.0](#migrating-from-100-to-200).

```
your navigation app                         mapzone_nav_speed_alert
───────────────────                         ──────────────────────
identity + vehicle                  ────────► configure()
route built ──── polyline (precision 1e6) ──► start()
GPS fix ~1 Hz ── lat/lng/bearing/speed ─────► onLocation()
                                              │
UI  ◄── onSigns        speed limit · next · camera · toll (PNG)
UI  ◄── onRestriction  no stopping · closed · vehicle ban · built-up area · turn
    ◄── voice          built-in player, or onVoice for your own player
    ◄── onReroute      route lost → build a new one, call start() again
```

## Requirements

| | Minimum |
|---|---|
| Flutter | 3.32 |
| Dart | 3.8 |
| Android | `minSdk` 24, compiled against SDK 36 |
| iOS | 13.0 |
| Network | Internet access to the alert service |

The plugin does **not** read GPS, request permissions or draw a map — your app
does that and passes positions in.

## Getting an integration key

Contact MapZone on [MapZone](https://zalo.me/3189066936017422854) — and provide:

- the **application id** of every build that will call the service
  (Android package name / iOS bundle id), including debug or flavour ids such
  as `com.example.app.debug` if you run them;
- the kind of vehicles you will configure (see [`vehicleType`](#vehicle-types)).

You will receive the `apiKeyId` and `apiKey` used in
[`AlertViewConfig`](#alertviewconfig).

### Application id

The service authenticates your app by its **exact** application id, resolved
natively — you do not pass it in Dart. A build whose id is not registered for
the key (for example an Android `applicationIdSuffix ".debug"` variant) is
rejected and no signs are delivered. Either register that id as well, or run
the build whose id is registered.

Keep `apiKey` out of source control (e.g. a git-ignored Dart file,
`--dart-define`, or your secrets pipeline).

## Installation

```yaml
dependencies:
  mapzone_nav_speed_alert: ^2.0.0
```

### Android

The native SDK is hosted on JitPack, and Gradle resolves it with **your app's**
repositories, so JitPack must be declared in the app project.

If your project declares repositories in `android/build.gradle.kts`:

```kotlin
allprojects {
    repositories {
        google()
        mavenCentral()
        maven { url = uri("https://jitpack.io") }
    }
}
```

If it uses `dependencyResolutionManagement` in `android/settings.gradle.kts`:

```kotlin
dependencyResolutionManagement {
    repositories {
        google()
        mavenCentral()
        maven { url = uri("https://jitpack.io") }
    }
}
```

Ensure `minSdk` is at least 24 and declare the permissions your app uses in
`android/app/src/main/AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
```

### iOS

Set the platform to iOS 13.0 or later in `ios/Podfile`, then:

```sh
cd ios && pod install
```

The `MapZoneAlertView` pod is resolved automatically. Add the location usage
descriptions your app needs to `ios/Runner/Info.plist`, for example:

```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>Your location is used to show speed limits and road alerts.</string>
```

Add `NSLocationAlwaysAndWhenInUseUsageDescription` and the `location` /
`audio` background modes if you keep navigating with the screen off.

### Store privacy forms

Declare *Device or other IDs* and *Precise
location*, linked to the user, for app functionality (Google Play Data safety /
App Store privacy details). The iOS framework ships its own privacy manifest.

## Integration guide

### 1. Configure — signs the user in

```dart
import 'package:mapzone_nav_speed_alert/mapzone_nav_speed_alert.dart';

final alert = NavSpeedAlert.instance;

try {
  await alert.configure(AlertViewConfig(
    baseUrl: 'https://driving.map.zone', // issued by MapZone; https:// only
    apiKeyId: 'your-api-key-id',           // from MapZone
    apiKey: 'your-api-key',                // from MapZone
    identity: signedInUser.phone,          // who is signed in on this device
    vehicleType: AlertVehicleType.truck,
    weightTons: 15,
    metadata: {'vehicleId': '29A-12345'},  // optional; key names agreed with Vietmap
  ));
} on PlatformException catch (e) {
  // INVALID_CONFIGURATION: an input was rejected (e.message says why).
  // CONFIGURE_FAILED: baseUrl is not https://, or the SDK could not start.
  // Either way nothing was applied.
}
```

Call `configure` **on every app launch** with the user already signed in, and
on every sign-in: the SDK does not remember the identity across launches. Call
it again to switch identity or vehicle. Its failures arrive on `onResult` (see
[Sessions](#sessions-sign-in-and-sign-out)).

#### Identity

The signed-in user — phone number, driver code, … — sent verbatim and matched
exactly: `"0901234567"` and `"+84901234567"` are two different users, so pick
one format and keep it. Non-empty, at most 128 characters, no `"` and no
control characters. Do not use an id shared by several devices (e.g. one
vehicle id for a whole fleet): they would sign each other out with `2006`.

#### Metadata

Optional `Map<String, Object?>` about this device or user, encoded with
`jsonEncode` (a value it cannot encode fails `configure` with
`INVALID_CONFIGURATION`). One JSON object, at most 2048 UTF-8 bytes, nesting
depth at most 16. The SDK adds `"model"` and `"os"` unless you set them. It is
stored **only when a session opens** (first sign-in on the device, or a new
identity): configuring again with the same identity does not update it.

### 2. Listen to the streams

Subscribe before `start` so the first tick is not missed.

```dart
final subs = <StreamSubscription<Object>>[
  alert.onSigns.listen((e) => setState(() => _signs = e)),
  alert.onRestriction.listen((e) => setState(() => _restriction = e)),
  alert.onResult.listen((r) {
    if (!r.success) debugPrint('alert ${r.errorCode}: ${r.errorMessage}');
  }),
  alert.onReroute.listen((_) => _rebuildRoute()),
];
```

Listen to `onRestriction` and `onVoice` only if you need them — see
[Streams](#streams).

### 3. Start along a route

```dart
await alert.start(routePolyline);  // encoded polyline, precision 1e6
```

The polyline must use **precision 1e6** (polyline6), not the common 1e5.

### 4. Feed GPS fixes

Call `onLocation` for every fix, about once per second:

```dart
await alert.onLocation(LocationFix(
  lat: pos.latitude,
  lng: pos.longitude,
  bearing: pos.heading,
  speedKmh: pos.speed < 0 ? 0 : pos.speed * 3.6,  // m/s → km/h; iOS reports -1 when unknown
  accuracy: pos.accuracy,
));
```

Fixes faster than ~1 Hz are dropped by the engine. A position snapped to the
route by your navigation SDK works as well as a raw GPS fix.

### 5. Handle reroutes

When the vehicle leaves the route, `onReroute` fires. Build a new route with
your navigation SDK and call `start(newPolyline)` again — no `reset` needed.

### 6. Stop

```dart
await alert.reset();               // releases route and voice state; stays signed in
for (final s in subs) { await s.cancel(); }
```

### 7. Sign out

```dart
final result = await alert.logout();
if (!result.success) {
  // e.g. offline: the identity is still signed in — call logout() again later.
}
```

## Sessions (sign in and sign out)

```
configure(identity) ──► signed in (the SDK signs in, in the background)
        │                    │ 2006 / 2007 / 2005 / … on onResult, once ──► loading stops
        │                    │                                             (loaded route keeps alerting)
        └── logout() ────────┴─► queued requests finish ─► server sign-out ─► ResultEvent(success)
```

- One identity is active on one device at a time. Signing the same identity in
  on another device moves the session there and this device receives `2006`
  (`AlertViewError.sessionMoved`). Then: tell the user the account is in use on
  another device, call `logout()` (it counts as success), send the user back to
  sign in, and call `configure` again **only after the user signs in** — two
  devices that re-configure on their own keep signing each other out.
- Switching to a **different** identity on the same device is allowed only 20
  minutes after this device last opened a session (`2008` otherwise; the SDK
  resumes by itself).
- After `logout()`, fetches report `-6` (`AlertViewError.notLoggedIn`) until
  the next `configure`. With no `configure` in this process, `logout()`
  succeeds without sending anything.
- A sign-in that fails for network or server reasons does not stop alerts on
  data already loaded.

### Drawing signs

Every image is PNG bytes; `null` means the slot is empty. Images are re-rendered
every tick, so use `gaplessPlayback` to avoid flicker:

```dart
Widget sign(Uint8List? png, {double size = 64}) => png == null
    ? const SizedBox.shrink()
    : Image.memory(png, width: size, height: size, gaplessPlayback: true);

Row(children: [
  sign(_signs?.current, size: 80),
  sign(_signs?.next),
  if ((_signs?.nextDistMeters ?? 0) > 0) Text('${_signs!.nextDistMeters} m'),
  sign(_signs?.camera),
  sign(_signs?.toll),
]);
```

Use `speedStatus` to colour your own speedometer — `safe`, `approaching`
(within 5 km/h of the limit) or `speeding`.

## Configuration reference

### AlertViewConfig

| Field | Type | Required | Description |
|---|---|---|---|
| `baseUrl` | `String` | yes | Service base URL, from MapZone; must start with `https://`. |
| `apiKeyId` | `String` | yes | API key id issued for your application id. |
| `apiKey` | `String` | yes | API key secret. |
| `identity` | `String` | yes | Who is signed in on this device, see [Identity](#identity). |
| `vehicleType` | `AlertVehicleType` | yes | See below. |
| `seats` | `int` | no | Number of seats (coaches), 0 or more; `0` = default for the type. |
| `weightTons` | `double` | no | Gross weight in **tonnes** (trucks), 0 or more; `0` = default for the type. |
| `maxSnapMeters` | `double` | no | Max distance (m) a fix may be from the route and still snap to it; `<= 0` = service default (~25 m). |
| `metadata` | `Map<String, Object?>?` | no | See [Metadata](#metadata). |

### Vehicle types

`AlertVehicleType.value` is the service's own code, sent unchanged — the same
numbers as the native SDK.

| `AlertVehicleType` | Code | Vehicle |
|---|---|---|
| `car` | 1 | Car |
| `taxi` | 2 | Taxi |
| `bus` | 3 | Bus |
| `coach` | 4 | Coach |
| `truck` | 5 | Truck |
| `motorcycle` | 7 | Motorcycle |

The type, seats and weight decide which speed limits and vehicle bans apply;
the type also picks the artwork of the vehicle-restricted sign. The type must
be enabled for your API key (`3003` otherwise). `AlertVehicleType.fromValue`
returns `null` for a code the SDK does not offer.

### LocationFix

| Field | Unit | Notes |
|---|---|---|
| `lat`, `lng` | degrees (WGS84) | |
| `bearing` | degrees | `0` = north, `90` = east. |
| `speedKmh` | km/h | Never negative. |
| `accuracy` | m | Horizontal accuracy; default `0`. |
| `fixTimeMillis` | ms since epoch (UTC) | Defaults to now. |

## API reference

### Methods

| Method | Description |
|---|---|
| `configure(AlertViewConfig)` | Credentials + vehicle profile; signs the identity in. Call before `start`, on every launch. |
| `logout()` → `Future<ResultEvent>` | Sign the identity out of this device. |
| `start(String polyline)` | Start alerting along a route (precision 1e6). Call again after a reroute. |
| `onLocation(LocationFix)` | Feed one GPS fix (~1 Hz). |
| `reset()` | Release route and voice state, e.g. when navigation ends. Stays signed in. |
| `setMutedAlertTypes(Set<VoiceAlertType>)` | Mute voice categories; empty set = announce everything. |
| `setVoiceMode(VoiceMode)` | `full` sentences or `ding` chimes. |
| `setVoiceSpeed(double)` | Built-in player speed, `1.0` = recorded, clamped to `0.5..2.0`, pitch kept. No effect while `onVoice` has a listener. |
| `setSegmentUrl(String)` | Override the route-data (segment) endpoint only (`https://`); `''` restores the default derived from `baseUrl`. |
| `setExtraHeaders(Map<String, String>)` | Add HTTP headers to segment requests. |
| `setExtraBodyFields(Map<String, String>)` | Add string fields to segment request bodies. |

**Errors.** Every method that takes configuration reports a rejected input the
same way — it throws `PlatformException` and applies nothing:

| Method | `code` | When |
|---|---|---|
| `configure` | `INVALID_CONFIGURATION` | The SDK rejected an input (`message` says why), or `metadata` cannot be JSON-encoded. The previous configuration stays in effect. |
| `configure` | `CONFIGURE_FAILED` | `baseUrl` is not `https://`, or the SDK could not start in this process. |
| `setSegmentUrl`, `setExtraHeaders`, `setExtraBodyFields` | `INVALID_CONFIGURATION` | The value was rejected (`message` says why); the previous value is kept. |

Server and network outcomes are never thrown: they arrive on `onResult`, and
`logout()` returns them.

`setSegmentUrl`, `setExtraHeaders` and `setExtraBodyFields` should be called
after `configure` and before `start`. A segment URL must be `https://`; a proxy
behind it must forward to `<baseUrl>/speed/v2/tracking/network/packed`
and pass the status, the body and `Retry-After` through unchanged (the SDK does
not follow redirects). Extras reject a reserved, empty or multi-line key/value;
SDK-owned keys (including `identity`, `deviceId`, `refId`, `deviceMeta`,
`metadata`) cannot be overridden. Pass `{}` to clear.

Settings made with `setMutedAlertTypes`, `setVoiceMode`, `setVoiceSpeed`,
`setSegmentUrl` and the extras **persist** across routes and `reset()`.

### Streams

| Stream | Payload | When |
|---|---|---|
| `onSigns` | `SignsEvent` | Every tick after `start`. |
| `onRestriction` | `RestrictionEvent` | Every tick, **only while listened to** — on Android the images are not rendered at all otherwise. |
| `onVoice` | `VoiceEvent` | Per clip, **only while listened to** — the built-in player is silent for that time. |
| `onResult` | `ResultEvent` | After each sign-in failure and route-segment fetch. |
| `onReroute` | `RerouteEvent` | The vehicle has left the route. |

Distances are in metres. A distance of `0` means "currently on it".

#### SignsEvent

| Field | Type | Description |
|---|---|---|
| `current` | `Uint8List?` | Current speed-limit sign; `null` when no road is matched. |
| `speedStatus` | `SpeedStatus` | `safe`, `approaching` (within 5 km/h) or `speeding`. |
| `next` / `nextDistMeters` | `Uint8List?` / `int` | Next speed-limit sign ahead and its distance. |
| `camera` / `cameraDistMeters` | `Uint8List?` / `int` | Nearest camera ahead; the artwork shows the camera kind. |
| `toll` / `tollDistMeters` | `Uint8List?` / `int` | Nearest toll booth ahead. |

#### RestrictionEvent

The slots are independent: one stretch of road can be in a built-up area,
closed to your vehicle and no-stopping at once.

| Field | Type | Description |
|---|---|---|
| `stop` / `stopDistMeters` | `Uint8List?` / `int` | No-parking / no-stopping sign. |
| `closed` / `closedDistMeters` | `Uint8List?` / `int` | Road-closed sign. |
| `vehicle` / `vehicleDistMeters` | `Uint8List?` / `int` | Road closed to the configured vehicle type. |
| `bua` / `buaDistMeters` | `Uint8List?` / `int` | Built-up-area sign: shown while inside the area, then an end-of-area sign for a few seconds after leaving. |
| `inBua` | `bool` | Whether the vehicle is inside a built-up area. |
| `turn` / `turnDistMeters` | `Uint8List?` / `int` | Turn restriction (banned or mandatory manoeuvre). |

#### VoiceEvent

| Field | Type | Description |
|---|---|---|
| `wav` | `Uint8List` | WAV clip, PCM 16-bit mono 22050 Hz. |
| `trigger` | `int` | Native trigger code of the announcement (see `VoiceAlertType.triggerValue`). |
| `priority` | `int` | `0` current speed (lowest), `1` normal, `2` speeding. |

#### ResultEvent and RerouteEvent

`ResultEvent`: `success`, `errorCode`, `errorMessage` (a short English
sentence derived from the code, empty on success) — see
[Error codes](#error-codes). `RerouteEvent`: `lat`, `lng` of the position where
the route was lost.

## Voice alerts

### Built-in player or your own

By default the native SDK plays alerts through a built-in priority queue —
nothing to do. To play clips yourself (mixing with other audio, custom
ducking…), listen to `onVoice`:

```dart
final voiceSub = alert.onVoice.listen((v) => myPlayer.play(v.wav, v.priority));
// Later: cancel every onVoice subscription to hand playback back to the SDK.
await voiceSub.cancel();
```

Use `priority` to decide whether a new clip interrupts the current one.

### Voice mode

```dart
await alert.setVoiceMode(VoiceMode.ding);
```

- `VoiceMode.full` (default): full spoken sentences.
- `VoiceMode.ding`: a chime for cameras and no-parking / no-stopping signs, a
  distinct chime for speeding, silence for everything else.

On-screen signs are identical in both modes.

### Muting categories

```dart
await alert.setMutedAlertTypes({VoiceAlertType.toll, VoiceAlertType.noParking});
```

- Speed-limit and speeding announcements **cannot** be muted.
- Muting a camera or toll category **also hides its sign** — there is a single
  slot for each.
- Muting a restriction category silences the voice only; the sign still shows.

| `VoiceAlertType` | Code | Muting also hides the sign |
|---|---|---|
| `speedCamera` | 3 | yes |
| `toll` | 4 | yes |
| `trafficEnforcementCamera` | 6 | yes |
| `redLightCamera` | 7 | yes |
| `aiCamera` | 8 | yes |
| `noLeftTurn`, `noRightTurn`, `noUturn`, `noStraight` | 9, 10, 11, 15 | no (no voice is produced for turn signs yet) |
| `noOvertaking`, `noOvertakingEnd` | 12, 13 | no |
| `noParking`, `noStopping` | 14, 19 | no |
| `buildupAreaStart`, `buildupAreaEnd` | 16, 17 | no |
| `restStation` | 18 | no |
| `roadClosed` | 20 | no |
| `vehicleRestricted` | 21 | no |

## Error codes

Reported in `ResultEvent.errorCode` — on `onResult` and by `logout()`. Branch
on the exact code with the `AlertViewError` constants: ranges such as
`2000`–`2999` no longer have one single meaning. Whatever the code, route data
already loaded **keeps alerting**; a route passed to `start()` while loading is
stopped waits, and loads by itself once loading resumes.

| Code | `AlertViewError` | Meaning | What the SDK does |
|---|---|---|---|
| `0` | `ok` | Segment loaded, or signed out | — |
| `-1` | `verifyFailed` | The server response could not be verified | Reports |
| `-2` | `dataInvalid` | Route data unavailable or invalid (route with fewer than 2 points, unexpected proxy status) | Reports |
| `-3` | `sessionFailed` | Request session not set up yet; nothing was sent | Retries while you keep calling `onLocation` |
| `-4` | `networkFailed` | Server unreachable | Reports |
| `-5` | `bridgeFailed` | The SDK could not complete the request on this device | Reports |
| `-6` | `notLoggedIn` | Nobody signed in (`logout` ran, or `configure` never did) | Stops until `configure` |
| `-7` | `noRouteData` | No data for this stretch of the route | Retries that route after 30 / 60 / 120 s |
| `-8` | `deviceNotReady` | The device cannot be read yet; `logout` cannot close the session | Re-reads about once a minute — show a notice |
| `1001` | `invalidParameter` | Request rejected, or route outside Vietnam | From sign-in: stops until `configure` (check `identity`, `vehicleType`); on a route: retries that route |
| `1002` | `missingParameter` | Missing information in the request | Stops until `configure` |
| `2000` | `requestExpired` | Device clock more than 10 s off | Reports — enable automatic date & time |
| `2002` | `invalidSignature` | Request signature not accepted | Stops until `configure` |
| `2003` | `unauthorized` | API key unknown or disabled | Stops until `configure` |
| `2004` | `forbidden` | Application id not registered for the key | Stops until `configure` |
| `2005` | `planExpired` | Service plan expired | Stops until `configure` |
| `2006` | `sessionMoved` | Identity now in use on another device — see [Sessions](#sessions-sign-in-and-sign-out) | Stops until `configure` |
| `2007` | `locked` | Device or identity locked by an administrator | Stops until `configure` |
| `2008` | `switchTooSoon` | Account on this device changed too recently | Pauses 20 minutes, then resumes |
| `2009` | `tooManyNewSessions` | Too many new sessions for the key right now | Waits, then resumes |
| `2010` | `trialIdentityNotAllowed` | Trial key: identity not one of its sample identities | Stops until `configure` |
| `3003` | `vehicleTypeNotAllowed` | Vehicle type not enabled for the key | Stops until `configure` |
| `3011` | `enterprisePlanRequired` | Device limit of the key reached (older servers) | Stops until `configure` |
| `3012` | `newDeviceLimit` | The key cannot register more new devices | Stops until `configure` |
| `4000` | `tooManyRequests` | Too many requests | Waits for `Retry-After` (at most 600 s), then resumes |
| `4001` | `requestQuotaExceeded` | Request quota used up | Stops until `configure` |
| `5000` | `internalError` | Server error | Waits, then resumes |
| `5004` | `serviceStarting` | Service starting up | Waits, then resumes |

`start()` always gets an answer; while driving, a stop or wait code is reported
**once per episode**, not on every tick. Unlisted codes read as the generic
message of their thousand-range.

Using this plugin together with `mapzone_speed_alert`? Both export
`RestrictionEvent`, `SpeedStatus`, `VoiceAlertType` and `VoiceEvent`; import
one of them with a prefix:

```dart
import 'package:mapzone_nav_speed_alert/mapzone_nav_speed_alert.dart' as nav;
```

## Migrating from 1.0.0 to 2.0.0

2.0.0 moves to native SDK 2.0.1 (Android `2.0.1`, iOS `2.0.1`). Streams,
`start`, `onLocation`, `reset`, muting, voice mode and voice speed are
unchanged.

```
  1.0.0                                            2.0.0
  ─────                                            ─────
  AlertViewConfig(vehicleId:, vehicleType: 3,  ──► AlertViewConfig(identity:, vehicleType: AlertVehicleType.truck,
                  weights: 15)                                     weightTons: 15, metadata:)
  configure → ArgumentError (type outside 1..9) ──► configure → PlatformException(INVALID_CONFIGURATION | CONFIGURE_FAILED)
  setExtraHeaders / setExtraBodyFields          ──► Future<void>; a rejection throws PlatformException(INVALID_CONFIGURATION)
    → Future<String?> (error message)
  setSegmentUrl → never fails                   ──► throws PlatformException(INVALID_CONFIGURATION); https only
  (no sign-out)                                 ──► logout() on sign-out and after 2006
  ranges 2000–2999 = "session expired"          ──► exact codes, AlertViewError
```

1. `pubspec.yaml`: `mapzone_nav_speed_alert: ^2.0.0`; iOS:
   `cd ios && pod update MapZoneAlertView`.
2. **`vehicleId` → `identity`.** Pass who is signed in on this device (see
   [Identity](#identity)), on every sign-in and every app launch. If you still
   need the old vehicle id, send it in `metadata` (agree the key name with
   Vietmap); unlike 1.0.0 it is stored only when a session opens.
3. **`weights` → `weightTons`**, same unit (tonnes).
4. **Vehicle types:** `vehicleType` is now an `AlertVehicleType`, and four
   numbers changed. If you stored the old number, convert it with this table —
   do **not** call `AlertVehicleType.fromValue(oldNumber)` (`fromValue(3)` is
   now `bus`):

   | Vehicle | 1.0.0 | 2.0.0 |
   |---|---|---|
   | Car | `1` | `AlertVehicleType.car` (1) |
   | Motorcycle | `2` | `AlertVehicleType.motorcycle` (**7**) |
   | Truck | `3` | `AlertVehicleType.truck` (**5**) |
   | Coach | `4` | `AlertVehicleType.coach` (4) |
   | Bus | `5` | `AlertVehicleType.bus` (**3**) |
   | Taxi | `6` | `AlertVehicleType.taxi` (**2**) |
   | Bicycle / pedestrian / emergency | `7` / `8` / `9` | removed — contact Vietmap |

5. **`baseUrl`** is the gateway address issued by MapZone and must start with
   `https://`. If you proxy route data with `setSegmentUrl`, forward to the new
   path `<baseUrl>/speed/v2/tracking/network/packed`.
6. **Errors:** catch `PlatformException` from `configure`, `setSegmentUrl`,
   `setExtraHeaders` and `setExtraBodyFields` (see [Methods](#methods)); the
   last two no longer return a message. In `onResult`, branch on exact codes
   (`AlertViewError`): `2001` is now `2000`, `1003` / `3004` are no longer
   used, and `2006`, `2007`, `2008`, `-6`, `-8` need handling in your UI.
7. **Sign out:** call `logout()` when the user signs out, and after `2006`.
8. **Store privacy forms:** see [Store privacy forms](#store-privacy-forms).

## Support

- Integration key and commercial questions: [MapZone](https://zalo.me/3189066936017422854)
- Bugs and feature requests:
  [GitHub issues](https://github.com/mapzone-global/mapzone-nav-speed-alert-flutter/issues)

## License

MIT — see [LICENSE](LICENSE).
