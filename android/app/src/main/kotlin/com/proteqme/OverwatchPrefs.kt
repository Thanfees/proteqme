package com.proteqme

import android.content.Context

/**
 * Persistent state for the Safe Journey / Overwatch dead-man's switch.
 *
 * Survives process death and reboots so the AlarmManager-based timer can be
 * re-armed by [BootReceiver] / verified by [OverwatchExpiredReceiver].
 *
 * Also caches the contact payload needed to trigger the existing SOS flow
 * from the receiver — at expiry there is no app context, so the broadcast
 * receiver must be able to load every detail synchronously.
 */
class OverwatchPrefs(context: Context) {
    private val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    var active: Boolean
        get() = prefs.getBoolean(KEY_ACTIVE, false)
        set(value) = prefs.edit().putBoolean(KEY_ACTIVE, value).apply()

    var startAtMs: Long
        get() = prefs.getLong(KEY_START_AT, 0L)
        set(value) = prefs.edit().putLong(KEY_START_AT, value).apply()

    var endAtMs: Long
        get() = prefs.getLong(KEY_END_AT, 0L)
        set(value) = prefs.edit().putLong(KEY_END_AT, value).apply()

    var destination: String
        get() = prefs.getString(KEY_DESTINATION, "").orEmpty()
        set(value) = prefs.edit().putString(KEY_DESTINATION, value).apply()

    var userName: String
        get() = prefs.getString(KEY_USER_NAME, "").orEmpty()
        set(value) = prefs.edit().putString(KEY_USER_NAME, value).apply()

    var primaryNumber: String
        get() = prefs.getString(KEY_PRIMARY_NUMBER, "").orEmpty()
        set(value) = prefs.edit().putString(KEY_PRIMARY_NUMBER, value).apply()

    /** Raw JSON array of {phone,name,priority,language} entries — same shape SosLoopPrefs uses. */
    var contactsJson: String
        get() = prefs.getString(KEY_CONTACTS_JSON, "").orEmpty()
        set(value) = prefs.edit().putString(KEY_CONTACTS_JSON, value).apply()

    fun save(
        startAtMs: Long,
        endAtMs: Long,
        destination: String,
        userName: String,
        primaryNumber: String,
        contactsJson: String,
    ) {
        prefs.edit()
            .putBoolean(KEY_ACTIVE, true)
            .putLong(KEY_START_AT, startAtMs)
            .putLong(KEY_END_AT, endAtMs)
            .putString(KEY_DESTINATION, destination)
            .putString(KEY_USER_NAME, userName)
            .putString(KEY_PRIMARY_NUMBER, primaryNumber)
            .putString(KEY_CONTACTS_JSON, contactsJson)
            .apply()
    }

    fun clear() {
        prefs.edit()
            .putBoolean(KEY_ACTIVE, false)
            .putLong(KEY_START_AT, 0L)
            .putLong(KEY_END_AT, 0L)
            .putString(KEY_DESTINATION, "")
            .apply()
    }

    fun isActive(): Boolean = active && endAtMs > 0L

    fun remainingMs(nowMs: Long = System.currentTimeMillis()): Long {
        if (!isActive()) return 0L
        val remaining = endAtMs - nowMs
        return if (remaining < 0L) 0L else remaining
    }

    companion object {
        private const val PREFS_NAME = "overwatch_prefs"
        private const val KEY_ACTIVE = "active"
        private const val KEY_START_AT = "start_at_ms"
        private const val KEY_END_AT = "end_at_ms"
        private const val KEY_DESTINATION = "destination"
        private const val KEY_USER_NAME = "user_name"
        private const val KEY_PRIMARY_NUMBER = "primary_number"
        private const val KEY_CONTACTS_JSON = "contacts_json"
    }
}
