package com.proteqme

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.app.NotificationCompat

class NotificationHelper(private val context: Context) {
    private val manager: NotificationManager =
        context.getSystemService(NotificationManager::class.java)

    fun createChannels() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            return
        }

        val foregroundChannel = NotificationChannel(
            FOREGROUND_CHANNEL_ID,
            "SOS Listener Service",
            NotificationManager.IMPORTANCE_LOW,
        ).apply {
            description = "Persistent notification for SOS listening"
        }

        val alertChannel = NotificationChannel(
            ALERT_CHANNEL_ID,
            "SOS Alerts",
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = "Emergency trigger and call notifications"
        }

        val sosLoopChannel = NotificationChannel(
            SOS_LOOP_CHANNEL_ID,
            "ProteqMe SOS Loop",
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = "Active emergency — cannot be dismissed until disarmed"
            setShowBadge(true)
        }

        val overwatchChannel = NotificationChannel(
            OVERWATCH_CHANNEL_ID,
            "Safe Journey Overwatch",
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = "Warning when the Overwatch dead-man's switch is about to expire"
            setShowBadge(true)
        }

        manager.createNotificationChannel(foregroundChannel)
        manager.createNotificationChannel(alertChannel)
        manager.createNotificationChannel(sosLoopChannel)
        manager.createNotificationChannel(overwatchChannel)
    }

    fun buildForegroundNotification(contentText: String): Notification {
        val launchIntent =
            context.packageManager.getLaunchIntentForPackage(context.packageName)
                ?: Intent(context, MainActivity::class.java).apply {
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
        val pendingIntent = PendingIntent.getActivity(
            context,
            10,
            launchIntent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )

        return NotificationCompat.Builder(context, FOREGROUND_CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle("SOS Listening")
            .setContentText(contentText)
            .setOngoing(true)
            .setSilent(true)
            .setContentIntent(pendingIntent)
            .build()
    }

    fun updateForeground(contentText: String) {
        manager.notify(FOREGROUND_NOTIFICATION_ID, buildForegroundNotification(contentText))
    }

    fun buildSosLoopNotification(contentText: String): Notification {
        val launchIntent =
            context.packageManager.getLaunchIntentForPackage(context.packageName)
                ?: Intent(context, MainActivity::class.java).apply {
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
        val pendingIntent = PendingIntent.getActivity(
            context,
            11,
            launchIntent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )

        return NotificationCompat.Builder(context, SOS_LOOP_CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle("ProteqMe SOS Active")
            .setContentText(contentText)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setContentIntent(pendingIntent)
            .build()
    }

    /**
     * Posts a full-screen intent notification that launches [EmergencyActionActivity]
     * to make a call. Full-screen intents are the only reliable way to start an
     * Activity from a background FGS on Android 10+ / HyperOS.
     */
    fun showEmergencyCallNotification(phone: String) {
        val callIntent = EmergencyActionActivity.createCallIntent(context, phone)
        val fullScreenPending = PendingIntent.getActivity(
            context,
            CALL_REQUEST_CODE,
            callIntent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )

        val notification = NotificationCompat.Builder(context, ALERT_CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle("ProteqMe — Emergency Call")
            .setContentText("Calling $phone…")
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setCategory(NotificationCompat.CATEGORY_CALL)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setFullScreenIntent(fullScreenPending, true)
            .setOngoing(false)
            .setAutoCancel(true)
            .build()

        manager.notify(CALL_NOTIFICATION_ID, notification)
    }

    /**
     * High-priority notification fired 60 s before the Safe Journey timer
     * expires. Tapping it brings the user back into the app so they can verify
     * with biometrics before the dead-man's switch escalates to a full SOS.
     */
    fun showOverwatchWarningNotification(remainingSeconds: Int) {
        createChannels()
        val launchIntent =
            context.packageManager.getLaunchIntentForPackage(context.packageName)
                ?: Intent(context, MainActivity::class.java).apply {
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
        val pendingIntent = PendingIntent.getActivity(
            context,
            OVERWATCH_WARNING_REQUEST_CODE,
            launchIntent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )

        val notification = NotificationCompat.Builder(context, OVERWATCH_CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle("Overwatch expiring — verify your safety")
            .setContentText(
                "Your Safe Journey timer expires in ~${remainingSeconds}s. " +
                    "Open ProteqMe and tap 'I Arrived Safely'.",
            )
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setContentIntent(pendingIntent)
            .setFullScreenIntent(pendingIntent, true)
            .setAutoCancel(true)
            .build()

        manager.notify(OVERWATCH_WARNING_NOTIFICATION_ID, notification)
    }

    fun clearOverwatchWarningNotification() {
        manager.cancel(OVERWATCH_WARNING_NOTIFICATION_ID)
    }

    fun showAlert(title: String, message: String) {
        val notification = NotificationCompat.Builder(context, ALERT_CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(title)
            .setContentText(message)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setAutoCancel(true)
            .build()

        manager.notify((System.currentTimeMillis() % Int.MAX_VALUE).toInt(), notification)
    }

    companion object {
        const val FOREGROUND_CHANNEL_ID = "sos_listener_foreground"
        const val ALERT_CHANNEL_ID = "sos_listener_alerts"
        const val SOS_LOOP_CHANNEL_ID = "proteqme_sos_loop"
        const val OVERWATCH_CHANNEL_ID = "proteqme_overwatch"
        const val FOREGROUND_NOTIFICATION_ID = 443001
        const val SOS_LOOP_NOTIFICATION_ID = 443002
        const val CALL_NOTIFICATION_ID = 443003
        const val OVERWATCH_WARNING_NOTIFICATION_ID = 443004
        private const val CALL_REQUEST_CODE = 9001
        private const val OVERWATCH_WARNING_REQUEST_CODE = 9002
    }
}
