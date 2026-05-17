package com.proteqme

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log

/**
 * Schedules / cancels the two AlarmManager alarms behind the Safe Journey
 * dead-man's switch:
 *
 *   * primary expiry  → [OverwatchExpiredReceiver] with [ACTION_EXPIRED]
 *   * 60s warning     → [OverwatchExpiredReceiver] (same receiver, different
 *                       action) with [ACTION_WARNING]
 *
 * Uses `setExactAndAllowWhileIdle` for sub-second accuracy. Falls back to the
 * inexact `setAndAllowWhileIdle` on devices/OEMs (Android 12+) where
 * `canScheduleExactAlarms()` returns false.
 */
object OverwatchScheduler {
    private const val TAG = "OverwatchScheduler"

    private const val REQUEST_CODE_EXPIRY = 7701
    private const val REQUEST_CODE_WARNING = 7702

    /** Warning alarm fires this many ms before the expiry alarm. */
    private const val WARNING_LEAD_MS = 60_000L

    const val ACTION_EXPIRED = "com.proteqme.OVERWATCH_EXPIRED"
    const val ACTION_WARNING = "com.proteqme.OVERWATCH_WARNING"

    fun schedule(
        context: Context,
        durationSeconds: Int,
        destination: String,
        userName: String,
        primaryNumber: String,
        contactsJson: String,
    ) {
        val nowMs = System.currentTimeMillis()
        val endAtMs = nowMs + durationSeconds.coerceAtLeast(1) * 1000L

        val prefs = OverwatchPrefs(context)
        prefs.save(
            startAtMs = nowMs,
            endAtMs = endAtMs,
            destination = destination.trim(),
            userName = userName.trim(),
            primaryNumber = primaryNumber.trim(),
            contactsJson = contactsJson,
        )

        armAlarms(context, endAtMs)
        Log.i(TAG, "Overwatch armed for ${durationSeconds}s. endAtMs=$endAtMs")
    }

    fun cancel(context: Context) {
        val alarmManager = alarmManagerOrNull(context) ?: return
        alarmManager.cancel(buildExpiryPendingIntent(context))
        alarmManager.cancel(buildWarningPendingIntent(context))
        OverwatchPrefs(context).clear()
        Log.i(TAG, "Overwatch alarms cancelled")
    }

    /**
     * Called from [BootReceiver]. If the saved end time is still in the future
     * the alarms are re-armed using the surviving prefs. If the timer expired
     * while the device was off the expiry receiver is fired immediately so the
     * SOS workflow runs even after late boots.
     */
    fun rescheduleAfterBoot(context: Context) {
        val prefs = OverwatchPrefs(context)
        if (!prefs.isActive()) {
            return
        }

        val nowMs = System.currentTimeMillis()
        if (prefs.endAtMs <= nowMs) {
            Log.w(TAG, "Boot detected — overwatch expired while powered off, firing now")
            val intent = Intent(context, OverwatchExpiredReceiver::class.java).apply {
                action = ACTION_EXPIRED
                setPackage(context.packageName)
            }
            context.sendBroadcast(intent)
            return
        }

        armAlarms(context, prefs.endAtMs)
        Log.i(TAG, "Boot detected — overwatch re-armed, endAtMs=${prefs.endAtMs}")
    }

    private fun armAlarms(context: Context, endAtMs: Long) {
        val alarmManager = alarmManagerOrNull(context) ?: return
        val canExact = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            alarmManager.canScheduleExactAlarms()
        } else {
            true
        }

        if (!canExact) {
            Log.w(
                TAG,
                "canScheduleExactAlarms() == false — falling back to setAndAllowWhileIdle",
            )
        }

        val expiryIntent = buildExpiryPendingIntent(context)
        scheduleAlarm(alarmManager, endAtMs, expiryIntent, canExact)

        val warningAtMs = endAtMs - WARNING_LEAD_MS
        if (warningAtMs > System.currentTimeMillis() + 1_000L) {
            val warningIntent = buildWarningPendingIntent(context)
            scheduleAlarm(alarmManager, warningAtMs, warningIntent, canExact)
        }
    }

    private fun scheduleAlarm(
        alarmManager: AlarmManager,
        triggerAtMs: Long,
        pending: PendingIntent,
        canExact: Boolean,
    ) {
        try {
            if (canExact) {
                alarmManager.setExactAndAllowWhileIdle(
                    AlarmManager.RTC_WAKEUP,
                    triggerAtMs,
                    pending,
                )
            } else {
                alarmManager.setAndAllowWhileIdle(
                    AlarmManager.RTC_WAKEUP,
                    triggerAtMs,
                    pending,
                )
            }
        } catch (security: SecurityException) {
            Log.e(TAG, "Exact alarm denied by OS, retrying inexact", security)
            alarmManager.setAndAllowWhileIdle(
                AlarmManager.RTC_WAKEUP,
                triggerAtMs,
                pending,
            )
        }
    }

    private fun buildExpiryPendingIntent(context: Context): PendingIntent {
        val intent = Intent(context, OverwatchExpiredReceiver::class.java).apply {
            action = ACTION_EXPIRED
            setPackage(context.packageName)
        }
        return PendingIntent.getBroadcast(
            context,
            REQUEST_CODE_EXPIRY,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    private fun buildWarningPendingIntent(context: Context): PendingIntent {
        val intent = Intent(context, OverwatchExpiredReceiver::class.java).apply {
            action = ACTION_WARNING
            setPackage(context.packageName)
        }
        return PendingIntent.getBroadcast(
            context,
            REQUEST_CODE_WARNING,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    private fun alarmManagerOrNull(context: Context): AlarmManager? {
        return context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager
    }
}
