#
# Flutter plugin for the MapZone Alert View SDK. The native SDK is resolved from
# the published `MapZoneAlertView` pod; keep its version in step with pubspec.
#
Pod::Spec.new do |s|
  s.name             = 'mapzone_nav_speed_alert'
  s.version          = '1.0.2'
  s.summary          = 'Speed, camera, toll and road-restriction alerts along a route.'
  s.description      = <<-DESC
Flutter plugin for the MapZone Alert View SDK: speed-limit, camera, toll and
road-restriction signs with voice along a route supplied by the host app.
                       DESC
  s.homepage         = 'https://map.zone'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'MapZone' => 'https://map.zone' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.dependency 'Flutter'
  s.dependency 'MapZoneAlertView', '= 1.0.2'
  s.platform = :ios, '13.0'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.9'

  s.resource_bundles = { 'mapzone_nav_speed_alert_privacy' => ['Resources/PrivacyInfo.xcprivacy'] }
end
