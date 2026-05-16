package com.proteqme

import android.Manifest
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.telephony.SmsManager
import android.util.Log
import androidx.core.content.ContextCompat

class SmsManagerHelper(
    private val context: Context,
    private val logTag: String = "SmsManagerHelper",
) {
    fun sendEmergencySms(numbers: List<String>, message: String): Boolean {
        val sanitizedNumbers =
            numbers
                .map { it.trim() }
                .filter { it.isNotEmpty() }
                .distinct()
        if (sanitizedNumbers.isEmpty() || message.isBlank()) {
            return false
        }

        var sentAny = false
        if (!hasPermission(Manifest.permission.SEND_SMS)) {
            Log.w(logTag, "SEND_SMS permission missing")
        } else {
            val smsManager =
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                    context.getSystemService(SmsManager::class.java) ?: SmsManager.getDefault()
                } else {
                    SmsManager.getDefault()
                }

            for (number in sanitizedNumbers) {
                try {
                    val parts = smsManager.divideMessage(message)
                    if (parts.size > 1) {
                        smsManager.sendMultipartTextMessage(number, null, parts, null, null)
                    } else {
                        smsManager.sendTextMessage(number, null, message, null, null)
                    }
                    sentAny = true
                } catch (error: Exception) {
                    Log.e(logTag, "Failed sending SMS to $number", error)
                }
            }
        }

        if (!sentAny) {
            sentAny = openSmsComposer(sanitizedNumbers, message)
        }

        return sentAny
    }

    fun openSmsComposer(numbers: List<String>, message: String): Boolean {
        val sanitizedNumbers =
            numbers
                .map { it.trim() }
                .filter { it.isNotEmpty() }
                .distinct()
        if (sanitizedNumbers.isEmpty()) {
            return false
        }

        return try {
            val recipients = sanitizedNumbers.joinToString(separator = ";")
            val intent =
                Intent(Intent.ACTION_SENDTO).apply {
                    data = Uri.parse("smsto:$recipients")
                    putExtra("sms_body", message)
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
            context.startActivity(intent)
            true
        } catch (error: Exception) {
            Log.e(logTag, "Unable to open SMS composer fallback", error)
            false
        }
    }

    private fun hasPermission(permission: String): Boolean {
        return ContextCompat.checkSelfPermission(context, permission) == PackageManager.PERMISSION_GRANTED
    }
}
