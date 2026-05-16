package com.proteqme

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject

data class SosContactEntry(
    val phone: String,
    val name: String,
    val priority: Int,
    val language: String,
)

class SosLoopPrefs(context: Context) {
    private val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    var isActive: Boolean
        get() = prefs.getBoolean(KEY_ACTIVE, false)
        set(value) = prefs.edit().putBoolean(KEY_ACTIVE, value).apply()

    var userName: String
        get() = prefs.getString(KEY_USER_NAME, "ProteqMe User") ?: "ProteqMe User"
        set(value) = prefs.edit().putString(KEY_USER_NAME, value).apply()

    var smsIntervalSec: Int
        get() = prefs.getInt(KEY_SMS_INTERVAL_SEC, 360).coerceIn(300, 420)
        set(value) = prefs.edit().putInt(KEY_SMS_INTERVAL_SEC, value.coerceIn(300, 420)).apply()

    var callPaused: Boolean
        get() = prefs.getBoolean(KEY_CALL_PAUSED, false)
        set(value) = prefs.edit().putBoolean(KEY_CALL_PAUSED, value).apply()

    var callIndex: Int
        get() = prefs.getInt(KEY_CALL_INDEX, 0)
        set(value) = prefs.edit().putInt(KEY_CALL_INDEX, value).apply()

    var triggeredAtMs: Long
        get() = prefs.getLong(KEY_TRIGGERED_AT, 0L)
        set(value) = prefs.edit().putLong(KEY_TRIGGERED_AT, value).apply()

    fun saveContacts(contacts: List<SosContactEntry>) {
        val array = JSONArray()
        contacts.sortedBy { it.priority }.forEach { contact ->
            array.put(
                JSONObject()
                    .put("phone", contact.phone)
                    .put("name", contact.name)
                    .put("priority", contact.priority)
                    .put("language", contact.language),
            )
        }
        prefs.edit().putString(KEY_CONTACTS_JSON, array.toString()).apply()
    }

    fun loadContacts(): List<SosContactEntry> {
        val raw = prefs.getString(KEY_CONTACTS_JSON, null) ?: return emptyList()
        return try {
            val array = JSONArray(raw)
            buildList {
                for (i in 0 until array.length()) {
                    val obj = array.getJSONObject(i)
                    add(
                        SosContactEntry(
                            phone = obj.optString("phone", "").trim(),
                            name = obj.optString("name", "").trim(),
                            priority = obj.optInt("priority", i + 1),
                            language = obj.optString("language", "en"),
                        ),
                    )
                }
            }.filter { it.phone.isNotEmpty() }
                .sortedBy { it.priority }
        } catch (_: Exception) {
            emptyList()
        }
    }

    fun clearLoop() {
        prefs.edit()
            .putBoolean(KEY_ACTIVE, false)
            .putBoolean(KEY_CALL_PAUSED, false)
            .putInt(KEY_CALL_INDEX, 0)
            .apply()
    }

    companion object {
        fun parseContactsFromJson(json: String): List<SosContactEntry> {
            return try {
                val array = JSONArray(json)
                buildList {
                    for (i in 0 until array.length()) {
                        val obj = array.getJSONObject(i)
                        add(
                            SosContactEntry(
                                phone = obj.optString("phone", "").trim(),
                                name = obj.optString("name", "").trim(),
                                priority = obj.optInt("priority", i + 1),
                                language = obj.optString("language", "en"),
                            ),
                        )
                    }
                }.filter { it.phone.isNotEmpty() }.sortedBy { it.priority }
            } catch (_: Exception) {
                emptyList()
            }
        }

        private const val PREFS_NAME = "proteqme_sos_loop"
        private const val KEY_ACTIVE = "active"
        private const val KEY_USER_NAME = "user_name"
        private const val KEY_SMS_INTERVAL_SEC = "sms_interval_sec"
        private const val KEY_CALL_PAUSED = "call_paused"
        private const val KEY_CALL_INDEX = "call_index"
        private const val KEY_TRIGGERED_AT = "triggered_at"
        private const val KEY_CONTACTS_JSON = "contacts_json"
    }
}
