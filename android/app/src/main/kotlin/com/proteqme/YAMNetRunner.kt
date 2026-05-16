package com.proteqme

import android.content.Context
import android.util.Log
import org.tensorflow.lite.Interpreter
import java.io.FileInputStream
import java.nio.MappedByteBuffer
import java.nio.channels.FileChannel
import kotlin.math.abs
import kotlin.math.sqrt

data class YAMNetInference(
    val screamConfidence: Float,
    val scores: FloatArray,
    val embedding: FloatArray,
)

class YAMNetRunner(
    private val context: Context,
    private val config: RuntimeConfig,
) : AutoCloseable {
    private val logTag = "YAMNetRunner"
    private val interpreter: Interpreter?
    private val classLabels: List<String>
    private val screamClassIndices: IntArray
    private val preprocessor: AudioPreprocessor

    init {
        preprocessor = AudioPreprocessor(config.chunkSamples)
        interpreter = loadInterpreter("ml/yamnet.tflite")
        classLabels = loadClassLabels("ml/yamnet_class_map.csv")
        screamClassIndices = findScreamClassIndices(classLabels)
        if (interpreter == null) {
            Log.w(logTag, "YAMNet model not found. Using fallback scream heuristic.")
        }
    }

    fun run(chunk: FloatArray): YAMNetInference {
        val waveform = preprocessor.standardize(chunk)
        val model = interpreter ?: return fallbackInference(waveform)

        return try {
            val inputTensor = model.getInputTensor(0)
            val inputShape = inputTensor.shape()
            val expectedSamples = inputShape.lastOrNull() ?: waveform.size
            val inputWave = preprocessor.ensureLength(waveform, expectedSamples)

            val inputObject: Any =
                when (inputShape.size) {
                    1 -> inputWave
                    2 -> arrayOf(inputWave)
                    else -> arrayOf(inputWave)
                }

            val outputMap = mutableMapOf<Int, Any>()
            for (index in 0 until model.outputTensorCount) {
                val shape = model.getOutputTensor(index).shape()
                outputMap[index] = createFloatTensor(shape)
            }

            model.runForMultipleInputsOutputs(arrayOf(inputObject), outputMap)

            val scores = extractScores(outputMap[0], classLabels.size)
            val embedding = extractEmbedding(outputMap[1], fallbackSize = 1024)
            val screamConfidence = computeScreamConfidence(scores)

            YAMNetInference(
                screamConfidence = screamConfidence,
                scores = scores,
                embedding = embedding,
            )
        } catch (error: Exception) {
            Log.e(logTag, "YAMNet inference failed. Using fallback.", error)
            fallbackInference(waveform)
        }
    }

    override fun close() {
        interpreter?.close()
    }

    private fun fallbackInference(waveform: FloatArray): YAMNetInference {
        val screamConfidence = heuristicScreamConfidence(waveform)
        val embedding = FloatArray(1024)
        val usable = waveform.size.coerceAtMost(1024)
        for (i in 0 until usable) {
            embedding[i] = waveform[i]
        }
        val scores = FloatArray(classLabels.size.coerceAtLeast(1))
        if (scores.isNotEmpty()) {
            scores[0] = screamConfidence
        }
        return YAMNetInference(
            screamConfidence = screamConfidence,
            scores = scores,
            embedding = embedding,
        )
    }

    private fun heuristicScreamConfidence(waveform: FloatArray): Float {
        if (waveform.isEmpty()) {
            return 0f
        }
        var sumSq = 0.0
        var maxAbs = 0f
        for (value in waveform) {
            sumSq += (value * value).toDouble()
            val a = abs(value)
            if (a > maxAbs) {
                maxAbs = a
            }
        }
        val rms = sqrt(sumSq / waveform.size).toFloat()
        val confidence = ((rms - 0.08f) / 0.20f).coerceIn(0f, 1f)
        return (confidence * 0.7f + maxAbs.coerceIn(0f, 1f) * 0.3f).coerceIn(0f, 1f)
    }

    private fun computeScreamConfidence(scores: FloatArray): Float {
        if (scores.isEmpty()) {
            return 0f
        }
        if (screamClassIndices.isNotEmpty()) {
            var maxScore = 0f
            for (idx in screamClassIndices) {
                if (idx in scores.indices && scores[idx] > maxScore) {
                    maxScore = scores[idx]
                }
            }
            return maxScore.coerceIn(0f, 1f)
        }
        return scores.maxOrNull()?.coerceIn(0f, 1f) ?: 0f
    }

    private fun findScreamClassIndices(labels: List<String>): IntArray {
        val keywords = listOf("scream", "screaming", "yell", "shout", "crying", "shriek")
        val indices = mutableListOf<Int>()
        for ((index, label) in labels.withIndex()) {
            val low = label.lowercase()
            if (keywords.any { key -> low.contains(key) }) {
                indices += index
            }
        }
        return indices.toIntArray()
    }

    private fun loadInterpreter(assetPath: String): Interpreter? {
        return try {
            val afd = context.assets.openFd(assetPath)
            val input = FileInputStream(afd.fileDescriptor)
            val channel = input.channel
            val modelBuffer: MappedByteBuffer = channel.map(
                FileChannel.MapMode.READ_ONLY,
                afd.startOffset,
                afd.declaredLength,
            )
            input.close()
            afd.close()
            Interpreter(modelBuffer, Interpreter.Options().apply { setNumThreads(2) })
        } catch (error: Exception) {
            Log.w(logTag, "Unable to load asset model: $assetPath", error)
            null
        }
    }

    private fun loadClassLabels(assetPath: String): List<String> {
        return try {
            val lines = context.assets.open(assetPath).bufferedReader().use { it.readLines() }
            val labels = mutableListOf<String>()
            for (line in lines) {
                if (line.isBlank()) {
                    continue
                }
                val parsed = parseCsvLine(line)
                if (parsed.isEmpty()) {
                    continue
                }
                if (parsed[0].equals("index", ignoreCase = true)) {
                    continue
                }
                val label = parsed.lastOrNull().orEmpty().trim()
                if (label.isNotEmpty()) {
                    labels += label
                }
            }
            if (labels.isNotEmpty()) {
                labels
            } else {
                listOf("scream")
            }
        } catch (error: Exception) {
            Log.w(logTag, "Unable to load class map: $assetPath", error)
            listOf("scream")
        }
    }

    private fun parseCsvLine(line: String): List<String> {
        val out = mutableListOf<String>()
        val sb = StringBuilder()
        var inQuotes = false
        var i = 0
        while (i < line.length) {
            val c = line[i]
            if (c == '"') {
                inQuotes = !inQuotes
            } else if (c == ',' && !inQuotes) {
                out += sb.toString()
                sb.clear()
            } else {
                sb.append(c)
            }
            i += 1
        }
        out += sb.toString()
        return out
    }

    private fun createFloatTensor(shape: IntArray): Any {
        return when (shape.size) {
            0 -> FloatArray(1)
            1 -> FloatArray(shape[0])
            2 -> Array(shape[0]) { FloatArray(shape[1]) }
            3 -> Array(shape[0]) { Array(shape[1]) { FloatArray(shape[2]) } }
            else -> FloatArray(shape.fold(1) { acc, v -> acc * v })
        }
    }

    private fun extractScores(raw: Any?, classCount: Int): FloatArray {
        val fallback = FloatArray(classCount.coerceAtLeast(1))
        if (raw == null) {
            return fallback
        }

        return when (raw) {
            is FloatArray -> raw.copyOf(classCount.coerceAtMost(raw.size))
            is Array<*> -> {
                if (raw.isEmpty()) {
                    fallback
                } else {
                    when (val first = raw[0]) {
                        is FloatArray -> {
                            // [patches, classes] -> max pool over patches
                            val pooled = FloatArray(first.size)
                            for (row in raw) {
                                val arr = row as? FloatArray ?: continue
                                for (i in arr.indices) {
                                    if (arr[i] > pooled[i]) {
                                        pooled[i] = arr[i]
                                    }
                                }
                            }
                            pooled
                        }

                        else -> fallback
                    }
                }
            }

            else -> fallback
        }
    }

    private fun extractEmbedding(raw: Any?, fallbackSize: Int): FloatArray {
        val fallback = FloatArray(fallbackSize)
        if (raw == null) {
            return fallback
        }

        return when (raw) {
            is FloatArray -> raw
            is Array<*> -> {
                if (raw.isEmpty()) {
                    fallback
                } else {
                    when (val first = raw[0]) {
                        is FloatArray -> {
                            // [patches, embedding] -> mean pool
                            val emb = FloatArray(first.size)
                            var rows = 0
                            for (row in raw) {
                                val arr = row as? FloatArray ?: continue
                                for (i in arr.indices) {
                                    emb[i] += arr[i]
                                }
                                rows += 1
                            }
                            if (rows > 0) {
                                for (i in emb.indices) {
                                    emb[i] /= rows
                                }
                            }
                            emb
                        }

                        else -> fallback
                    }
                }
            }

            else -> fallback
        }
    }
}
