package com.proteqme

import android.content.BroadcastReceiver
import android.content.Context
import android.os.Handler
import android.os.HandlerThread
import android.util.Log
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * Single broadcast receiver that handles both the "60s warning" and the
 * "timer expired" alarms for the Safe Journey / Overwatch dead-man's switch.
 *
 * Long work — location lookup, SMS dispatch, foreground service launch — is
 * pushed onto a worker [HandlerThread] under [goAsync] so we never block the
 * receiver thread and risk an ANR. This mirrors the pattern used in
 * [EmergencySosLoopService].
 */
class OverwatchExpiredReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: android.content.Intent?) {
        val action = intent?.action ?: return
        val appContext = context.applicationContext
        val pendingResult = goAsync()

        val worker = HandlerThread("OverwatchExpiredWorker").apply { start() }
        Handler(worker.looper).post {
            try {
                when (action) {
                    OverwatchScheduler.ACTION_WARNING -> handleWarning(appContext)
                    OverwatchScheduler.ACTION_EXPIRED -> handleExpired(appContext)
                    else -> Log.w(TAG, "Unknown action: $action")
                }
            } catch (error: Exception) {
                Log.e(TAG, "Overwatch receiver failed", error)
            } finally {
                pendingResult.finish()
                worker.quitSafely()
            }
        }
    }

    private fun handleWarning(context: Context) {
        val prefs = OverwatchPrefs(context)
        if (!prefs.isActive()) {
            Log.i(TAG, "Warning fired but overwatch no longer active — ignoring")
            return
        }

        val remainingSeconds = (prefs.remainingMs() / 1000L).coerceAtLeast(0L).toInt()
        val notificationHelper = NotificationHelper(context)
        notificationHelper.showOverwatchWarningNotification(remainingSeconds)

        OverwatchEventBus.emit(
            mapOf(
                "type" to "EXPIRING_SOON",
                "remainingMs" to prefs.remainingMs(),
            ),
        )
        Log.w(TAG, "Overwatch warning fired (${remainingSeconds}s remaining)")
    }

    private fun handleExpired(context: Context) {
        val prefs = OverwatchPrefs(context)
        // Snapshot every field we still need before clearing so we never race
        // against a UI-side cancel that wipes prefs.
        val destination = prefs.destination
        val userName = prefs.userName
        val primaryNumber = prefs.primaryNumber
        val contactsJson = prefs.contactsJson
        val wasActive = prefs.isActive()
        prefs.clear()

        val notificationHelper = NotificationHelper(context)
        notificationHelper.clearOverwatchWarningNotification()

        if (!wasActive) {
            Log.i(TAG, "Expiry fired but overwatch was not active — ignoring")
            return
        }

        if (primaryNumber.isBlank()) {
            Log.e(TAG, "Cannot escalate: no primary number cached. Showing alert only.")
            notificationHelper.showAlert(
                title = "Safe Journey timer expired",
                message = "ProteqMe could not auto-escalate — no emergency contact saved.",
            )
            OverwatchEventBus.emit(
                mapOf(
                    "type" to "EXPIRED",
                    "escalated" to false,
                    "reason" to "missing_primary",
                ),
            )
            return
        }

        val allNumbers = parseAllNumbers(contactsJson, primaryNumber)
        val message = buildExpiredMessage(context, userName, destination)

        val executor = EmergencyWorkflowExecutor(context, logTag = TAG_EXECUTOR)
        val result = executor.execute(
            primaryNumber = primaryNumber,
            allNumbers = allNumbers,
            providedMessage = message,
        )

        Log.w(
            TAG,
            "Overwatch expired → smsSent=${result.smsSent} callStarted=${result.callStarted}",
        )

        // Kick off the unbreakable SOS loop so the recipients keep getting
        // location pings + escalation calls until the user disarms via the
        // biometric overlay — same path the button SOS uses.
        startUnbreakableLoop(context, userName, contactsJson, primaryNumber)

        OverwatchEventBus.emit(
            mapOf(
                "type" to "EXPIRED",
                "escalated" to true,
                "smsSent" to result.smsSent,
                "callStarted" to result.callStarted,
            ),
        )
    }

    private fun parseAllNumbers(contactsJson: String, primary: String): List<String> {
        val parsed = SosLoopPrefs.parseContactsFromJson(contactsJson)
        val numbers = parsed.map { it.phone }.filter { it.isNotBlank() }.toMutableList()
        if (numbers.none { it.equals(primary, ignoreCase = true) }) {
            numbers.add(0, primary)
        }
        return numbers.distinct()
    }

    private fun buildExpiredMessage(
        context: Context,
        userName: String,
        destination: String,
    ): String {
        val timestamp = SimpleDateFormat("yyyy-MM-dd HH:mm:ss", Locale.US).format(Date())
        val locationHelper = LocationHelper(context, TAG_EXECUTOR)
        val location = locationHelper.getBestLocation(timeoutMs = 8_000L)
        val mapsLink = location?.let {
            "https://maps.google.com/?q=${it.latitude},${it.longitude}"
        }
        return SosMessageTemplates.overwatchExpired(
            userName = userName,
            destination = destination,
            mapsLink = mapsLink,
            timestamp = timestamp,
        )
    }

    private fun startUnbreakableLoop(
        context: Context,
        userName: String,
        contactsJson: String,
        primaryNumber: String,
    ) {
        try {
            val loopPrefs = SosLoopPrefs(context)
            val contacts = SosLoopPrefs.parseContactsFromJson(contactsJson).ifEmpty {
                listOf(
                    SosContactEntry(
                        phone = primaryNumber,
                        name = "Primary contact",
                        priority = 1,
                        language = "en",
                    ),
                )
            }
            loopPrefs.userName = userName.ifBlank { "ProteqMe User" }
            loopPrefs.saveContacts(contacts)
            loopPrefs.isActive = true
            loopPrefs.callPaused = false
            loopPrefs.callIndex = 0
            loopPrefs.triggeredAtMs = System.currentTimeMillis()

            val intent = android.content.Intent(context, EmergencySosLoopService::class.java).apply {
                action = EmergencySosLoopService.ACTION_START
                putExtra(EmergencySosLoopService.EXTRA_USER_NAME, loopPrefs.userName)
                putExtra(EmergencySosLoopService.EXTRA_SMS_INTERVAL_SEC, loopPrefs.smsIntervalSec)
                putExtra(EmergencySosLoopService.EXTRA_CONTACTS_JSON, contactsJson)
            }
            EmergencySosLoopService.start(context, intent)
            Log.i(TAG, "Unbreakable SOS loop started from overwatch expiry")
        } catch (error: Exception) {
            Log.e(TAG, "Failed to start SOS loop from overwatch expiry", error)
        }
    }

    companion object {
        private const val TAG = "OverwatchExpired"
        private const val TAG_EXECUTOR = "OverwatchEmergency"
    }
}
