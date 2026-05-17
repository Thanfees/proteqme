package com.proteqme

import android.content.Context

/** Tracks whether the user wants SOS listening to stay on (for MIUI restart). */
class ListenerPrefs(context: Context) {
    private val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    var userWantsListening: Boolean
        get() = prefs.getBoolean(KEY_ENABLED, false)
        set(value) = prefs.edit().putBoolean(KEY_ENABLED, value).apply()

    fun saveContactPayload(primary: String, all: List<String>) {
        prefs.edit()
            .putString(KEY_PRIMARY, primary)
            .putStringSet(KEY_ALL, all.toSet())
            .apply()
    }

    fun primaryNumber(): String = prefs.getString(KEY_PRIMARY, "").orEmpty()

    fun allNumbers(): List<String> =
        prefs.getStringSet(KEY_ALL, emptySet())?.toList() ?: emptyList()

    companion object {
        private const val PREFS_NAME = "proteqme_listener"
        private const val KEY_ENABLED = "enabled"
        private const val KEY_PRIMARY = "primary"
        private const val KEY_ALL = "all_numbers"
    }
}
