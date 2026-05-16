package com.proteqme

import android.content.Context
import android.util.Log
import org.tensorflow.lite.Interpreter
import java.io.FileInputStream
import java.nio.MappedByteBuffer
import java.nio.channels.FileChannel

class HelpClassifierRunner(
    private val context: Context,
) : AutoCloseable {
    private val logTag = "HelpClassifierRunner"
    private val interpreter: Interpreter? = loadInterpreter("ml/help_classifier.tflite")

    init {
        if (interpreter == null) {
            Log.w(logTag, "HELP classifier not found. helpConfidence will remain 0.")
        }
    }

    fun predictHelpConfidence(embedding: FloatArray): Float {
        val model = interpreter ?: return 0f
        return try {
            val inputShape = model.getInputTensor(0).shape()
            val inputSize = inputShape.lastOrNull() ?: embedding.size
            val inVec = padOrTruncate(embedding, inputSize)
            val input: Any =
                when (inputShape.size) {
                    1 -> inVec
                    else -> arrayOf(inVec)
                }

            val outputShape = model.getOutputTensor(0).shape()
            val output =
                when (outputShape.size) {
                    1 -> FloatArray(outputShape[0])
                    else -> Array(outputShape[0]) { FloatArray(outputShape.getOrElse(1) { 1 }) }
                }

            model.run(input, output)
            when (output) {
                is FloatArray -> decodeOutput(output)
                is Array<*> -> decodeOutput((output.firstOrNull() as? FloatArray) ?: floatArrayOf(0f))
                else -> 0f
            }.coerceIn(0f, 1f)
        } catch (error: Exception) {
            Log.e(logTag, "HELP classifier inference failed", error)
            0f
        }
    }

    override fun close() {
        interpreter?.close()
    }

    private fun decodeOutput(output: FloatArray): Float {
        if (output.isEmpty()) {
            return 0f
        }
        return if (output.size == 1) {
            output[0]
        } else {
            // If model outputs two logits/probabilities, assume index 1 is HELP.
            output[1]
        }
    }

    private fun padOrTruncate(input: FloatArray, size: Int): FloatArray {
        if (input.size == size) {
            return input
        }
        if (input.size > size) {
            return input.copyOf(size)
        }
        val out = FloatArray(size)
        input.copyInto(out, endIndex = input.size)
        return out
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
            Interpreter(modelBuffer, Interpreter.Options().apply { setNumThreads(1) })
        } catch (error: Exception) {
            Log.w(logTag, "Unable to load asset model: $assetPath", error)
            null
        }
    }
}
