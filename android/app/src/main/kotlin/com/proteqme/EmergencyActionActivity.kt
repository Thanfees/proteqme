package com.proteqme

import android.Manifest
import android.app.Activity
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.telephony.SmsManager
import android.util.Log
import androidx.core.content.ContextCompat

/**
 * Transparent activity so CALL/SMS run from a visible foreground context.
 * Background [Service] cannot reliably start ACTION_CALL or send SMS on API 29+.
 */
class EmergencyActionActivity : Activity() {
    private val logTag = "EmergencyAction"

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
        }

        when (intent?.action) {
            ACTION_CALL -> handleCall()
            ACTION_SMS -> handleSms()
            else -> Log.w(logTag, "Unknown action: ${intent?.action}")
        }

        Handler(Looper.getMainLooper()).postDelayed({ finish() }, 800)
    }

    private fun handleCall() {
        val phone = PhoneNormalizer.normalize(intent.getStringExtra(EXTRA_PHONE).orEmpty())
        if (phone.isEmpty()) {
            Log.e(logTag, "CALL: empty phone")
            return
        }

        val uri = Uri.parse("tel:$phone")
        if (hasPermission(Manifest.permission.CALL_PHONE)) {
            try {
                startActivity(Intent(Intent.ACTION_CALL, uri))
                Log.i(logTag, "ACTION_CALL started for $phone")
                return
            } catch (error: Exception) {
                Log.e(logTag, "ACTION_CALL failed", error)
            }
        }

        try {
            startActivity(Intent(Intent.ACTION_DIAL, uri))
            Log.i(logTag, "ACTION_DIAL fallback for $phone")
        } catch (error: Exception) {
            Log.e(logTag, "ACTION_DIAL failed", error)
        }
    }

    private fun handleSms() {
        val numbers =
            intent.getStringArrayListExtra(EXTRA_PHONES)?.let { PhoneNormalizer.normalizeAll(it) }
                ?: emptyList()
        val message = intent.getStringExtra(EXTRA_MESSAGE).orEmpty().trim()

        if (numbers.isEmpty() || message.isEmpty()) {
            Log.e(logTag, "SMS: empty numbers or message")
            return
        }

        if (hasPermission(Manifest.permission.SEND_SMS)) {
            val smsManager = getSmsManager()
            var sent = 0
            for (number in numbers) {
                try {
                    val parts = smsManager.divideMessage(message)
                    if (parts.size > 1) {
                        smsManager.sendMultipartTextMessage(number, null, parts, null, null)
                    } else {
                        smsManager.sendTextMessage(number, null, message, null, null)
                    }
                    sent++
                    Log.i(logTag, "SMS sent to $number")
                } catch (error: Exception) {
                    Log.e(logTag, "SMS failed for $number", error)
                }
            }
            if (sent > 0) return
        } else {
            Log.w(logTag, "SEND_SMS not granted")
        }

        openSmsComposer(numbers, message)
    }

    private fun openSmsComposer(numbers: List<String>, message: String) {
        try {
            val recipients = numbers.joinToString(";")
            val intent =
                Intent(Intent.ACTION_SENDTO).apply {
                    data = Uri.parse("smsto:$recipients")
                    putExtra("sms_body", message)
                }
            startActivity(intent)
            Log.i(logTag, "Opened SMS composer for ${numbers.size} recipients")
        } catch (error: Exception) {
            Log.e(logTag, "SMS composer failed", error)
        }
    }

    private fun getSmsManager(): SmsManager {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            getSystemService(SmsManager::class.java) ?: SmsManager.getDefault()
        } else {
            SmsManager.getDefault()
        }
    }

    private fun hasPermission(permission: String): Boolean {
        return ContextCompat.checkSelfPermission(this, permission) ==
            PackageManager.PERMISSION_GRANTED
    }

    companion object {
        const val ACTION_CALL = "com.proteqme.action.EMERGENCY_CALL"
        const val ACTION_SMS = "com.proteqme.action.EMERGENCY_SMS"

        const val EXTRA_PHONE = "extra_phone"
        const val EXTRA_PHONES = "extra_phones"
        const val EXTRA_MESSAGE = "extra_message"

        fun launchCall(context: Context, phone: String) {
            val intent =
                Intent(context, EmergencyActionActivity::class.java).apply {
                    action = ACTION_CALL
                    putExtra(EXTRA_PHONE, phone)
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    addFlags(Intent.FLAG_ACTIVITY_EXCLUDE_FROM_RECENTS)
                }
            context.startActivity(intent)
        }

        fun launchSms(context: Context, numbers: List<String>, message: String) {
            val normalized = PhoneNormalizer.normalizeAll(numbers)
            if (normalized.isEmpty() || message.isBlank()) return

            val intent =
                Intent(context, EmergencyActionActivity::class.java).apply {
                    action = ACTION_SMS
                    putStringArrayListExtra(EXTRA_PHONES, ArrayList(normalized))
                    putExtra(EXTRA_MESSAGE, message)
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    addFlags(Intent.FLAG_ACTIVITY_EXCLUDE_FROM_RECENTS)
                }
            context.startActivity(intent)
        }
    }
}
