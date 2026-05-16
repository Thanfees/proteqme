package com.proteqme

import android.util.Log

object PhoneNormalizer {
    private const val TAG = "PhoneNormalizer"

    /** Best-effort E.164-ish formatting for Sri Lanka SIM dialing/SMS. */
    fun normalize(raw: String): String {
        var digits = raw.trim().replace(Regex("[^+\\d]"), "")
        if (digits.isEmpty()) return ""

        if (digits.startsWith("+")) {
            return digits
        }

        if (digits.startsWith("00")) {
            return "+" + digits.removePrefix("00")
        }

        // Local SL mobile: 07XXXXXXXX -> +947XXXXXXXX
        if (digits.startsWith("0") && digits.length in 9..11) {
            digits = "+94" + digits.removePrefix("0")
        } else if (digits.length == 9 && digits.startsWith("7")) {
            digits = "+94$digits"
        }

        Log.d(TAG, "Normalized $raw -> $digits")
        return digits
    }

    fun normalizeAll(numbers: List<String>): List<String> =
        numbers.map { normalize(it) }.filter { it.isNotEmpty() }.distinct()
}
