# mapzone_nav_speed_alert

Speed-limit, camera, toll and road-restriction alerts with voice **along a
route** for Flutter navigation apps, on Android and iOS.

Your app supplies the route polyline and feeds GPS fixes; the plugin returns
ready-to-draw sign images every tick and plays Vietnamese voice alerts.
It wraps the native MapZone Alert View SDK — Android
`com.github.mapzone-global:mapzone-alert-view-android` and iOS pod
`MapZoneAlertView`, both **1.0.2**.

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

## Installation

```yaml
dependencies:
  mapzone_nav_speed_alert: ^1.0.2
```

### Android

The native SDK is hosted on JitPack. Add the repository to your app's
`android/build.gradle.kts` (or `settings.gradle.kts` if you use
`dependencyResolutionManagement`):

```kotlin
allprojects {
    repositories {
        google()
        mavenCentral()
        maven { url = uri("https://jitpack.io") }
    }
}
```

`minSdk` 24. Declare `INTERNET` and the location permissions your app uses.

### iOS

iOS 13.0+. Run `pod install`; the `MapZoneAlertView` pod is resolved
automatically. Add the location usage descriptions your app needs to
`Info.plist`.

### Application id

The alert service authenticates your app by its **exact** application id
(Android package name / iOS bundle id), resolved natively — you do not pass it.
Build variants with an id suffix (for example `.debug`) are rejected unless that
id is registered for your API key too.

## Quick start

```dart
import 'package:mapzone_nav_speed_alert/mapzone_nav_speed_alert.dart';

final alert = NavSpeedAlert.instance;

await alert.configure(const AlertViewConfig(
  baseUrl: 'https://…',
  apiKeyId: '…',
  apiKey: '…',
  vehicleId: 'vehicle-42',
  vehicleType: 1,        // 1..9, as defined by the alert service
));

final signs = alert.onSigns.listen((e) {
  // e.current, e.next, e.camera, e.toll: PNG bytes or null
  setState(() => _signs = e);
});

await alert.start(routePolyline);   // encoded polyline, precision 1e6

// For every GPS fix (~1 Hz):
await alert.onLocation(LocationFix(
  lat: pos.latitude,
  lng: pos.longitude,
  bearing: pos.heading,
  speedKmh: pos.speed < 0 ? 0 : pos.speed * 3.6,  // -1 = unknown on iOS
  accuracy: pos.accuracy,
));

// Navigation finished:
await alert.reset();
await signs.cancel();
```

Draw a sign with `Image.memory(bytes, gaplessPlayback: true)` — images are
re-rendered every tick, and `gaplessPlayback` avoids flicker.

## API

| Method | Notes |
|---|---|
| `configure(AlertViewConfig)` | Credentials + vehicle profile. Call before `start`. Throws `ArgumentError` for `vehicleType` outside 1..9. |
| `start(polyline)` | Start alerting along a route; call again after a reroute. |
| `onLocation(LocationFix)` | Feed one GPS fix. Faster than ~1 Hz is dropped by the engine. |
| `reset()` | Release route and voice state. |
| `setMutedAlertTypes(Set<VoiceAlertType>)` | Mute voice categories (see below). |
| `setVoiceMode(VoiceMode)` | `full` sentences or `ding` chimes. |
| `setVoiceSpeed(double)` | Built-in player speed, clamped to 0.5–2.0. |
| `setSegmentUrl(url)` | Override the route-data endpoint; `''` restores the default. |
| `setExtraHeaders(map)` / `setExtraBodyFields(map)` | Add headers / body fields to route-data requests. Returns `null` on success or an error message; SDK-owned keys cannot be overridden. |

Settings made with `setMutedAlertTypes`, `setVoiceMode`, `setVoiceSpeed`,
`setSegmentUrl` and the extras persist across routes and `reset()`.

### Streams

| Stream | Payload | When |
|---|---|---|
| `onSigns` | `SignsEvent`: `current`, `next`, `camera`, `toll` images + distances (m) + `speedStatus` | every tick after `start` |
| `onRestriction` | `RestrictionEvent`: `stop`, `closed`, `vehicle`, `bua`, `turn` images + distances, `inBua` | every tick, **only while listened to** — on Android the images are not even rendered otherwise |
| `onVoice` | `VoiceEvent`: `wav` (PCM16 mono 22050 Hz), `trigger`, `priority` | per clip, **only while listened to** — the built-in player is silent for that time |
| `onResult` | `ResultEvent`: `success`, `errorCode`, `errorMessage` | after each route-segment fetch |
| `onReroute` | `RerouteEvent`: `lat`, `lng` | the route was lost |

A distance of `0` means "currently on it". `speedStatus` is `safe`,
`approaching` (within 5 km/h of the limit) or `speeding`.

Error codes in `onResult`: `1001` point outside Vietnam · `1002` missing points ·
`1003` malformed polyline · `2001` device clock off by more than 10 s ·
`3003` vehicle type outside 1..9 · `3004` no road matched · `5000` server error.

### Voice

By default the native SDK plays alerts through a built-in priority queue.
Listen to `onVoice` to play clips yourself; cancel every subscription to hand
playback back to the SDK.

Muting rules:

- Speed-limit and speeding announcements cannot be muted.
- Muting a camera or toll category (`speedCamera`, `trafficEnforcementCamera`,
  `redLightCamera`, `aiCamera`, `toll`) also **hides its sign** — there is a
  single slot for each.
- Muting a restriction category (`noParking`, `noStopping`, `roadClosed`,
  `vehicleRestricted`, `buildupAreaStart`, `buildupAreaEnd`) silences the voice
  only; the sign still shows.

`VoiceMode.ding` replaces sentences with a chime for cameras and
no-parking / no-stopping signs and a distinct chime for speeding; other
announcements are silent. Signs are identical in both modes.

## Limitations

- One Flutter engine should drive the alert: the native engine and its
  callbacks are process-wide. Other engines (e.g. background isolates) may
  load the plugin, but should not call `start` or listen to its streams.
- The plugin does not read GPS or request permissions — the host app does.
- Sign images are PNG-encoded every tick (off the main thread).

## Example

[`example/`](example) is a complete navigation app (map, search, simulated or
real driving) built on `vietmap_flutter_navigation`. See its README for setup.

## License

MIT — see [LICENSE](LICENSE).
