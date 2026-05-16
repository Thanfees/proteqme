package com.proteqme

import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.EventChannel

class ListenerEventStreamHandler : EventChannel.StreamHandler {
    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
    }

    companion object {
        private val mainHandler = Handler(Looper.getMainLooper())

        @Volatile
        private var eventSink: EventChannel.EventSink? = null

        fun emit(event: DetectionEvent) {
            val payload = event.toMap()
            mainHandler.post {
                eventSink?.success(payload)
            }
        }
    }
}
