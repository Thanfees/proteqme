package com.proteqme

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.telephony.PhoneStateListener
import android.telephony.TelephonyManager
import android.util.Log

/**
 * Dials contacts sequentially; treats calls shorter than 40s as unanswered.
 */
class CallEscalationManager(
    private val context: Context,
    private val callManager: CallManager,
    private val logTag: String = "CallEscalation",
) {
    private val mainHandler = Handler(Looper.getMainLooper())
    private var telephonyManager: TelephonyManager? = null
    private var phoneStateListener: PhoneStateListener? = null

    private var offhookAtMs: Long = 0L
    private var isDialing = false

    var onHumanAnswered: (() -> Unit)? = null
    var onEscalateNext: (() -> Unit)? = null

    fun dial(phone: String) {
        if (isDialing) return
        isDialing = true
        offhookAtMs = 0L
        registerListener()
        Log.i(logTag, "Dialing $phone")
        callManager.makeEmergencyCall(phone)
    }

    fun stop() {
        unregisterListener()
        isDialing = false
        offhookAtMs = 0L
    }

    private fun registerListener() {
        unregisterListener()
        val manager =
            context.getSystemService(Context.TELEPHONY_SERVICE) as? TelephonyManager ?: return
        telephonyManager = manager

        val listener =
            object : PhoneStateListener() {
                override fun onCallStateChanged(state: Int, phoneNumber: String?) {
                    handleState(state)
                }
            }
        phoneStateListener = listener

        @Suppress("DEPRECATION")
        manager.listen(listener, PhoneStateListener.LISTEN_CALL_STATE)
    }

    private fun unregisterListener() {
        val manager = telephonyManager ?: return
        val listener = phoneStateListener ?: return
        @Suppress("DEPRECATION")
        manager.listen(listener, PhoneStateListener.LISTEN_NONE)
        phoneStateListener = null
    }

    private fun handleState(state: Int) {
        when (state) {
            TelephonyManager.CALL_STATE_OFFHOOK -> {
                if (offhookAtMs == 0L) {
                    offhookAtMs = System.currentTimeMillis()
                    Log.i(logTag, "Call OFFHOOK")
                }
            }

            TelephonyManager.CALL_STATE_IDLE -> {
                if (!isDialing) return
                val durationSec =
                    if (offhookAtMs > 0L) {
                        ((System.currentTimeMillis() - offhookAtMs) / 1000L).toInt()
                    } else {
                        0
                    }
                Log.i(logTag, "Call IDLE duration=${durationSec}s")
                isDialing = false
                unregisterListener()

                if (durationSec >= ANSWERED_THRESHOLD_SEC) {
                    onHumanAnswered?.invoke()
                } else {
                    mainHandler.postDelayed({
                        onEscalateNext?.invoke()
                    }, ESCALATION_PAUSE_MS)
                }
            }
        }
    }

    companion object {
        private const val ANSWERED_THRESHOLD_SEC = 40
        private const val ESCALATION_PAUSE_MS = 5_000L
    }
}
