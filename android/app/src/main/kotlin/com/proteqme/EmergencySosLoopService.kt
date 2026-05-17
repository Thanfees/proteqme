package com.proteqme

import android.app.Service
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.Handler
import android.os.HandlerThread
import android.os.IBinder
import android.os.Looper
import android.util.Log
import androidx.core.content.ContextCompat

/**
 * Unbreakable SOS loop: periodic SMS with GPS + sequential call escalation.
 */
class EmergencySosLoopService : Service() {
    private val logTag = "EmergencySosLoop"
    private val mainHandler = Handler(Looper.getMainLooper())
    private lateinit var workerThread: HandlerThread
    private lateinit var workerHandler: Handler

    private lateinit var prefs: SosLoopPrefs
    private lateinit var notificationHelper: NotificationHelper
    private lateinit var locationHelper: LocationHelper
    private lateinit var smsHelper: SmsManagerHelper
    private lateinit var callEscalation: CallEscalationManager

    /** First SMS tick must finish before we ring the first contact. */
    private var pendingFirstDial = false

    private val smsRunnable =
        object : Runnable {
            override fun run() {
                if (!prefs.isActive) return
                tickSmsAndGps()
                val intervalMs = prefs.smsIntervalSec * 1000L
                workerHandler.postDelayed(this, intervalMs)
            }
        }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        workerThread = HandlerThread("EmergencySosLoopWorker").apply { start() }
        workerHandler = Handler(workerThread.looper)

        prefs = SosLoopPrefs(this)
        notificationHelper = NotificationHelper(this)
        notificationHelper.createChannels()
        locationHelper = LocationHelper(this, logTag)
        smsHelper = SmsManagerHelper(this, logTag)
        val callManager = CallManager(this, notificationHelper, logTag)
        callEscalation = CallEscalationManager(this, callManager, logTag)

        callEscalation.onHumanAnswered = {
            prefs.callPaused = true
            notificationHelper.updateForeground("SOS active — contact answered. SMS continues.")
            Log.i(logTag, "Call answered >=40s — pausing dial loop")
        }

        callEscalation.onEscalateNext = {
            if (prefs.isActive && !prefs.callPaused) {
                prefs.callIndex += 1
                maybeDialNext()
            }
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_DISARM -> {
                disarm()
                stopSelf()
                return START_NOT_STICKY
            }

            ACTION_START, null -> {
                if (intent?.action == ACTION_START) {
                    applyStartExtras(intent)
                }

                if (!prefs.isActive) {
                    stopSelf()
                    return START_NOT_STICKY
                }

                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    startForeground(
                        NotificationHelper.SOS_LOOP_NOTIFICATION_ID,
                        notificationHelper.buildSosLoopNotification("ProteqMe SOS active"),
                        ServiceInfo.FOREGROUND_SERVICE_TYPE_LOCATION or
                            ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC,
                    )
                } else {
                    startForeground(
                        NotificationHelper.SOS_LOOP_NOTIFICATION_ID,
                        notificationHelper.buildSosLoopNotification("ProteqMe SOS active"),
                    )
                }

                workerHandler.removeCallbacks(smsRunnable)
                pendingFirstDial = !prefs.callPaused
                workerHandler.post(smsRunnable)

                return START_STICKY
            }

