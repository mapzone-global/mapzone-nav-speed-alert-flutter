# mapzone_nav_speed_alert

Speed-limit, camera, toll and road-restriction alerts with voice
**along a route**, for Flutter navigation apps on Android and iOS.

Your app supplies the route polyline and feeds GPS fixes; the plugin returns
ready-to-draw sign images on every tick and plays voice alerts.

```
your navigation app                         mapzone_nav_speed_alert
───────────────────                         ──────────────────────
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
  mapzone_nav_speed_alert: ^1.0.0
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

## Integration guide

### 1. Configure once

```dart
import 'package:mapzone_nav_speed_alert/mapzone_nav_speed_alert.dart';

final alert = NavSpeedAlert.instance;

await alert.configure(const AlertViewConfig(
  baseUrl: 'https://…',        // from MapZone
  apiKeyId: 'your-api-key-id',               // from MapZone
  apiKey: 'your-api-key',                 // from MapZone
  vehicleId: 'your-vehicle-id',     // your own identifier for this vehicle
  vehicleType: 1,              // 1 = car, see "Vehicle types"
));
```

`configure` throws `ArgumentError` when `vehicleType` is outside `1..9` and a
`PlatformException` when the native SDK cannot initialise. Call it again to
change the vehicle profile.

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
await alert.reset();               // releases route and voice state
for (final s in subs) { await s.cancel(); }
```

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
| `baseUrl` | `String` | yes | Service base URL, from MapZone. |
| `apiKeyId` | `String` | yes | API key id issued for your application id. |
| `apiKey` | `String` | yes | API key secret. |
| `vehicleId` | `String` | yes | Your identifier for the vehicle. |
| `vehicleType` | `int` | yes | Vehicle class `1..9`, see below. |
| `seats` | `int` | no | Number of seats (coaches); `0` = default for the type. |
| `weights` | `double` | no | Gross weight in **tonnes** (trucks); `0` = default for the type. |
| `maxSnapMeters` | `double` | no | Max distance (m) a fix may be from the route and still snap to it; `<= 0` = service default (~25 m). |

### Vehicle types

| `vehicleType` | Vehicle |
|---|---|
| 1 | Car |
| 2 | Motorcycle |
| 3 | Truck |
| 4 | Coach |
| 5 | Bus |
| 6 | Taxi |
| 7 | Bicycle |
| 8 | Pedestrian |
| 9 | Emergency / priority vehicle |

The type, seats and weight decide which speed limits and vehicle bans apply.

### LocationFix

| Field | Unit | Notes |
|---|---|---|
| `lat`, `lng` | degrees (WGS84) | |
| `bearing` | degrees | `0` = north, `90` = east. |
| `speedKmh` | km/h | Never negative. |
| `accuracy` | m | Horizontal accuracy; default `0`. |
| `fixTimeMillis` | ms since epoch (UTC) | Defaults to now. |

## API reference

All members are on `NavSpeedAlert.instance`.

### Methods

| Method | Description |
|---|---|
| `configure(AlertViewConfig)` | Credentials + vehicle profile. Call before `start`. |
| `start(String polyline)` | Start alerting along a route (precision 1e6). Call again after a reroute. |
| `onLocation(LocationFix)` | Feed one GPS fix (~1 Hz). |
| `reset()` | Release route and voice state, e.g. when navigation ends. |
| `setMutedAlertTypes(Set<VoiceAlertType>)` | Mute voice categories; empty set = announce everything. |
| `setVoiceMode(VoiceMode)` | `full` sentences or `ding` chimes. |
| `setVoiceSpeed(double)` | Built-in player speed, `1.0` = recorded, clamped to `0.5..2.0`, pitch kept. No effect while `onVoice` has a listener. |
| `setSegmentUrl(String)` | Override the route-data (segment) endpoint only; `''` restores the default derived from `baseUrl`. |
| `setExtraHeaders(Map<String, String>)` | Add HTTP headers to segment requests. |
| `setExtraBodyFields(Map<String, String>)` | Add string fields to segment request bodies. |

`setExtraHeaders` and `setExtraBodyFields` should be called after `configure`
and before `start`. They return `null` on success, or an error message — for a
reserved, empty or multi-line key/value — in which case the previous values are
kept. SDK-owned keys cannot be overridden. Pass `{}` to clear.

Settings made with `setMutedAlertTypes`, `setVoiceMode`, `setVoiceSpeed`,
`setSegmentUrl` and the extras **persist** across routes and `reset()`.

### Streams

| Stream | Payload | When |
|---|---|---|
| `onSigns` | `SignsEvent` | Every tick after `start`. |
| `onRestriction` | `RestrictionEvent` | Every tick, **only while listened to** — on Android the images are not rendered at all otherwise. |
| `onVoice` | `VoiceEvent` | Per clip, **only while listened to** — the built-in player is silent for that time. |
| `onResult` | `ResultEvent` | After each route-segment fetch. |
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

`ResultEvent`: `success`, `errorCode`, `errorMessage` (empty on success) — see
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

Reported in `ResultEvent.errorCode` after a route-segment fetch.

| Code | Meaning | What to check |
|---|---|---|
| `1001` | Point outside Vietnam | The route or position is outside coverage. |
| `1002` | Missing points | The polyline is empty or too short. |
| `1003` | Malformed polyline | Encode with precision **1e6**. |
| `2001` | Device clock off by more than 10 s | Enable automatic date & time on the device. |
| `3003` | Vehicle type outside `1..9` | `AlertViewConfig.vehicleType`. |
| `3004` | No road matched | The route does not follow mapped roads. |
| `5000` | Server error | Retry later; contact MapZone if it persists. |

## Example app

[`example/`](example) is a complete navigation app (map, search, simulated or
real driving) built on `vietmap_flutter_navigation`. See
[example/README.md](example/README.md) for setup.

## Support

- Integration key and commercial questions: [MapZone](https://zalo.me/3189066936017422854)
- Bugs and feature requests:
  [GitHub issues](https://github.com/mapzone-global/mapzone-nav-speed-alert-flutter/issues)

## License

MIT — see [LICENSE](LICENSE).
