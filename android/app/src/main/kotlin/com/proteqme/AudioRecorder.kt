package com.proteqme

import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaRecorder
import android.util.Log
import java.util.concurrent.atomic.AtomicBoolean

class AudioRecorder(
    private val sampleRate: Int,
    private val chunkSamples: Int,
    private val onChunk: (FloatArray) -> Unit,
) {
    private val logTag = "AudioRecorder"
    private val running = AtomicBoolean(false)

    private var audioRecord: AudioRecord? = null
    private var readerThread: Thread? = null

    fun start() {
        if (running.get()) {
            return
        }

        val minBuffer = AudioRecord.getMinBufferSize(
            sampleRate,
            AudioFormat.CHANNEL_IN_MONO,
            AudioFormat.ENCODING_PCM_16BIT,
        )
        val bufferSize = (minBuffer * 2).coerceAtLeast(chunkSamples * 2)

        val recorder =
            AudioRecord(
                MediaRecorder.AudioSource.MIC,
                sampleRate,
                AudioFormat.CHANNEL_IN_MONO,
                AudioFormat.ENCODING_PCM_16BIT,
                bufferSize,
            )

        if (recorder.state != AudioRecord.STATE_INITIALIZED) {
            recorder.release()
            throw IllegalStateException("AudioRecord could not be initialized")
        }

        audioRecord = recorder
        running.set(true)
        recorder.startRecording()

        readerThread =
            Thread {
                val readBuffer = ShortArray((bufferSize / 2).coerceAtLeast(1024))
                val frameBuffer = FloatArray(chunkSamples)
                var frameOffset = 0

                while (running.get()) {
                    val read = recorder.read(readBuffer, 0, readBuffer.size)
                    if (read <= 0) {
                        continue
                    }

                    var idx = 0
                    while (idx < read && running.get()) {
                        frameBuffer[frameOffset] = readBuffer[idx] / 32768f
                        frameOffset += 1
                        idx += 1

                        if (frameOffset >= chunkSamples) {
                            try {
                                onChunk(frameBuffer.copyOf())
                            } catch (error: Exception) {
                                Log.e(logTag, "Chunk callback failed", error)
                            }
                            frameOffset = 0
                        }
                    }
                }
            }.apply {
                name = "audio-recorder-thread"
                isDaemon = true
                start()
            }
    }

    fun stop() {
        running.set(false)
        try {
            readerThread?.join(500)
        } catch (_: Exception) {
            // Best effort.
        }
        readerThread = null

        audioRecord?.let { recorder ->
            try {
                recorder.stop()
            } catch (_: Exception) {
                // Best effort.
            }
            recorder.release()
        }
        audioRecord = null
    }
}
