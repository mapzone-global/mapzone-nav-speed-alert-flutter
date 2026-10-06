# mapzone_nav_speed_alert example

A route-based navigation app: search a destination, build the route, then drive
it (simulated or with real GPS) while the plugin shows speed-limit, camera, toll
and restriction signs and plays voice alerts.

## Setup

You need two sets of credentials:

- **MapZone alert key** (`apiKeyId`, `apiKey`, `vehicleId`) registered for the
  application id you will run — contact [MapZone](https://zalo.me/3189066936017422854).
- **VietMap API key** for the map, routing and search.

Credentials are never committed. Provide them locally:

1. **Dart** — copy `lib/env.example.dart` to `lib/env.dart` (git-ignored) and
   fill in `baseUrl`, `apiKeyId`, `apiKey`, `vehicleId` and `vietmapApiKey`.

   ```sh
   cp lib/env.example.dart lib/env.dart
   ```

2. **iOS** — copy `ios/Flutter/Secrets.xcconfig.example` to
   `ios/Flutter/Secrets.xcconfig` (git-ignored); set `APP_BUNDLE_ID` to the
   bundle id registered for your alert key and `VIETMAP_API_KEY` (the
   navigation SDK reads it from `Info.plist`). Then:

   ```sh
   cd ios && pod install
   ```

3. **Android** — set `applicationId` in `android/app/build.gradle.kts` to the
   application id registered for your alert key.

The alert service authenticates by the exact application id, so steps 2–3 are
required for alerts to load.

## Run

```sh
flutter run
```

Settings (gear button): vehicle profile, simulation on/off and simulation speed
multiplier. Voice sheet (speaker button): built-in player vs app playback
(`onVoice`), full sentences vs chimes, playback speed and per-category mute.

## Notes

- On iOS, `vietmap_flutter_navigation` does not expose the route geometry, so
  the example fetches the same route from the VietMap route API to get the
  polyline for the alert (`lib/services/route_polyline.dart`). That request
  always takes the API's first path and may differ slightly from the route
  being navigated (for example after picking an alternative route), which can
  trigger an early reroute.
- Set your Apple development team in Xcode before running on a device.
- In simulation the replayed speed is replaced by 45 km/h × multiplier so that
  speeding can be exercised.
