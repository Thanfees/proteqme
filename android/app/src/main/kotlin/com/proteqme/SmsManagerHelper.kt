package com.proteqme

import android.Manifest
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.os.Build
import android.telephony.SmsManager
import android.util.Log
import androidx.core.content.ContextCompat

class SmsManagerHelper(
    private val context: Context,
    private val logTag: String = "SmsManagerHelper",
) {
    init {
        registerReceiversOnce(context)
    }

    fun sendEmergencySms(numbers: List<String>, message: String): Boolean {
        val sanitized = PhoneNormalizer.normalizeAll(numbers)
        if (sanitized.isEmpty() || message.isBlank()) {
            Log.e(logTag, "No valid numbers or empty message")
            return false
        }

        if (!hasPermission(Manifest.permission.SEND_SMS)) {
            Log.e(logTag, "SEND_SMS permission not granted")
            return false
        }

        val manager = getSmsManager()
        var dispatched = 0
        for (number in sanitized) {
            try {
                val parts = manager.divideMessage(message)
                val sentIntents =
                    ArrayList<PendingIntent>(parts.size).apply {
                        repeat(parts.size) { add(buildSentIntent(number)) }
                    }
                val deliveredIntents =
                    ArrayList<PendingIntent>(parts.size).apply {
                        repeat(parts.size) { add(buildDeliveredIntent(number)) }
                    }

                if (parts.size > 1) {
                    manager.sendMultipartTextMessage(
                        number, null, parts, sentIntents, deliveredIntents,
                    )
                } else {
                    manager.sendTextMessage(
                        number, null, message,
                        sentIntents.first(), deliveredIntents.first(),
                    )
                }
                dispatched++
                Log.i(logTag, "SMS dispatched to $number (${message.length} chars)")
            } catch (e: Exception) {
                Log.e(logTag, "SMS dispatch failed for $number: $e")
            }
        }

        Log.i(logTag, "SMS dispatched to $dispatched/${sanitized.size} recipients (awaiting carrier result)")
        return dispatched > 0
    }

    private fun buildSentIntent(number: String): PendingIntent {
        val intent =
            Intent(ACTION_SMS_SENT).apply {
                setPackage(context.packageName)
                putExtra(EXTRA_NUMBER, number)
            }
        return PendingIntent.getBroadcast(
            context,
            number.hashCode() and 0x7fffffff,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    private fun buildDeliveredIntent(number: String): PendingIntent {
        val intent =
            Intent(ACTION_SMS_DELIVERED).apply {
                setPackage(context.packageName)
                putExtra(EXTRA_NUMBER, number)
            }
        return PendingIntent.getBroadcast(
            context,
            (number.hashCode() and 0x7fffffff) + 1,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    private fun getSmsManager(): SmsManager =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            context.getSystemService(SmsManager::class.java) ?: SmsManager.getDefault()
        } else {
            @Suppress("DEPRECATION")
            SmsManager.getDefault()
        }

    private fun hasPermission(permission: String) =
        ContextCompat.checkSelfPermission(context, permission) == PackageManager.PERMISSION_GRANTED

    companion object {
        const val ACTION_SMS_SENT = "com.proteqme.action.SMS_SENT"
        const val ACTION_SMS_DELIVERED = "com.proteqme.action.SMS_DELIVERED"
        private const val EXTRA_NUMBER = "extra_number"

        @Volatile
        private var registered = false

        @Synchronized
        private fun registerReceiversOnce(context: Context) {
            if (registered) return
            registered = true

            val appCtx = context.applicationContext
            val tag = "SmsResult"

            val sentReceiver =
                object : BroadcastReceiver() {
                    override fun onReceive(c: Context, intent: Intent) {
                        val number = intent.getStringExtra(EXTRA_NUMBER) ?: "?"
                        val result =
                            when (resultCode) {
                                android.app.Activity.RESULT_OK -> "OK"
                                SmsManager.RESULT_ERROR_GENERIC_FAILURE -> "GENERIC_FAILURE"
                                SmsManager.RESULT_ERROR_NO_SERVICE -> "NO_SERVICE (no signal / radio off)"
                                SmsManager.RESULT_ERROR_NULL_PDU -> "NULL_PDU"
                                SmsManager.RESULT_ERROR_RADIO_OFF -> "RADIO_OFF (airplane mode)"
                                else -> "code=$resultCode"
                            }
                        if (resultCode == android.app.Activity.RESULT_OK) {
                            Log.i(tag, "SMS to $number → SENT BY CARRIER")
                        } else {
                            Log.e(tag, "SMS to $number → SEND FAILED: $result. " +
                                "On HyperOS check: SIM credit, Settings → Apps → ProteqMe → " +
                                "Other permissions → Send SMS without confirmation = ON")
                        }
                    }
                }

            val deliveredReceiver =
                object : BroadcastReceiver() {
                    override fun onReceive(c: Context, intent: Intent) {
                        val number = intent.getStringExtra(EXTRA_NUMBER) ?: "?"
                        if (resultCode == android.app.Activity.RESULT_OK) {
                            Log.i(tag, "SMS to $number → DELIVERED TO RECIPIENT")
                        } else {
                            Log.w(tag, "SMS to $number → NOT DELIVERED (recipient phone off or out of range)")
                        }
                    }
                }

            val flags =
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                    Context.RECEIVER_NOT_EXPORTED
                } else {
                    0
                }
            appCtx.registerReceiver(sentReceiver, IntentFilter(ACTION_SMS_SENT), flags)
            appCtx.registerReceiver(deliveredReceiver, IntentFilter(ACTION_SMS_DELIVERED), flags)
        }
    }
}
