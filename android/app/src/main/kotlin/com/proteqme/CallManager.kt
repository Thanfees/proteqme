package com.proteqme

import android.Manifest
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.telecom.TelecomManager
import android.util.Log
import androidx.core.content.ContextCompat

class CallManager(
    private val context: Context,
    private val logTag: String = "CallManager",
) {
    fun makeEmergencyCall(phoneNumber: String): Boolean {
        val sanitized = phoneNumber.trim()
        if (sanitized.isEmpty()) {
            Log.e(logTag, "Primary number is empty")
            return false
        }

        val uri = Uri.parse("tel:$sanitized")
        if (hasPermission(Manifest.permission.CALL_PHONE)) {
            if (placeCallWithTelecom(uri)) {
                return true
            }

            val callIntent = Intent(Intent.ACTION_CALL, uri)
            if (startActivitySafely(callIntent)) {
                return true
            }
        }

        return openDialer(sanitized)
    }

    private fun openDialer(phoneNumber: String): Boolean {
        val intent = Intent(Intent.ACTION_DIAL, Uri.parse("tel:$phoneNumber"))
        return startActivitySafely(intent)
    }

    private fun startActivitySafely(intent: Intent): Boolean {
        return try {
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            context.startActivity(intent)
            true
        } catch (error: Exception) {
            Log.e(logTag, "Unable to start activity for intent: ${intent.action}", error)
            false
        }
    }

    private fun placeCallWithTelecom(uri: Uri): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) {
            return false
        }

        val telecomManager = context.getSystemService(TelecomManager::class.java) ?: return false
        return try {
            telecomManager.placeCall(uri, null)
            true
        } catch (error: Exception) {
            Log.w(logTag, "TelecomManager.placeCall() failed", error)
            false
        }
    }

    private fun hasPermission(permission: String): Boolean {
        return ContextCompat.checkSelfPermission(context, permission) == PackageManager.PERMISSION_GRANTED
    }
}
