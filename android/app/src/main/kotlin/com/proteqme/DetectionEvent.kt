package com.proteqme

enum class DetectionEventType(val wireName: String) {
    HELP_DETECTED("HELP_DETECTED"),
    WINDOW_RESET("WINDOW_RESET"),
    TRIGGERED("TRIGGERED"),
    COOLDOWN("COOLDOWN")
}

data class DetectionEvent(
    val type: DetectionEventType,
    val count: Int,
    val timestamp: Long,
    val cooldownRemaining: Int? = null
) {
    fun toMap(): Map<String, Any> {
        val payload = mutableMapOf<String, Any>(
            "type" to type.wireName,
            "count" to count,
            "timestamp" to timestamp,
        )
        cooldownRemaining?.let { payload["cooldownRemaining"] = it }
        return payload
    }
}
