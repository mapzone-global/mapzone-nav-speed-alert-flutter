# mapzone_nav_speed_alert example

A route-based navigation app: search a destination, build the route, then drive
it (simulated or with real GPS) while the plugin shows speed-limit, camera, toll
and restriction signs and plays voice alerts.

```
pick destination → buildRoute → onRouteBuilt(route)
Start            → startNavigation + NavSpeedAlert.start(route polyline)
progress tick    → NavSpeedAlert.onLocation(snapped position)
reroute          → new route → NavSpeedAlert.start(new polyline)
Stop / arrival   → NavSpeedAlert.reset()
```

## Setup

Credentials are never committed. Provide them locally:

1. **Dart** — copy `env.example.json` to `env.json` and fill in the alert
   service credentials and your VietMap key.
2. **iOS** — copy `ios/Flutter/Secrets.xcconfig.example` to
   `ios/Flutter/Secrets.xcconfig`; set `APP_BUNDLE_ID` to the bundle id
   registered for your alert API key and `VIETMAP_API_KEY` (the navigation SDK
   reads it from `Info.plist`). Then `cd ios && pod install`.
3. **Android** — add `appId=<registered application id>` to
   `android/local.properties`.

The alert service authenticates by the exact application id, so steps 2–3 are
required for alerts to load.

## Run

```sh
flutter run --dart-define-from-file=env.json
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
