package com.proteqme

object SosMessageTemplates {
    fun ongoing(userName: String, lat: Double, lng: Double, language: String): String {
        val link = "https://maps.google.com/?q=$lat,$lng"
        return when (language.lowercase()) {
            "si" ->
                "හදිසි අවස්ථාවකි: $userName අනතුරක වැටී ඇත! යාවත්කාලීන කළ ස්ථානය: $link"
            "ta" ->
                "அவசரநிலை: $userName ஆபத்தில் உள்ளார்! தற்போதைய இடம்: $link"
            else ->
                "URGENT ONGOING SOS: $userName is in danger! Updated Location: $link"
        }
    }

    fun resolved(userName: String, language: String = "en"): String {
        return when (language.lowercase()) {
            "si" -> "විසඳුණි: $userName ආරක්ෂිතයි සහ ඔවුන්ගේ අනන්‍යතාව තහවුරු කර ඇත."
            "ta" -> "தீர்வு: $userName பாதுகாப்பாக உள்ளார், அடையாளம் சரிபார்க்கப்பட்டது."
            else -> "RESOLVED: $userName is safe and has verified their identity via biometrics."
        }
    }
}
