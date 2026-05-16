package com.proteqme

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import androidx.core.content.ContextCompat

/** Resumes the SOS loop after device reboot if still active. */
class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        if (intent?.action != Intent.ACTION_BOOT_COMPLETED &&
            intent?.action != "android.intent.action.QUICKBOOT_POWERON"
        ) {
            return
        }

        if (!SosLoopPrefs(context).isActive) {
            return
        }

        Log.i(TAG, "Boot completed — resuming SOS loop")
        val serviceIntent =
            Intent(context, EmergencySosLoopService::class.java).apply {
                action = EmergencySosLoopService.ACTION_START
            }
        ContextCompat.startForegroundService(context, serviceIntent)

        val launch = context.packageManager.getLaunchIntentForPackage(context.packageName)
        launch?.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        if (launch != null) {
            context.startActivity(launch)
        }
    }

    companion object {
        private const val TAG = "ProteqMeBootReceiver"
    }
}
