package com.proteqme

import android.content.Context
import android.util.Log

class CallManager(
    private val context: Context,
    private val logTag: String = "CallManager",
) {
    fun makeEmergencyCall(phoneNumber: String): Boolean {
        val sanitized = PhoneNormalizer.normalize(phoneNumber)
        if (sanitized.isEmpty()) {
            Log.e(logTag, "Primary number is empty after normalize")
            return false
        }

        Log.i(logTag, "Launching emergency call bridge for $sanitized")
        EmergencyActionActivity.launchCall(context, sanitized)
        return true
    }
}
