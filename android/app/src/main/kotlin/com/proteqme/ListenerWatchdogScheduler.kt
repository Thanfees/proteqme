package com.proteqme

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log

object ListenerWatchdogScheduler {
    private const val TAG = "ListenerWatchdogScheduler"
    private const val REQUEST_CODE = 77001

    fun schedule(context: Context) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager
        if (alarmManager == null) return

        val intent =
            Intent(context, ListenerWatchdogReceiver::class.java).apply {
                action = ListenerWatchdogReceiver.ACTION_TICK
            }
        val pending =
            PendingIntent.getBroadcast(
                context,
                REQUEST_CODE,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )

        val triggerAt = System.currentTimeMillis() + 90_000L
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                alarmManager.setExactAndAllowWhileIdle(
                    AlarmManager.RTC_WAKEUP,
                    triggerAt,
                    pending,
                )
            } else {
                alarmManager.setExact(AlarmManager.RTC_WAKEUP, triggerAt, pending)
            }
            Log.i(TAG, "Watchdog scheduled")
        } catch (error: Exception) {
            Log.w(TAG, "Exact alarm failed, using inexact", error)
            alarmManager.setInexactRepeating(
                AlarmManager.RTC_WAKEUP,
                triggerAt,
                120_000L,
                pending,
            )
        }
    }

    fun cancel(context: Context) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager ?: return
        val intent =
            Intent(context, ListenerWatchdogReceiver::class.java).apply {
                action = ListenerWatchdogReceiver.ACTION_TICK
            }
        val pending =
            PendingIntent.getBroadcast(
                context,
                REQUEST_CODE,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
        alarmManager.cancel(pending)
    }
}
