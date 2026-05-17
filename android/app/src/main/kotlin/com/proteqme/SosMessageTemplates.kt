package com.proteqme

import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

object SosMessageTemplates {
    private fun formatNow(): String {
        return SimpleDateFormat("dd MMM, HH:mm", Locale.getDefault()).format(Date())
    }

    fun ongoing(userName: String, lat: Double, lng: Double, language: String): String {
        val link = "https://maps.google.com/?q=$lat,$lng"
        val time = formatNow()
        val name = userName.ifBlank { "Your contact" }
        return when (language.lowercase()) {
            "si" ->
                "හදිසි අවස්ථාවකි ($time): $name අනතුරක වැටී ඇත! යාවත්කාලීන කළ ස්ථානය: $link"
            "ta" ->
                "அவசரநிலை ($time): $name ஆபத்தில் உள்ளார்! தற்போதைய இடம்: $link"
            else ->
                "URGENT SOS ($time): $name is in danger! Location: $link"
        }
    }

    fun resolved(userName: String, language: String = "en"): String {
        val time = formatNow()
        val name = userName.ifBlank { "Your contact" }
        return when (language.lowercase()) {
            "si" -> "විසඳුණි ($time): $name ආරක්ෂිතයි සහ ඔවුන්ගේ අනන්‍යතාව තහවුරු කර ඇත."
            "ta" -> "தீர்வு ($time): $name பாதுகாப்பாக உள்ளார், அடையாளம் சரிபார்க்கப்பட்டது."
            else -> "RESOLVED ($time): $name is safe and has verified their identity via biometrics."
        }
    }

    /**
     * Fired when the Safe Journey / Overwatch dead-man's switch hits zero
     * without an "I arrived safely" check-in. Always English — when the timer
     * was active the user explicitly opted into a one-shot urgent escalation,
     * and the message must be understood by every responder.
     */
    fun overwatchExpired(
        userName: String,
        destination: String?,
        mapsLink: String?,
        timestamp: String,
    ): String {
        val name = userName.ifBlank { "Your contact" }
        val destinationPart = if (destination.isNullOrBlank()) {
            ""
        } else {
            " Intended destination: $destination."
        }
        val locationPart = if (mapsLink.isNullOrBlank()) {
            " Location unavailable."
        } else {
            " Last known location: $mapsLink."
        }
        return "URGENT: $name's Safe Journey timer has expired without a check-in!" +
            " They may be in danger.$destinationPart$locationPart ($timestamp)"
    }
}
