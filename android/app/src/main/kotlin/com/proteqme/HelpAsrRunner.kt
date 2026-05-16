package com.proteqme

import android.content.Context
import android.util.Log
import org.json.JSONObject
import org.vosk.Model
import org.vosk.Recognizer
import java.io.File
import java.io.FileOutputStream

data class HelpAsrInference(
    val helpConfidence: Float,
    val transcript: String?,
    val isFinal: Boolean,
)

class HelpAsrRunner(
    private val context: Context,
    private val config: RuntimeConfig,
) : AutoCloseable {
    private val logTag = "HelpAsrRunner"
    private val helpTokenRegex = Regex("\\bhelp\\b", RegexOption.IGNORE_CASE)

    private var model: Model? = null
    private var recognizer: Recognizer? = null

    init {
        initialize()
    }

    fun process(floatChunk: FloatArray): HelpAsrInference {
        val rec = recognizer ?: return HelpAsrInference(0f, null, isFinal = false)
        if (floatChunk.isEmpty()) {
            return HelpAsrInference(0f, null, isFinal = false)
        }

        return try {
            val pcm16 = toPcm16(floatChunk)
            val accepted = rec.acceptWaveForm(pcm16, pcm16.size)
            val payload = if (accepted) rec.result else rec.partialResult
            parse(payload, isFinal = accepted)
        } catch (error: Exception) {
            Log.e(logTag, "ASR chunk processing failed", error)
            HelpAsrInference(0f, null, isFinal = false)
        }
    }

    override fun close() {
        try {
            recognizer?.close()
        } catch (_: Exception) {
            // Best effort.
        }
        recognizer = null

        try {
            model?.close()
        } catch (_: Exception) {
            // Best effort.
        }
        model = null
    }

    private fun initialize() {
        if (!config.useAsrHelp) {
            Log.i(logTag, "ASR help detection disabled by config.")
            return
        }

        val modelPath = ensureModelOnDisk(config.asrModelDir)
        if (modelPath == null) {
            Log.w(logTag, "ASR model not available under assets/vosk/${config.asrModelDir}")
            return
        }

        try {
            model = Model(modelPath.absolutePath)
            val grammar = "[\"help\", \"help me\", \"please help\", \"[unk]\"]"
            recognizer =
                try {
                    Recognizer(model, config.sampleRate.toFloat(), grammar)
                } catch (_: Throwable) {
                    Recognizer(model, config.sampleRate.toFloat())
                }
            Log.i(logTag, "ASR recognizer initialized from ${modelPath.absolutePath}")
        } catch (error: Exception) {
            Log.e(logTag, "Failed to initialize Vosk model", error)
            close()
        }
    }

    private fun parse(rawJson: String?, isFinal: Boolean): HelpAsrInference {
        if (rawJson.isNullOrBlank()) {
            return HelpAsrInference(0f, null, isFinal = isFinal)
        }

        return try {
            val json = JSONObject(rawJson)
            val transcriptKey = if (isFinal) "text" else "partial"
            val transcript = json.optString(transcriptKey).trim()
            if (transcript.isEmpty() || !helpTokenRegex.containsMatchIn(transcript)) {
                return HelpAsrInference(0f, transcript.ifEmpty { null }, isFinal = isFinal)
            }

            val confidenceFromWords = extractWordConfidence(json)
            val confidence =
                if (confidenceFromWords != null) {
                    if (confidenceFromWords >= config.asrWordConfidenceThreshold) {
                        confidenceFromWords
                    } else {
                        0f
                    }
                } else {
                    config.asrFallbackConfidence.coerceIn(0f, 1f)
                }

            HelpAsrInference(
                helpConfidence = confidence.coerceIn(0f, 1f),
                transcript = transcript,
                isFinal = isFinal,
            )
        } catch (error: Exception) {
            Log.w(logTag, "Failed to parse ASR payload", error)
            HelpAsrInference(0f, null, isFinal = isFinal)
        }
    }

    private fun extractWordConfidence(json: JSONObject): Float? {
        val words = json.optJSONArray("result") ?: return null
        var best = Float.NEGATIVE_INFINITY
        for (i in 0 until words.length()) {
            val wordObj = words.optJSONObject(i) ?: continue
            val word = wordObj.optString("word")
            if (!helpTokenRegex.containsMatchIn(word)) {
                continue
            }
            val conf = wordObj.optDouble("conf", Double.NaN)
            if (!conf.isNaN()) {
                best = maxOf(best, conf.toFloat())
            }
        }
        return if (best.isFinite()) best else null
    }

    private fun ensureModelOnDisk(modelDirName: String): File? {
        val assetRoot = "vosk/$modelDirName"
        val children =
            try {
                context.assets.list(assetRoot)
            } catch (_: Exception) {
                null
            }
        if (children.isNullOrEmpty()) {
            return null
        }

        val targetRoot = File(context.filesDir, "vosk_models/$modelDirName")
        val marker = File(targetRoot, "am")
        if (marker.exists()) {
            return targetRoot
        }

        try {
            if (targetRoot.exists()) {
                targetRoot.deleteRecursively()
            }
            copyAssetTree(assetRoot, targetRoot)
            return if (marker.exists()) targetRoot else null
        } catch (error: Exception) {
            Log.e(logTag, "Failed copying ASR model assets to local storage", error)
        }
        return null
    }

    private fun copyAssetTree(assetPath: String, targetPath: File) {
        val children = context.assets.list(assetPath).orEmpty()
        if (children.isEmpty()) {
            targetPath.parentFile?.mkdirs()
            context.assets.open(assetPath).use { input ->
                FileOutputStream(targetPath).use { output ->
                    input.copyTo(output)
                }
            }
            return
        }

        if (!targetPath.exists()) {
            targetPath.mkdirs()
        }

        for (child in children) {
            val childAsset = "$assetPath/$child"
            val childTarget = File(targetPath, child)
            copyAssetTree(childAsset, childTarget)
        }
    }

    private fun toPcm16(floatChunk: FloatArray): ShortArray {
        val out = ShortArray(floatChunk.size)
        for (i in floatChunk.indices) {
            val clamped = floatChunk[i].coerceIn(-1f, 1f)
            val scaled = clamped * 32767f
            out[i] = when {
                scaled >= Short.MAX_VALUE -> Short.MAX_VALUE
                scaled <= Short.MIN_VALUE -> Short.MIN_VALUE
                else -> scaled.toInt().toShort()
            }
        }
        return out
    }
}
