package com.proteqme

import android.Manifest
import android.app.Service
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.util.Log
import androidx.core.content.ContextCompat

class SosListenerService : Service() {
    private val logTag = "SosListenerService"
    private val mainHandler = Handler(Looper.getMainLooper())

    private lateinit var notificationHelper: NotificationHelper
    private lateinit var runtimeConfig: RuntimeConfig
    private lateinit var triggerStateMachine: TriggerStateMachine
    private lateinit var emergencyActionManager: EmergencyActionManager

    private var yamNetRunner: YAMNetRunner? = null
    private var helpClassifierRunner: HelpClassifierRunner? = null
    private var helpAsrRunner: HelpAsrRunner? = null
    private var audioRecorder: AudioRecorder? = null

    private var primaryNumber: String = ""
    private var allNumbers: List<String> = emptyList()

    private val stateTickRunnable =
        object : Runnable {
            override fun run() {
                tickStateMachine()
                mainHandler.postDelayed(this, 1000L)
            }
        }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        notificationHelper = NotificationHelper(this)
        notificationHelper.createChannels()
        runtimeConfig = RuntimeConfig.load(this)
        triggerStateMachine = TriggerStateMachine(runtimeConfig)
        emergencyActionManager = EmergencyActionManager(this, logTag)

        yamNetRunner = YAMNetRunner(this, runtimeConfig)
        helpClassifierRunner = HelpClassifierRunner(this)
        helpAsrRunner = HelpAsrRunner(this, runtimeConfig)

        startForeground(
            NotificationHelper.FOREGROUND_NOTIFICATION_ID,
            notificationHelper.buildForegroundNotification("Starting SOS listener"),
        )

        running = true
        mainHandler.post(stateTickRunnable)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_STOP -> {
                Log.i(logTag, "Stop action received")
                stopSelf()
                return START_NOT_STICKY
            }

            ACTION_UPDATE_PRIMARY -> {
                applyContactPayload(intent)
                return START_STICKY
            }

            ACTION_START, null -> {
                applyContactPayload(intent)
                startListeningPipeline()
                return START_STICKY
            }

            else -> return START_STICKY
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        running = false
        cooldownUntilMs = 0L

        mainHandler.removeCallbacks(stateTickRunnable)
        stopListeningPipeline()

        try {
            yamNetRunner?.close()
        } catch (_: Exception) {
            // Best effort.
        }
        yamNetRunner = null

        try {
            helpClassifierRunner?.close()
        } catch (_: Exception) {
            // Best effort.
        }
        helpClassifierRunner = null

        try {
            helpAsrRunner?.close()
        } catch (_: Exception) {
            // Best effort.
        }
        helpAsrRunner = null

