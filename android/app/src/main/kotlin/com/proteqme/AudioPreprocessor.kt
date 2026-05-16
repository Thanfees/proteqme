package com.proteqme

import kotlin.math.abs

class AudioPreprocessor(
    private val targetSamples: Int,
) {
    fun toFloatPcm16(shorts: ShortArray, length: Int = shorts.size): FloatArray {
        val safeLength = length.coerceIn(0, shorts.size)
        val out = FloatArray(safeLength)
        for (i in 0 until safeLength) {
            out[i] = shorts[i] / 32768f
        }
        return out
    }

    fun standardize(waveform: FloatArray): FloatArray {
        val fixed = ensureLength(waveform, targetSamples)
        return normalizePeak(fixed)
    }

    fun ensureLength(waveform: FloatArray, expectedSamples: Int): FloatArray {
        if (waveform.size == expectedSamples) {
            return waveform
        }
        if (waveform.size > expectedSamples) {
            return waveform.copyOf(expectedSamples)
        }
        val out = FloatArray(expectedSamples)
        waveform.copyInto(out, endIndex = waveform.size)
        return out
    }

    private fun normalizePeak(waveform: FloatArray): FloatArray {
        var peak = 0f
        for (value in waveform) {
            val a = abs(value)
            if (a > peak) {
                peak = a
            }
        }
        if (peak <= 1e-6f) {
            return waveform
        }
        val scale = 1f / peak
        val out = FloatArray(waveform.size)
        for (i in waveform.indices) {
            out[i] = waveform[i] * scale
        }
        return out
    }
}
