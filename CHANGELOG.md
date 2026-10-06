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
