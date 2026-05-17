package com.proteqme

import kotlin.math.max

class DetectionStateMachine(
    private val windowMs: Long = 10_000,
    private val debounceMs: Long = 2_000,
    private val cooldownMs: Long = 0,
    private val confidenceThreshold: Float = 0.25f,
) {
    private var windowStartMs = 0L
    private var lastDetectionMs = 0L
    private var count = 0
    private var cooldownUntilMs = 0L

    fun processRecognition(
        transcript: String,
        confidence: Float?,
        nowMs: Long = System.currentTimeMillis(),
    ): List<DetectionEvent> {
        val events = mutableListOf<DetectionEvent>()

        if (expireWindowIfNeeded(nowMs)) {
            events += DetectionEvent(DetectionEventType.WINDOW_RESET, 0, nowMs)
        }

        val cooldownRemaining = getCooldownRemainingSeconds(nowMs)
        if (cooldownRemaining > 0) {
            events += DetectionEvent(
                type = DetectionEventType.COOLDOWN,
                count = count,
                timestamp = nowMs,
                cooldownRemaining = cooldownRemaining,
            )
            return events
        }

        val tokenCount = countHelpTokens(transcript)
        if (tokenCount <= 0) {
            return events
        }

        if (confidence != null && confidence < confidenceThreshold) {
            return events
        }

        for (index in 0 until tokenCount) {
            val detectionTime = nowMs + (index * (debounceMs + 1L))

            if (lastDetectionMs != 0L && detectionTime - lastDetectionMs < debounceMs) {
                continue
            }

            if (count == 0) {
                windowStartMs = detectionTime
            }

            if (windowStartMs != 0L && detectionTime - windowStartMs > windowMs) {
                count = 0
                windowStartMs = detectionTime
                events += DetectionEvent(
                    type = DetectionEventType.WINDOW_RESET,
                    count = 0,
                    timestamp = detectionTime,
                )
            }

            count += 1
            lastDetectionMs = detectionTime
            events += DetectionEvent(
                type = DetectionEventType.HELP_DETECTED,
                count = count,
                timestamp = detectionTime,
            )

            if (count >= 3 && detectionTime - windowStartMs <= windowMs) {
                events += DetectionEvent(
                    type = DetectionEventType.TRIGGERED,
                    count = count,
                    timestamp = detectionTime,
                )
                count = 0
                windowStartMs = 0L
                cooldownUntilMs = detectionTime + cooldownMs
                events += DetectionEvent(
                    type = DetectionEventType.COOLDOWN,
                    count = 0,
                    timestamp = detectionTime,
                    cooldownRemaining = getCooldownRemainingSeconds(detectionTime),
                )
                break
            }
        }

        return events
    }

    fun expireWindowIfNeeded(nowMs: Long = System.currentTimeMillis()): Boolean {
        val shouldReset = count > 0 && nowMs - windowStartMs > windowMs
        if (!shouldReset) {
            return false
        }

        count = 0
        windowStartMs = 0L
        return true
    }

    fun getCooldownRemainingSeconds(nowMs: Long = System.currentTimeMillis()): Int {
        val ms = cooldownUntilMs - nowMs
        if (ms <= 0L) {
            return 0
        }
        return max(0, ((ms + 999L) / 1000L).toInt())
    }

    fun getCooldownUntilMs(): Long = cooldownUntilMs

    companion object {
        private val helpTokenRegex = Regex("\\bhelp\\b", RegexOption.IGNORE_CASE)

        fun containsHelpToken(text: String): Boolean {
            return helpTokenRegex.containsMatchIn(text)
        }

        fun countHelpTokens(text: String): Int {
            return helpTokenRegex.findAll(text).count()
        }
    }
}
