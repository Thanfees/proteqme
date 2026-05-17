package com.proteqme

import android.content.Context
import android.util.Log
import org.json.JSONObject
import kotlin.math.max

enum class TriggerMode {
    ANY,
    HELP_ONLY,
    SCREAM_ONLY,
    BOTH_REQUIRED,
}

data class RuntimeConfig(
    val sampleRate: Int = 16_000,
    val chunkSamples: Int = 16_000,
    val helpThreshold: Float = 0.65f,
    val screamThreshold: Float = 0.45f,
    val useAsrHelp: Boolean = true,
    val asrModelDir: String = "vosk-model-small-en-us-0.15",
    val asrWordConfidenceThreshold: Float = 0.55f,
    val asrFallbackConfidence: Float = 0.72f,
    val requiredDetections: Int = 3,
    val windowMs: Long = 10_000L,
    val debounceMs: Long = 2_000L,
    val cooldownMs: Long = 0L,
    val triggerMode: TriggerMode = TriggerMode.ANY,
) {
    companion object {
        private const val TAG = "RuntimeConfig"

        fun load(context: Context): RuntimeConfig {
            return try {
                val jsonText =
                    context.assets
                        .open("ml/runtime_config.json")
                        .bufferedReader()
                        .use { it.readText() }
                parse(JSONObject(jsonText))
            } catch (error: Exception) {
                Log.w(TAG, "Unable to load ml/runtime_config.json. Using defaults.", error)
                RuntimeConfig()
            }
        }

        private fun parse(json: JSONObject): RuntimeConfig {
            val mode =
                when (json.optString("trigger_mode", "ANY").uppercase()) {
                    "HELP_ONLY" -> TriggerMode.HELP_ONLY
                    "SCREAM_ONLY" -> TriggerMode.SCREAM_ONLY
                    "BOTH_REQUIRED" -> TriggerMode.BOTH_REQUIRED
                    else -> TriggerMode.ANY
                }

            val modelDir = json.optString("asr_model_dir", "vosk-model-small-en-us-0.15").trim()

            return RuntimeConfig(
                sampleRate = json.optInt("sample_rate", 16_000),
                chunkSamples = json.optInt("chunk_samples", 16_000),
                helpThreshold = json.optDouble("help_threshold", 0.65).toFloat(),
                screamThreshold = json.optDouble("scream_threshold", 0.45).toFloat(),
                useAsrHelp = json.optBoolean("use_asr_help", true),
                asrModelDir = if (modelDir.isEmpty()) "vosk-model-small-en-us-0.15" else modelDir,
                asrWordConfidenceThreshold = json.optDouble("asr_word_confidence_threshold", 0.55).toFloat(),
                asrFallbackConfidence = json.optDouble("asr_fallback_confidence", 0.72).toFloat(),
                requiredDetections = json.optInt("required_detections", 3),
                windowMs = json.optLong("window_ms", 10_000L),
                debounceMs = json.optLong("debounce_ms", 2_000L),
                cooldownMs = json.optLong("cooldown_ms", 60_000L),
                triggerMode = mode,
            )
        }
    }
}

class TriggerStateMachine(
    private val cfg: RuntimeConfig,
) {
    private var windowStartMs = 0L
    private var lastDetectionMs = 0L
    private var count = 0
    private var cooldownUntilMs = 0L

    fun process(
        helpConfidence: Float,
        screamConfidence: Float,
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

        val helpDetected = helpConfidence >= cfg.helpThreshold
        val screamDetected = screamConfidence >= cfg.screamThreshold

        val validDetection =
            when (cfg.triggerMode) {
                TriggerMode.ANY -> helpDetected || screamDetected
                TriggerMode.HELP_ONLY -> helpDetected
                TriggerMode.SCREAM_ONLY -> screamDetected
                TriggerMode.BOTH_REQUIRED -> helpDetected && screamDetected
            }

        if (!validDetection) {
            return events
        }

        if (lastDetectionMs != 0L && nowMs - lastDetectionMs < cfg.debounceMs) {
            return events
        }

        if (count == 0) {
            windowStartMs = nowMs
        }

        if (windowStartMs != 0L && nowMs - windowStartMs > cfg.windowMs) {
            count = 0
            windowStartMs = nowMs
            events += DetectionEvent(
                type = DetectionEventType.WINDOW_RESET,
                count = 0,
                timestamp = nowMs,
            )
        }

        count += 1
        lastDetectionMs = nowMs
        events += DetectionEvent(
            type = DetectionEventType.HELP_DETECTED,
            count = count,
            timestamp = nowMs,
        )

        if (count >= cfg.requiredDetections && nowMs - windowStartMs <= cfg.windowMs) {
            events += DetectionEvent(
                type = DetectionEventType.TRIGGERED,
                count = count,
                timestamp = nowMs,
            )
            count = 0
            windowStartMs = 0L
            cooldownUntilMs = nowMs + cfg.cooldownMs
            events += DetectionEvent(
                type = DetectionEventType.COOLDOWN,
                count = 0,
                timestamp = nowMs,
                cooldownRemaining = getCooldownRemainingSeconds(nowMs),
            )
        }

        return events
    }

    fun tick(nowMs: Long = System.currentTimeMillis()): List<DetectionEvent> {
        val events = mutableListOf<DetectionEvent>()

        if (expireWindowIfNeeded(nowMs)) {
            events += DetectionEvent(
                type = DetectionEventType.WINDOW_RESET,
                count = 0,
                timestamp = nowMs,
            )
        }

        val cooldownRemaining = getCooldownRemainingSeconds(nowMs)
        if (cooldownRemaining > 0) {
            events += DetectionEvent(
                type = DetectionEventType.COOLDOWN,
                count = count,
                timestamp = nowMs,
                cooldownRemaining = cooldownRemaining,
            )
        }

        return events
    }

    fun getCooldownRemainingSeconds(nowMs: Long = System.currentTimeMillis()): Int {
        val ms = cooldownUntilMs - nowMs
        if (ms <= 0L) {
            return 0
        }
        return max(0, ((ms + 999L) / 1000L).toInt())
    }

    fun getCooldownUntilMs(): Long = cooldownUntilMs

    fun expireWindowIfNeeded(nowMs: Long = System.currentTimeMillis()): Boolean {
        val shouldReset = count > 0 && nowMs - windowStartMs > cfg.windowMs
        if (!shouldReset) {
            return false
        }

        count = 0
        windowStartMs = 0L
        return true
    }
}
