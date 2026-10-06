package com.mapzone.mapzone_nav_speed_alert

import android.graphics.Bitmap
import android.os.Handler
import android.os.Looper
import com.vietmap.alert_view_sdk.AlertViewManager
import com.vietmap.alert_view_sdk.VoiceAlertType
import com.vietmap.alert_view_sdk.VoiceCallback
import com.vietmap.alert_view_sdk.VoiceMode
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import java.io.ByteArrayOutputStream
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

/**
 * Flutter plugin wrapping the native `AlertViewManager`. Method order mirrors the
 * native class and the Swift plugin so the two can be diffed side by side.
 *
 * Every event channel registers its native callback on the first Dart listen and
 * removes it on cancel. For `restriction` and `voice` this is what keeps the
 * native semantics: restriction images are rendered only while a callback exists,
 * and the built-in voice player stays active until a voice callback is set.
 */
class MapzoneNavSpeedAlertPlugin : FlutterPlugin, MethodCallHandler {
    private val mgr = AlertViewManager()
    private val main = Handler(Looper.getMainLooper())

    private lateinit var methodChannel: MethodChannel
    private val eventChannels = mutableListOf<EventChannel>()
    private val streams = mutableListOf<CallbackStream>()

    // Whether this engine started a route. The native engine is process-wide and
    // Flutter attaches the plugin to every engine (background isolates too), so
    // teardown must only undo what this instance did.
    @Volatile
    private var started = false

    // Calls that wait for the engine queue (a segment fetch may be in flight) must
    // not block the platform thread.
    private lateinit var blockingCalls: ExecutorService

    // Sign images are PNG-encoded off the main thread; one thread keeps tick order.
    private lateinit var encoder: ExecutorService

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        blockingCalls = Executors.newSingleThreadExecutor()
        encoder = Executors.newSingleThreadExecutor()
        val messenger = binding.binaryMessenger
        methodChannel = MethodChannel(messenger, CHANNEL).also { it.setMethodCallHandler(this) }

        stream(messenger, "signs", { emit ->
            mgr.setBitmapCallback { cur, status, next, nextDist, cam, camDist, toll, tollDist, _ ->
                encoder.execute {
                    emit(
                        mapOf(
                            "current" to png(cur),
                            "speedStatus" to status,
                            "next" to png(next),
                            "nextDistMeters" to nextDist,
                            "camera" to png(cam),
                            "cameraDistMeters" to camDist,
                            "toll" to png(toll),
                            "tollDistMeters" to tollDist,
                        ),
                    )
                }
            }
        }, { mgr.setBitmapCallback(null) })

        stream(messenger, "restriction", { emit ->
            mgr.setRestrictionCallback { stop, stopD, closed, closedD, vehicle, vehicleD, bua, buaD, inBua, turn, turnD ->
                encoder.execute {
                    emit(
                        mapOf(
                            "stop" to png(stop),
                            "stopDistMeters" to stopD,
                            "closed" to png(closed),
                            "closedDistMeters" to closedD,
                            "vehicle" to png(vehicle),
                            "vehicleDistMeters" to vehicleD,
                            "bua" to png(bua),
                            "buaDistMeters" to buaD,
                            "inBua" to inBua,
                            "turn" to png(turn),
                            "turnDistMeters" to turnD,
                        ),
                    )
                }
            }
        }, { mgr.setRestrictionCallback(null) })

        stream(messenger, "voice", { emit ->
            // Explicit object, not a lambda: a SAM lambda would bind the 1-arg
            // overload and lose trigger/priority.
            mgr.setVoiceCallback(
                object : VoiceCallback {
                    override fun onVoice(wavBytes: ByteArray) = onVoice(wavBytes, 0, 0)

                    override fun onVoice(wavBytes: ByteArray, trigger: Int, priority: Int) {
                        emit(mapOf("wav" to wavBytes, "trigger" to trigger, "priority" to priority))
                    }
                },
            )
        }, { mgr.setVoiceCallback(null) })

        stream(messenger, "result", { emit ->
            mgr.setResultCallback { ok, code, msg ->
                emit(mapOf("success" to ok, "errorCode" to code, "errorMessage" to (msg ?: "")))
            }
        }, { mgr.setResultCallback(null) })

