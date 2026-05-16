package com.proteqme.proteqme

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

/// Resumes Flutter after reboot when SOS was active — DB check happens in Dart `main`.
class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        if (intent?.action != Intent.ACTION_BOOT_COMPLETED) return
        Log.i("ProteqMe", "BOOT_COMPLETED — launching app to resume SOS if active")
        val launch = Intent(context, MainActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            putExtra("boot_resume", true)
        }
        context.startActivity(launch)
    }
}
