package com.proteqme

import android.content.Context
import android.util.Log

class SmsManagerHelper(
    private val context: Context,
    private val logTag: String = "SmsManagerHelper",
) {
    fun sendEmergencySms(numbers: List<String>, message: String): Boolean {
        val sanitizedNumbers = PhoneNormalizer.normalizeAll(numbers)
        if (sanitizedNumbers.isEmpty() || message.isBlank()) {
            Log.e(logTag, "No valid numbers or empty message")
            return false
        }

        Log.i(logTag, "Launching SMS bridge for ${sanitizedNumbers.size} recipients")
        EmergencyActionActivity.launchSms(context, sanitizedNumbers, message)
        return true
    }
}
