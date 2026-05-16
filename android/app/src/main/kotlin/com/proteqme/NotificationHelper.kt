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

        manager.createNotificationChannel(foregroundChannel)
        manager.createNotificationChannel(alertChannel)
        manager.createNotificationChannel(sosLoopChannel)
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
        const val FOREGROUND_NOTIFICATION_ID = 443001
        const val SOS_LOOP_NOTIFICATION_ID = 443002
    }
}