            else -> return START_STICKY
        }
    }

    override fun onDestroy() {
        workerHandler.removeCallbacks(smsRunnable)
        workerThread.quitSafely()
        callEscalation.stop()
        if (!prefs.isActive) {
            stopForeground(STOP_FOREGROUND_REMOVE)
        }
        super.onDestroy()
    }

    private fun applyStartExtras(intent: Intent) {
        val userName = intent.getStringExtra(EXTRA_USER_NAME)
        if (!userName.isNullOrBlank()) {
            prefs.userName = userName.trim()
        }

        val interval = intent.getIntExtra(EXTRA_SMS_INTERVAL_SEC, 0)
        if (interval > 0) {
            prefs.smsIntervalSec = interval
        }

        val contactsJson = intent.getStringExtra(EXTRA_CONTACTS_JSON)
        if (!contactsJson.isNullOrBlank()) {
            prefs.saveContacts(SosLoopPrefs.parseContactsFromJson(contactsJson))
        }

        prefs.isActive = true
        prefs.callPaused = false
        prefs.callIndex = 0
        prefs.triggeredAtMs = System.currentTimeMillis()
    }

    /** Runs on [workerHandler] thread — never call from main. */
    private fun tickSmsAndGps() {
        val contacts = prefs.loadContacts()
        if (contacts.isEmpty()) {
            Log.e(logTag, "No contacts for SMS loop")
            return
        }

        // First-call burst can be slow on cold GPS; cap so we never trigger ANR / FGS timeout.
        val location = locationHelper.getBestLocation(timeoutMs = 8_000L)
        val numbers = contacts.map { it.phone }.distinct()

        if (location != null) {
            contacts.forEachIndexed { index, contact ->
                val message =
                    SosMessageTemplates.ongoing(
                        prefs.userName,
                        location.latitude,
                        location.longitude,
                        contact.language,
                    )
                workerHandler.postDelayed({
                    if (prefs.isActive) {
                        smsHelper.sendEmergencySms(listOf(contact.phone), message)
                    }
                }, index * 1_500L)
            }
        } else {
            val fallback =
                "URGENT ONGOING SOS: ${prefs.userName} is in danger! Location unavailable."
            smsHelper.sendEmergencySms(numbers, fallback)
        }

        mainHandler.post {
            notificationHelper.updateForeground(
                "SOS active — location SMS sent (${contacts.size} contacts)",
            )
        }

        // Ring the first contact only AFTER SMS are dispatched (priority + buffer).
        if (pendingFirstDial) {
            pendingFirstDial = false
            val smsDispatchMs = contacts.size * 1_500L
            val callDelayMs = smsDispatchMs + 3_000L
            mainHandler.postDelayed({
                if (prefs.isActive && !prefs.callPaused) {
                    maybeDialNext()
                }
            }, callDelayMs)
        }
    }

    private fun maybeDialNext() {
        if (prefs.callPaused) return

        val contacts = prefs.loadContacts()
        if (contacts.isEmpty()) return

        val index = prefs.callIndex
        if (index >= contacts.size) {
            Log.i(logTag, "All contacts dialed")
            return
        }

        val contact = contacts[index]
        notificationHelper.updateForeground("Calling ${contact.name} (priority ${contact.priority})")
        callEscalation.dial(contact.phone)
    }

    private fun disarm() {
        val contacts = prefs.loadContacts()
        contacts.forEachIndexed { index, contact ->
            val msg = SosMessageTemplates.resolved(prefs.userName, contact.language)
            workerHandler.postDelayed({
                smsHelper.sendEmergencySms(listOf(contact.phone), msg)
            }, index * 1_500L)
        }

        prefs.clearLoop()
        callEscalation.stop()
        workerHandler.removeCallbacks(smsRunnable)
        notificationHelper.updateForeground("SOS disarmed")
        Log.i(logTag, "SOS loop disarmed")
    }

    companion object {
        const val ACTION_START = "com.proteqme.action.SOS_LOOP_START"
        const val ACTION_DISARM = "com.proteqme.action.SOS_LOOP_DISARM"

        const val EXTRA_USER_NAME = "extra_user_name"
        const val EXTRA_SMS_INTERVAL_SEC = "extra_sms_interval_sec"
        const val EXTRA_CONTACTS_JSON = "extra_contacts_json"

        fun start(context: android.content.Context, intent: Intent) {
            intent.setClass(context, EmergencySosLoopService::class.java)
            intent.action = ACTION_START
            ContextCompat.startForegroundService(context, intent)
        }

        fun disarm(context: android.content.Context) {
            val intent =
                Intent(context, EmergencySosLoopService::class.java).apply {
                    action = ACTION_DISARM
                }
            ContextCompat.startForegroundService(context, intent)
        }

        fun isActive(context: android.content.Context): Boolean {
            return SosLoopPrefs(context).isActive
        }
    }
}
