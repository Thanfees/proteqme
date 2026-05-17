package com.proteqme

import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.EventChannel

/**
 * Thread-safe singleton bridge for pushing Overwatch lifecycle events from
 * background components (alarm receivers, scheduler) back to the active Flutter
 * EventChannel sink. Designed exactly like [ListenerEventStreamHandler] so the
 * patterns are consistent.
 */
object OverwatchEventBus : EventChannel.StreamHandler {
    private val mainHandler = Handler(Looper.getMainLooper())

    @Volatile
    private var eventSink: EventChannel.EventSink? = null

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
    }

    /**
     * Emit an event payload to the Flutter side. The map MUST contain a `type`
     * key whose value is one of: `TICK`, `EXPIRING_SOON`, `EXPIRED`, `CANCELLED`.
     */
    fun emit(payload: Map<String, Any?>) {
        val safe = payload.toMap()
        mainHandler.post {
            eventSink?.success(safe)
        }
    }
}