        stopForeground(STOP_FOREGROUND_REMOVE)
    }

    private fun startListeningPipeline() {
        if (!running) {
            return
        }

        if (ContextCompat.checkSelfPermission(
                this,
                Manifest.permission.RECORD_AUDIO,
            ) != PackageManager.PERMISSION_GRANTED
        ) {
            notificationHelper.updateForeground("Missing microphone permission")
            notificationHelper.showAlert(
                title = "Microphone Permission Missing",
                message = "Grant microphone permission to continue SOS listening.",
            )
            return
        }

        if (audioRecorder != null) {
            return
        }

        try {
            audioRecorder =
                AudioRecorder(
                    sampleRate = runtimeConfig.sampleRate,
                    chunkSamples = runtimeConfig.chunkSamples,
                ) { chunk ->
                    processAudioChunk(chunk)
                }.also { recorder ->
                    recorder.start()
                }

            notificationHelper.updateForeground("Listening active")
            Log.i(logTag, "Audio listening pipeline started")
        } catch (error: Exception) {
            Log.e(logTag, "Failed to start audio recorder", error)
            notificationHelper.updateForeground("Failed to start listening")
            notificationHelper.showAlert(
                title = "SOS Listener Error",
                message = "Unable to start microphone listener.",
            )
        }
    }

    private fun stopListeningPipeline() {
        try {
            audioRecorder?.stop()
        } catch (_: Exception) {
            // Best effort.
        }
        audioRecorder = null
        Log.i(logTag, "Audio listening pipeline stopped")
    }

    private fun processAudioChunk(chunk: FloatArray) {
        if (!running) {
            return
        }

        val yamInference = yamNetRunner?.run(chunk) ?: return
        val embeddingHelpConfidence = helpClassifierRunner?.predictHelpConfidence(yamInference.embedding) ?: 0f
        val asrInference = helpAsrRunner?.process(chunk)
        val asrHelpConfidence = asrInference?.helpConfidence ?: 0f
        val helpConfidence = maxOf(embeddingHelpConfidence, asrHelpConfidence)
        val screamConfidence = yamInference.screamConfidence
        val now = System.currentTimeMillis()

        Log.d(
            logTag,
            "Chunk inference help=$helpConfidence (asr=$asrHelpConfidence emb=$embeddingHelpConfidence) scream=$screamConfidence",
        )

        if (asrHelpConfidence > 0f && !asrInference?.transcript.isNullOrBlank()) {
            Log.i(logTag, "ASR detected help token: ${asrInference?.transcript}")
        }

        val events = triggerStateMachine.process(helpConfidence, screamConfidence, now)
        cooldownUntilMs = triggerStateMachine.getCooldownUntilMs()

        if (events.isEmpty()) {
            return
        }

        for (event in events) {
            emitEvent(event)

            when (event.type) {
                DetectionEventType.HELP_DETECTED -> {
                    notificationHelper.updateForeground("Emergency audio detected (${event.count}/3)")
                }

                DetectionEventType.WINDOW_RESET -> {
                    notificationHelper.updateForeground("Listening active")
                }

                DetectionEventType.TRIGGERED -> {
                    Log.w(logTag, "Emergency trigger fired from audio model")
                    notificationHelper.showAlert(
                        title = "SOS Triggered",
                        message = "Calling contact and sending emergency SMS.",
                    )
                    triggerEmergencyWorkflow()
                }

                DetectionEventType.COOLDOWN -> {
                    val remaining = event.cooldownRemaining ?: 0
                    notificationHelper.updateForeground("In cooldown (${remaining}s)")
                }
            }
        }
    }

    private fun tickStateMachine() {
        val now = System.currentTimeMillis()
        val events = triggerStateMachine.tick(now)
        cooldownUntilMs = triggerStateMachine.getCooldownUntilMs()

        for (event in events) {
            emitEvent(event)
            if (event.type == DetectionEventType.COOLDOWN) {
                val remaining = event.cooldownRemaining ?: 0
                notificationHelper.updateForeground("In cooldown (${remaining}s)")
            }
            if (event.type == DetectionEventType.WINDOW_RESET) {
                notificationHelper.updateForeground("Listening active")
            }
        }
    }

    private fun triggerEmergencyWorkflow() {
        val primary = primaryNumber.trim()
        if (primary.isEmpty()) {
            notificationHelper.showAlert(
                title = "SOS Triggered",
                message = "No primary contact number configured.",
            )
            Log.e(logTag, "Primary number missing on trigger")
            return
        }

        val numbers =
            if (allNumbers.isEmpty()) {
                listOf(primary)
            } else {
                allNumbers
            }

        startUnbreakableSosLoop(numbers)

        notificationHelper.showAlert(
            title = "SOS Loop Started",
            message = "ProteqMe is sending location SMS and calling contacts.",
        )
        Log.w(logTag, "Unbreakable SOS loop started for ${numbers.size} contacts")
    }

    private fun startUnbreakableSosLoop(numbers: List<String>) {
        val prefs = SosLoopPrefs(this)
        val contacts =
            numbers.mapIndexed { index, phone ->
                SosContactEntry(
                    phone = phone,
                    name = "Contact ${index + 1}",
                    priority = index + 1,
                    language = "en",
                )
            }
        prefs.saveContacts(contacts)
        prefs.userName = "ProteqMe User"
        prefs.isActive = true
        prefs.callPaused = false
        prefs.callIndex = 0
        prefs.triggeredAtMs = System.currentTimeMillis()

        val intent =
            Intent(this, EmergencySosLoopService::class.java).apply {
                action = EmergencySosLoopService.ACTION_START
            }
        EmergencySosLoopService.start(this, intent)
    }

    private fun applyContactPayload(intent: Intent?) {
        val updatedPrimary = intent?.getStringExtra(EXTRA_PRIMARY_NUMBER).orEmpty().trim()
        if (updatedPrimary.isNotEmpty()) {
            primaryNumber = updatedPrimary
        }

        val updatedNumbers =
            intent
                ?.getStringArrayListExtra(EXTRA_ALL_NUMBERS)
                ?.map { it.trim() }
                ?.filter { it.isNotEmpty() }
                ?.distinct()

        if (!updatedNumbers.isNullOrEmpty()) {
            allNumbers = updatedNumbers
        } else if (allNumbers.isEmpty() && primaryNumber.isNotEmpty()) {
            allNumbers = listOf(primaryNumber)
        }

        Log.i(logTag, "Contact payload updated. primary=$primaryNumber all=${allNumbers.size}")
    }

    private fun emitEvent(event: DetectionEvent) {
        ListenerEventStreamHandler.emit(event)
        Log.i(logTag, "Event emitted: ${event.type.wireName} count=${event.count}")
    }

    companion object {
        const val ACTION_START = "com.proteqme.action.START"
        const val ACTION_STOP = "com.proteqme.action.STOP"
        const val ACTION_UPDATE_PRIMARY = "com.proteqme.action.UPDATE_PRIMARY"

        const val EXTRA_PRIMARY_NUMBER = "extra_primary_number"
        const val EXTRA_ALL_NUMBERS = "extra_all_numbers"

        @Volatile
        private var running = false

        @Volatile
        private var cooldownUntilMs: Long = 0L

        fun isServiceRunning(): Boolean = running

        fun cooldownRemainingSeconds(nowMs: Long = System.currentTimeMillis()): Int {
            val ms = cooldownUntilMs - nowMs
            if (ms <= 0L) {
                return 0
            }
            return ((ms + 999L) / 1000L).toInt()
        }
    }
}
