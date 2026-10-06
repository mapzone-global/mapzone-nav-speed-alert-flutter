import AlertViewSDK
import Flutter
import UIKit

/// Flutter plugin wrapping the native `AlertViewManager`. Method order mirrors the
/// native class and the Kotlin plugin so the two can be diffed side by side.
///
/// Every event channel registers its native callback on the first Dart listen and
/// removes it on cancel. For `voice` this is what keeps the native semantics: the
/// built-in voice player stays active until a voice callback is set. (The native
/// iOS SDK 1.0.2 renders restriction images whether or not a callback is set;
/// they are simply not forwarded without a listener.)
public class MapzoneNavSpeedAlertPlugin: NSObject, FlutterPlugin {
  private static let channelName = "mapzone_nav_speed_alert"

  private let mgr = AlertViewManager()
  private var methodChannel: FlutterMethodChannel?
  private var eventChannels: [FlutterEventChannel] = []
  private var streams: [CallbackStream] = []

  // Whether this engine started a route. The native engine is process-wide and
  // the plugin is registered on every engine, so teardown must only undo what
  // this instance did.
  private var started = false

  // Calls that wait for the engine queue (a segment fetch may be in flight) must
  // not block the platform thread.
  private let blockingCalls = DispatchQueue(label: "com.mapzone.nav_speed_alert.calls")

  // Sign images are PNG-encoded off the main thread; a serial queue keeps tick order.
  private let encoder = DispatchQueue(label: "com.mapzone.nav_speed_alert.encoder")

  public static func register(with registrar: FlutterPluginRegistrar) {
    let instance = MapzoneNavSpeedAlertPlugin()
    let messenger = registrar.messenger()
    let channel = FlutterMethodChannel(name: channelName, binaryMessenger: messenger)
    registrar.addMethodCallDelegate(instance, channel: channel)
    // Publishing is what makes the engine call detachFromEngine(for:) on teardown.
    registrar.publish(instance)
    instance.methodChannel = channel
    instance.registerStreams(messenger)
  }

  public func detachFromEngine(for registrar: FlutterPluginRegistrar) {
    methodChannel?.setMethodCallHandler(nil)
    eventChannels.forEach { $0.setStreamHandler(nil) }
    eventChannels.removeAll()
    // Callbacks are process-wide in the native SDK: drop only the ones this
    // engine installed, so a detached engine neither keeps the built-in player
    // muted nor receives ticks — and another engine going away does not tear
    // down the app's live route.
    streams.forEach { $0.release() }
    streams.removeAll()
    if started {
      mgr.reset()
      started = false
    }
  }

  // MARK: - Event channels

  private func registerStreams(_ messenger: FlutterBinaryMessenger) {
    stream(messenger, "signs", open: { [weak self] emit in
      self?.mgr.setBitmapCallback { [weak self] cur, status, next, nextDist, cam, camDist, toll, tollDist in
        self?.encoder.async {
          emit([
            "current": png(cur),
            "speedStatus": status,
            "next": png(next),
            "nextDistMeters": nextDist,
            "camera": png(cam),
            "cameraDistMeters": camDist,
            "toll": png(toll),
            "tollDistMeters": tollDist,
          ])
        }
      }
    }, close: { [weak self] in self?.mgr.setBitmapCallback(nil) })

    stream(messenger, "restriction", open: { [weak self] emit in
      self?.mgr.setRestrictionCallback {
        [weak self] stop, stopD, closed, closedD, vehicle, vehicleD, bua, buaD, inBua, turn, turnD in
        self?.encoder.async {
          emit([
            "stop": png(stop),
            "stopDistMeters": stopD,
            "closed": png(closed),
            "closedDistMeters": closedD,
            "vehicle": png(vehicle),
            "vehicleDistMeters": vehicleD,
            "bua": png(bua),
            "buaDistMeters": buaD,
            "inBua": inBua,
            "turn": png(turn),
            "turnDistMeters": turnD,
          ])
        }
      }
    }, close: { [weak self] in self?.mgr.setRestrictionCallback(nil) })

    stream(messenger, "voice", open: { [weak self] emit in
      self?.mgr.setVoiceCallback { wav, trigger, priority in
        emit([
          "wav": FlutterStandardTypedData(bytes: wav),
          "trigger": trigger,
          "priority": priority,
        ])
      }
    }, close: { [weak self] in self?.mgr.setVoiceCallback(nil) })

    stream(messenger, "result", open: { [weak self] emit in
      self?.mgr.setResultCallback { ok, code, msg in
        emit(["success": ok, "errorCode": code, "errorMessage": msg])
      }
    }, close: { [weak self] in self?.mgr.setResultCallback(nil) })

    stream(messenger, "reroute", open: { [weak self] emit in
      self?.mgr.setRerouteCallback { lat, lng in emit(["lat": lat, "lng": lng]) }
    }, close: { [weak self] in self?.mgr.setRerouteCallback(nil) })
  }

  /// Registers an event channel whose native callback is installed by `open` on
  /// listen and removed by `close` on cancel.
  private func stream(
    _ messenger: FlutterBinaryMessenger,
    _ name: String,
    open: @escaping (@escaping ([String: Any]) -> Void) -> Void,
    close: @escaping () -> Void
  ) {
    let channel = FlutterEventChannel(
      name: "\(Self.channelName)/\(name)", binaryMessenger: messenger)
    let handler = CallbackStream(open: open, close: close)
    channel.setStreamHandler(handler)
    eventChannels.append(channel)
    streams.append(handler)
  }

