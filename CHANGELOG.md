## 2.0.0

Native SDK 2.0.1: signed-in accounts. See the README section *Migrating from
1.0.0 to 2.0.0*.

**Breaking**

* `AlertViewConfig.vehicleId` → `identity` (who is signed in on this device).
  `configure` signs it in; call it on every sign-in and every app launch.
* `AlertViewConfig.vehicleType` is an `AlertVehicleType` instead of an `int`,
  with the service's codes: `car` 1, `taxi` 2, `bus` 3, `coach` 4, `truck` 5,
  `motorcycle` 7. Bicycle, pedestrian and emergency (old `7`–`9`) are removed.
* `AlertViewConfig.weights` → `weightTons` (same unit, tonnes).
* `configure` throws `PlatformException(INVALID_CONFIGURATION)` with the SDK's
  reason when an input is rejected (nothing is applied), and
  `PlatformException(CONFIGURE_FAILED)` when `baseUrl` is not `https://` or the
  SDK cannot start. It no longer throws `ArgumentError`.
* `setExtraHeaders` / `setExtraBodyFields` return `Future<void>` and throw
  `PlatformException(INVALID_CONFIGURATION)` on a rejected value, instead of
  returning the message. `setSegmentUrl` throws the same way and accepts
  `https` URLs only.
* Error codes follow the native 2.0.0 table: `2001` → `2000`, `1003` and
  `3004` are no longer used, and the `2000`–`2999` range no longer means
  "session expired" as a whole.

**Added**

* `logout()` → `Future<ResultEvent>`: signs the identity out of this device.
* `AlertViewConfig.metadata` (`Map<String, Object?>?`), JSON-encoded in Dart
  and stored with the session when it opens.
* `AlertVehicleType` and `AlertViewError` (every code of the native 2.0.0
  table, including the session codes `2006`, `2007`, `2008`, `2010`, `3012`,
  `4001`, `-6`, `-7`, `-8`). The names follow the native SDK, so they do not
  collide with `mapzone_speed_alert`.
* Road-closed and vehicle-restricted signs in `onRestriction` (`closed`,
  `vehicle`), drawn for the configured vehicle type by the native SDK.

**Changed**

* Native SDK: Android `mapzone-alert-view-android` `2.0.1` (JitPack), iOS
  `MapZoneAlertView` `2.0.1` (CocoaPods).
* The plugin never logs the identity or metadata.
* Example app: identity field and sign-out in the settings dialog, a
  "signed in elsewhere" dialog on `2006`, weight in tonnes, the six vehicle
  types.

## 1.0.0

Wraps the MapZone Alert View SDK **1.0.2**: Android
`com.github.mapzone-global:mapzone-alert-view-android:1.0.2` (JitPack) and iOS
`MapZoneAlertView` `1.0.2` (CocoaPods).

* `NavSpeedAlert.instance`: `configure`, `start`, `onLocation`, `reset`,
  `setSegmentUrl`, `setExtraHeaders`, `setExtraBodyFields`,
  `setMutedAlertTypes`, `setVoiceMode`, `setVoiceSpeed`.
* Streams: `onSigns` (speed limit, next limit, camera, toll), `onRestriction`
  (no stopping/parking, road closed, vehicle ban, built-up area, turn
  restriction), `onVoice`, `onResult`, `onReroute`. Sign images are PNG bytes.
* `onRestriction` and `onVoice` register their native callback only while
  listened to: on Android restriction images are not rendered without a
  listener, and the built-in voice player stays active until `onVoice` is
  listened to.
* Calls that wait on the engine (`setExtraHeaders`, `setExtraBodyFields`) run off the platform main thread.
* Engine teardown only removes the callbacks and route that engine set up, so
  a background Flutter engine going away does not stop the app's alerts.