        stream(messenger, "reroute", { emit ->
            mgr.setRerouteCallback { lat, lng -> emit(mapOf("lat" to lat, "lng" to lng)) }
        }, { mgr.setRerouteCallback(null) })
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        methodChannel.setMethodCallHandler(null)
        eventChannels.forEach { it.setStreamHandler(null) }
        eventChannels.clear()
        // Callbacks are process-wide in the native SDK: drop only the ones this
        // engine installed, so a detached engine neither keeps the built-in player
        // muted nor receives ticks — and a background engine going away does not
        // tear down the app's live route.
        streams.forEach { it.release() }
        streams.clear()
        if (started) {
            mgr.reset()
            started = false
        }
        blockingCalls.shutdown()
        encoder.shutdown()
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        try {
            when (call.method) {
                "configure" -> {
                    mgr.configure(
                        call.arg<String>("baseUrl"),
                        call.arg<String>("apiKeyId"),
                        call.arg<String>("apiKey"),
                        call.arg<String>("vehicleId"),
                        call.arg<Number>("vehicleType").toInt(),
                        call.arg<Number>("seats").toInt(),
                        call.arg<Number>("weights").toDouble(),
                        call.arg<Number>("maxSnapMeters").toDouble(),
                    )
                    result.success(null)
                }

                "setSegmentUrl" -> {
                    mgr.setSegmentUrl(call.arg<String>("url"))
                    result.success(null)
                }

                "setExtraHeaders" -> {
                    val map = call.stringMap()
                    offMain(result) { mgr.setExtraHeaders(map) }
                }

                "setExtraBodyFields" -> {
                    val map = call.stringMap()
                    offMain(result) { mgr.setExtraBodyFields(map) }
                }

                "start" -> {
                    mgr.start(call.arg<String>("polyline"))
                    started = true
                    result.success(null)
                }

                "onLocation" -> {
                    mgr.onLocation(
                        call.arg<Number>("lat").toDouble(),
                        call.arg<Number>("lng").toDouble(),
                        call.arg<Number>("bearing").toDouble(),
                        call.arg<Number>("speedKmh").toDouble(),
                        call.arg<Number>("accuracy").toDouble(),
                        call.arg<Number>("fixTimeMillis").toLong(),
                    )
                    result.success(null)
                }

                "reset" -> {
                    mgr.reset()
                    started = false
                    result.success(null)
                }

                "setMutedAlertTypes" -> {
                    val codes = call.arg<List<Number>>("codes").map { it.toInt() }.toSet()
                    mgr.setMutedAlertTypes(
                        VoiceAlertType.values().filter { it.triggerValue in codes }.toSet()
                    )
                    result.success(null)
                }

                "setVoiceMode" -> {
                    val mode = call.arg<Number>("mode").toInt()
                    mgr.setVoiceMode(if (mode == VoiceMode.DING.nativeValue) VoiceMode.DING else VoiceMode.FULL)
                    result.success(null)
                }

                "setVoiceSpeed" -> {
                    mgr.setVoiceSpeed(call.arg<Number>("speed").toFloat())
                    result.success(null)
                }

                else -> result.notImplemented()
            }
        } catch (e: Exception) {
            val code = if (call.method == "configure") "CONFIGURE_FAILED" else "INVALID_ARGUMENT"
            result.error(code, e.message, null)
        }
    }

    /** Runs [work] on [blockingCalls] and completes [result] on the main thread. */
    private fun offMain(result: Result, work: () -> Any?) {
        blockingCalls.execute {
            try {
                val value = work()
                main.post { result.success(value) }
            } catch (e: Exception) {
                main.post { result.error("NATIVE_ERROR", e.message, null) }
            }
        }
    }

    /**
     * Registers an event channel whose native callback is installed by [open] on
     * listen and removed by [close] on cancel.
     */
    private fun stream(
        messenger: BinaryMessenger,
        name: String,
        open: (emit: (Any) -> Unit) -> Unit,
        close: () -> Unit,
    ) {
        val channel = EventChannel(messenger, "$CHANNEL/$name")
        val handler = CallbackStream(main, open, close)
        channel.setStreamHandler(handler)
        eventChannels += channel
        streams += handler
    }

    private fun MethodCall.stringMap(): Map<String, String> =
        argument<Map<String, String>>("map") ?: emptyMap()

    private fun <T> MethodCall.arg(key: String): T =
        argument<T>(key) ?: throw IllegalArgumentException("Missing argument '$key'")

    private fun png(bitmap: Bitmap?): ByteArray? = bitmap?.let {
        val out = ByteArrayOutputStream()
        it.compress(Bitmap.CompressFormat.PNG, 100, out)
        out.toByteArray()
    }

    private companion object {
        const val CHANNEL = "mapzone_nav_speed_alert"
    }
}

/**
 * Event-channel handler that forwards payloads on the main thread while Dart is
 * listening. Payloads emitted after cancel are dropped.
 */
private class CallbackStream(
    private val main: Handler,
    private val open: (emit: (Any) -> Unit) -> Unit,
    private val close: () -> Unit,
) : EventChannel.StreamHandler {
    @Volatile
    private var sink: EventChannel.EventSink? = null

    // Whether this handler's native callback is currently installed.
    private var active = false

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        sink = events
        active = true
        open(::emit)
    }

    override fun onCancel(arguments: Any?) {
        release()
    }

    /** Removes the native callback if this handler installed it. */
    fun release() {
        sink = null
        if (active) {
            active = false
            close()
        }
    }

    private fun emit(payload: Any) {
        main.post { sink?.success(payload) }
    }
}