  // MARK: - Method channel

  /// Required argument keys per method; a missing one is reported like Kotlin does.
  private static let requiredArgs: [String: [String]] = [
    "configure": [
      "baseUrl", "apiKeyId", "apiKey", "vehicleId", "vehicleType", "seats", "weights",
      "maxSnapMeters",
    ],
    "setSegmentUrl": ["url"],
    "setExtraHeaders": ["map"],
    "setExtraBodyFields": ["map"],
    "start": ["polyline"],
    "onLocation": ["lat", "lng", "bearing", "speedKmh", "accuracy", "fixTimeMillis"],
    "setMutedAlertTypes": ["codes"],
    "setVoiceMode": ["mode"],
    "setVoiceSpeed": ["speed"],
  ]

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any] ?? [:]
    if let missing = Self.requiredArgs[call.method]?.first(where: { args[$0] == nil }) {
      result(
        FlutterError(
          code: call.method == "configure" ? "CONFIGURE_FAILED" : "INVALID_ARGUMENT",
          message: "Missing argument '\(missing)'", details: nil))
      return
    }
    switch call.method {
    case "configure":
      mgr.configure(
        baseUrl: args.string("baseUrl"),
        apiKeyId: args.string("apiKeyId"),
        apiKey: args.string("apiKey"),
        vehicleId: args.string("vehicleId"),
        vehicleType: args.int("vehicleType"),
        seats: args.int("seats"),
        weights: args.double("weights"),
        maxSnapMeters: args.double("maxSnapMeters"))
      result(nil)
    case "setSegmentUrl":
      mgr.setSegmentUrl(args.string("url"))
      result(nil)
    case "setExtraHeaders", "setExtraBodyFields":
      // A malformed map must not silently clear the extras already set.
      guard let map = args["map"] as? [String: String] else {
        result(
          FlutterError(
            code: "INVALID_ARGUMENT", message: "'map' must be Map<String, String>", details: nil))
        return
      }
      if call.method == "setExtraHeaders" {
        offMain(result) { [mgr] in mgr.setExtraHeaders(map) }
      } else {
        offMain(result) { [mgr] in mgr.setExtraBodyFields(map) }
      }
    case "start":
      mgr.start(args.string("polyline"))
      started = true
      result(nil)
    case "onLocation":
      mgr.onLocation(
        lat: args.double("lat"),
        lng: args.double("lng"),
        bearing: args.double("bearing"),
        speedKmh: args.double("speedKmh"),
        accuracy: args.double("accuracy"),
        fixTimeMillis: (args["fixTimeMillis"] as? NSNumber)?.int64Value ?? 0)
      result(nil)
    case "reset":
      mgr.reset()
      started = false
      result(nil)
    case "setMutedAlertTypes":
      let codes = (args["codes"] as? [NSNumber] ?? []).map { $0.intValue }
      mgr.setMutedAlertTypes(Set(codes.compactMap(VoiceAlertType.init(rawValue:))))
      result(nil)
    case "setVoiceMode":
      mgr.setVoiceMode(VoiceMode(rawValue: args.int("mode")) ?? .full)
      result(nil)
    case "setVoiceSpeed":
      mgr.setVoiceSpeed(Float(args.double("speed")))
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  /// Runs `work` on `blockingCalls` and completes `result` on the main thread.
  private func offMain(_ result: @escaping FlutterResult, _ work: @escaping () -> Any?) {
    blockingCalls.async {
      let value = work()
      DispatchQueue.main.async { result(value) }
    }
  }
}

/// Event-channel handler that forwards payloads on the main thread while Dart is
/// listening. Payloads emitted after cancel are dropped.
private final class CallbackStream: NSObject, FlutterStreamHandler {
  private let open: (@escaping ([String: Any]) -> Void) -> Void
  private let close: () -> Void
  private var sink: FlutterEventSink?

  // Whether this handler's native callback is currently installed.
  private var active = false

  init(
    open: @escaping (@escaping ([String: Any]) -> Void) -> Void,
    close: @escaping () -> Void
  ) {
    self.open = open
    self.close = close
  }

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink)
    -> FlutterError?
  {
    sink = events
    active = true
    open { [weak self] payload in
      DispatchQueue.main.async { self?.sink?(payload) }
    }
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    release()
    return nil
  }

  /// Removes the native callback if this handler installed it.
  func release() {
    sink = nil
    if active {
      active = false
      close()
    }
  }
}

/// PNG bytes for the channel, or `NSNull` for an empty slot.
private func png(_ image: UIImage?) -> Any {
  guard let data = image?.pngData() else { return NSNull() }
  return FlutterStandardTypedData(bytes: data)
}

extension Dictionary where Key == String, Value == Any {
  fileprivate func string(_ key: String) -> String { self[key] as? String ?? "" }
  fileprivate func int(_ key: String) -> Int { (self[key] as? NSNumber)?.intValue ?? 0 }
  fileprivate func double(_ key: String) -> Double { (self[key] as? NSNumber)?.doubleValue ?? 0 }
}
