package com.proteqme

import android.content.Context
import android.util.Log

class CallManager(
    private val context: Context,
    private val notificationHelper: NotificationHelper,
    private val logTag: String = "CallManager",
) {
    fun makeEmergencyCall(phoneNumber: String): Boolean {
        val sanitized = PhoneNormalizer.normalize(phoneNumber)
        if (sanitized.isEmpty()) {
            Log.e(logTag, "Primary number is empty after normalize")
            return false
        }

        Log.i(logTag, "Firing emergency call for $sanitized")
        // Post a full-screen notification (works when screen is locked on
        // stock Android) AND directly launch the transparent call activity
        // as a fallback — many OEMs (Xiaomi / MIUI, Samsung OneUI) silently
        // suppress full-screen intents, so the direct launch guarantees the
        // call actually fires.
        notificationHelper.showEmergencyCallNotification(sanitized)
        try {
            EmergencyActionActivity.launchCall(context, sanitized)
        } catch (e: Exception) {
            Log.e(logTag, "Direct launchCall failed (relying on notification)", e)
        }
        return true
    }
}
