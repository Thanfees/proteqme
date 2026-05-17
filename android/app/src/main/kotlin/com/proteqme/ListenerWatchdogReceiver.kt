package com.proteqme

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import androidx.core.content.ContextCompat

/** Restarts listening FGS if user enabled it but HyperOS killed the process. */
class ListenerWatchdogReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        val prefs = ListenerPrefs(context)
        if (!prefs.userWantsListening) return
        if (SosListenerService.isServiceRunning()) return

        val primary = prefs.primaryNumber()
        if (primary.isEmpty()) {
            Log.w(TAG, "Watchdog: no primary number saved")
            return
        }

        Log.i(TAG, "Watchdog restarting SOS listener")
        val serviceIntent =
            Intent(context, SosListenerService::class.java).apply {
                action = SosListenerService.ACTION_START
                putExtra(SosListenerService.EXTRA_PRIMARY_NUMBER, primary)
                putStringArrayListExtra(
                    SosListenerService.EXTRA_ALL_NUMBERS,
                    ArrayList(prefs.allNumbers().ifEmpty { listOf(primary) }),
                )
            }
        ContextCompat.startForegroundService(context, serviceIntent)
        ListenerWatchdogScheduler.schedule(context)
    }

    companion object {
        private const val TAG = "ListenerWatchdog"
        const val ACTION_TICK = "com.proteqme.action.LISTENER_WATCHDOG"
    }
}
