package com.proteqme

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.location.Location
import android.util.Log
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

data class EmergencyWorkflowResult(
    val callStarted: Boolean,
    val smsSent: Boolean,
    val locationIncluded: Boolean,
    val message: String,
) {
    fun toMap(): Map<String, Any> {
        return mapOf(
            "callStarted" to callStarted,
            "smsSent" to smsSent,
            "locationIncluded" to locationIncluded,
            "message" to message,
        )
    }
}

class EmergencyWorkflowExecutor(
    private val context: Context,
    private val logTag: String = "EmergencyWorkflow",
) {
    private val notificationHelper = NotificationHelper(context)
    private val callManager = CallManager(context, notificationHelper, logTag)
    private val smsManagerHelper = SmsManagerHelper(context, logTag)
    private val locationHelper = LocationHelper(context, logTag)

    fun execute(
        primaryNumber: String,
        allNumbers: List<String>,
        providedMessage: String? = null,
    ): EmergencyWorkflowResult {
        val sanitizedPrimary = primaryNumber.trim()
        val numbers = sanitizeNumbers(allNumbers)

        val message = providedMessage
            ?.trim()
            ?.takeIf { it.isNotEmpty() }
            ?: buildEmergencyMessage()
        val locationIncluded = message.contains("maps.google.com/?q=")

        val smsSent = smsManagerHelper.sendEmergencySms(numbers, message)
        val callStarted = callManager.makeEmergencyCall(sanitizedPrimary)

        return EmergencyWorkflowResult(
            callStarted = callStarted,
            smsSent = smsSent,
            locationIncluded = locationIncluded,
            message = message,
        )
    }

    fun sendSms(numbers: List<String>, message: String): Boolean {
        return smsManagerHelper.sendEmergencySms(numbers, message)
    }

    fun makeEmergencyCall(phoneNumber: String): Boolean {
        return callManager.makeEmergencyCall(phoneNumber)
    }

    private fun buildEmergencyMessage(): String {
        val timestamp = SimpleDateFormat("yyyy-MM-dd HH:mm:ss", Locale.US).format(Date())
        val location = getLastKnownLocation()

        if (location == null) {
            return "Emergency! I need immediate help. " +
                "Location unavailable at the moment. " +
                "Timestamp: $timestamp"
        }

        val link = "https://maps.google.com/?q=${location.latitude},${location.longitude}"
        return "Emergency! I need immediate help. " +
            "This alert was triggered from my SOS app. " +
            "My current location: $link " +
            "Timestamp: $timestamp"
    }

    private fun getLastKnownLocation(): Location? = locationHelper.getBestLocation()

    companion object {
        fun parseNumbers(raw: Any?): List<String> {
            val list = raw as? List<*> ?: return emptyList()
            return list
                .mapNotNull { it?.toString()?.trim() }
                .filter { it.isNotEmpty() }
                .distinct()
        }

        private fun sanitizeNumbers(numbers: List<String>): List<String> {
            return numbers
                .map { it.trim() }
                .filter { it.isNotEmpty() }
                .distinct()
        }
    }
}
