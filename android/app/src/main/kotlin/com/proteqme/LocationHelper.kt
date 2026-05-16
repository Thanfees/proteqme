package com.proteqme

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.location.Location
import android.location.LocationManager
import android.os.CancellationSignal
import android.os.Looper
import android.util.Log
import androidx.core.content.ContextCompat
import com.google.android.gms.location.CurrentLocationRequest
import com.google.android.gms.location.LocationServices
import com.google.android.gms.location.Priority
import com.google.android.gms.tasks.CancellationTokenSource
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicReference

/**
 * Fetches a fresh GPS fix when possible, then falls back to last-known providers.
 */
class LocationHelper(
    private val context: Context,
    private val logTag: String = "LocationHelper",
) {
    fun getBestLocation(timeoutMs: Long = 25_000L): Location? {
        if (!hasAnyLocationPermission()) {
            Log.w(logTag, "Location permission missing")
            return null
        }

        val fused = tryFreshFusedLocation(timeoutMs)
        if (fused != null && isUsable(fused)) {
            Log.i(logTag, "Using fused location ageMs=${locationAgeMs(fused)}")
            return fused
        }

        val lastKnown = getLastKnownBest()
        if (lastKnown != null) {
            Log.i(logTag, "Using last-known location ageMs=${locationAgeMs(lastKnown)}")
        } else {
            Log.w(logTag, "No location available")
        }
        return lastKnown
    }

    private fun tryFreshFusedLocation(timeoutMs: Long): Location? {
        return try {
            val client = LocationServices.getFusedLocationProviderClient(context)
            val result = AtomicReference<Location?>(null)
            val latch = CountDownLatch(1)
            val cancelSource = CancellationTokenSource()

            val request =
                CurrentLocationRequest.Builder()
                    .setPriority(Priority.PRIORITY_HIGH_ACCURACY)
                    .setMaxUpdateAgeMillis(0)
                    .build()

            client
                .getCurrentLocation(request, cancelSource.token)
                .addOnSuccessListener { location ->
                    result.set(location)
                    latch.countDown()
                }
                .addOnFailureListener { error ->
                    Log.w(logTag, "Fused location failed: ${error.message}")
                    latch.countDown()
                }

            if (!latch.await(timeoutMs, TimeUnit.MILLISECONDS)) {
                cancelSource.cancel()
                Log.w(logTag, "Fused location timed out after ${timeoutMs}ms")
            }

            result.get()
        } catch (error: Exception) {
            Log.w(logTag, "Fused location unavailable", error)
            null
        }
    }

    private fun getLastKnownBest(): Location? {
        val locationManager =
            context.getSystemService(Context.LOCATION_SERVICE) as? LocationManager ?: return null

        val providers =
            listOf(
                LocationManager.GPS_PROVIDER,
                LocationManager.NETWORK_PROVIDER,
                LocationManager.PASSIVE_PROVIDER,
            )

        var best: Location? = null
        for (provider in providers) {
            try {
                val location = locationManager.getLastKnownLocation(provider) ?: continue
                if (best == null || location.time > best.time) {
                    best = location
                }
            } catch (error: SecurityException) {
                Log.w(logTag, "SecurityException for provider $provider", error)
            }
        }
        return best
    }

    private fun hasAnyLocationPermission(): Boolean {
        val fine =
            ContextCompat.checkSelfPermission(
                context,
                Manifest.permission.ACCESS_FINE_LOCATION,
            ) == PackageManager.PERMISSION_GRANTED
        val coarse =
            ContextCompat.checkSelfPermission(
                context,
                Manifest.permission.ACCESS_COARSE_LOCATION,
            ) == PackageManager.PERMISSION_GRANTED
        return fine || coarse
    }

    private fun isUsable(location: Location): Boolean {
        return location.latitude != 0.0 || location.longitude != 0.0
    }

    private fun locationAgeMs(location: Location): Long {
        return (System.currentTimeMillis() - location.time).coerceAtLeast(0L)
    }
}
