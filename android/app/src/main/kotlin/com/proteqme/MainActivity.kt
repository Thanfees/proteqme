package com.proteqme

import android.content.Intent
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    private val methodChannelName = "com.proteqme/service"
    private val eventChannelName = "com.proteqme/service/events"
    private val overwatchMethodChannelName = "com.proteqme/overwatch"
    private val overwatchEventChannelName = "com.proteqme/overwatch/events"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, eventChannelName)
            .setStreamHandler(ListenerEventStreamHandler())

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, methodChannelName)
            .setMethodCallHandler { call, result ->
                handleMethodCall(call, result)
            }

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, overwatchEventChannelName)
            .setStreamHandler(OverwatchEventBus)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, overwatchMethodChannelName)
            .setMethodCallHandler { call, result ->
                handleOverwatchCall(call, result)
            }
    }

    private fun handleOverwatchCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "start" -> {
                val duration = call.argument<Int>("durationSeconds") ?: 0
                if (duration <= 0) {
                    result.error("INVALID_ARGUMENT", "durationSeconds must be > 0", null)
                    return
                }
                val destination = call.argument<String>("destination").orEmpty().trim()
                val userName = call.argument<String>("userName").orEmpty().trim()
                val primaryNumber = call.argument<String>("primaryNumber").orEmpty().trim()
                val contactsJson = call.argument<String>("contactsJson").orEmpty()

                if (primaryNumber.isEmpty()) {
                    result.error(
                        "INVALID_ARGUMENT",
                        "primaryNumber is required so we can escalate at expiry",
                        null,
                    )
                    return
                }

                OverwatchScheduler.schedule(
                    context = this,
                    durationSeconds = duration,
                    destination = destination,
                    userName = userName,
                    primaryNumber = primaryNumber,
                    contactsJson = contactsJson,
                )
                result.success(null)
            }

            "cancel" -> {
                OverwatchScheduler.cancel(this)
                NotificationHelper(this).clearOverwatchWarningNotification()
                OverwatchEventBus.emit(mapOf("type" to "CANCELLED"))
                result.success(null)
            }

            "getStatus" -> {
                val prefs = OverwatchPrefs(this)
                result.success(
                    mapOf(
                        "active" to prefs.isActive(),
                        "remainingMs" to prefs.remainingMs(),
                        "destination" to prefs.destination,
                        "endAtMs" to prefs.endAtMs,
                        "startAtMs" to prefs.startAtMs,
                    ),
                )
            }

            else -> result.notImplemented()
        }
    }

    private fun handleMethodCall(call: MethodCall, result: MethodChannel.Result) {
        val emergencyExecutor = EmergencyWorkflowExecutor(this)

        when (call.method) {
            "startService" -> {
                val primaryNumber = call.argument<String>("primaryNumber").orEmpty().trim()
                if (primaryNumber.isEmpty()) {
                    result.error("INVALID_ARGUMENT", "primaryNumber is required", null)
                    return
                }

                val numbers = EmergencyWorkflowExecutor.parseNumbers(call.argument<List<*>>("allNumbers"))
                    .ifEmpty { listOf(primaryNumber) }

                val intent =
                    Intent(this, SosListenerService::class.java).apply {
                        action = SosListenerService.ACTION_START
                        putExtra(SosListenerService.EXTRA_PRIMARY_NUMBER, primaryNumber)
                        putStringArrayListExtra(
                            SosListenerService.EXTRA_ALL_NUMBERS,
                            ArrayList(numbers),
                        )
                    }
                val listenerPrefs = ListenerPrefs(this)
                listenerPrefs.userWantsListening = true
                listenerPrefs.saveContactPayload(primaryNumber, numbers)

                ContextCompat.startForegroundService(this, intent)
                ListenerWatchdogScheduler.schedule(this)
                result.success(null)
            }

            "stopService" -> {
                ListenerPrefs(this).userWantsListening = false
                ListenerWatchdogScheduler.cancel(this)

                val intent =
                    Intent(this, SosListenerService::class.java).apply {
                        action = SosListenerService.ACTION_STOP
                    }
                startService(intent)
                stopService(Intent(this, SosListenerService::class.java))
                result.success(null)
            }

            "updatePrimaryNumber" -> {
                val primaryNumber = call.argument<String>("primaryNumber").orEmpty().trim()
                if (primaryNumber.isEmpty()) {
                    result.error("INVALID_ARGUMENT", "primaryNumber is required", null)
                    return
                }

                val numbers = EmergencyWorkflowExecutor.parseNumbers(call.argument<List<*>>("allNumbers"))
                    .ifEmpty { listOf(primaryNumber) }

                ListenerPrefs(this).saveContactPayload(primaryNumber, numbers)

                if (SosListenerService.isServiceRunning()) {
                    val intent =
                        Intent(this, SosListenerService::class.java).apply {
                            action = SosListenerService.ACTION_UPDATE_PRIMARY
                            putExtra(SosListenerService.EXTRA_PRIMARY_NUMBER, primaryNumber)
                            putStringArrayListExtra(
                                SosListenerService.EXTRA_ALL_NUMBERS,
                                ArrayList(numbers),
                            )
                        }
                    startService(intent)
                }

                result.success(null)
            }

            "getServiceStatus" -> {
                val listenerPrefs = ListenerPrefs(this)
                result.success(
                    mapOf(
                        "running" to SosListenerService.isServiceRunning(),
                        "cooldownRemaining" to SosListenerService.cooldownRemainingSeconds(),
                        "userWantsListening" to listenerPrefs.userWantsListening,
                        "primaryNumber" to listenerPrefs.primaryNumber(),
                        "allNumbers" to listenerPrefs.allNumbers(),
                    ),
                )
            }

            "makeEmergencyCall" -> {
                val phoneNumber = call.argument<String>("phoneNumber").orEmpty().trim()
                if (phoneNumber.isEmpty()) {
                    result.error("INVALID_ARGUMENT", "phoneNumber is required", null)
                    return
                }

                val started = emergencyExecutor.makeEmergencyCall(phoneNumber)
                result.success(started)
            }

            "sendEmergencySms" -> {
                val numbers = EmergencyWorkflowExecutor.parseNumbers(call.argument<List<*>>("numbers"))
                val message = call.argument<String>("message").orEmpty().trim()

                if (numbers.isEmpty() || message.isEmpty()) {
                    result.error("INVALID_ARGUMENT", "numbers and message are required", null)
                    return
                }

                val sent = emergencyExecutor.sendSms(numbers, message)
                result.success(sent)
            }

            "startSosLoop" -> {
                val userName = call.argument<String>("userName")?.trim().orEmpty()
                val intervalSec = call.argument<Int>("smsIntervalSec") ?: 360
                val contactsJson = call.argument<String>("contactsJson").orEmpty()
                if (contactsJson.isEmpty()) {
                    result.error("INVALID_ARGUMENT", "contactsJson is required", null)
                    return
                }

                val prefs = SosLoopPrefs(this)
                prefs.userName = userName.ifEmpty { "ProteqMe User" }
                prefs.smsIntervalSec = intervalSec
                prefs.saveContacts(SosLoopPrefs.parseContactsFromJson(contactsJson))
                prefs.isActive = true
                prefs.callPaused = false
                prefs.callIndex = 0
                prefs.triggeredAtMs = System.currentTimeMillis()

                val intent =
                    Intent(this, EmergencySosLoopService::class.java).apply {
                        action = EmergencySosLoopService.ACTION_START
                        putExtra(EmergencySosLoopService.EXTRA_USER_NAME, prefs.userName)
                        putExtra(EmergencySosLoopService.EXTRA_SMS_INTERVAL_SEC, prefs.smsIntervalSec)
                        putExtra(EmergencySosLoopService.EXTRA_CONTACTS_JSON, contactsJson)
                    }
                EmergencySosLoopService.start(this, intent)
                result.success(true)
            }

            "disarmSosLoop" -> {
                EmergencySosLoopService.disarm(this)
                result.success(true)
            }

            "getSosLoopStatus" -> {
                val prefs = SosLoopPrefs(this)
                result.success(
                    mapOf(
                        "active" to prefs.isActive,
                        "callPaused" to prefs.callPaused,
                        "smsIntervalSec" to prefs.smsIntervalSec,
                        "triggeredAtMs" to prefs.triggeredAtMs,
                    ),
                )
            }

            "triggerEmergencyWorkflow" -> {
                val primaryNumber = call.argument<String>("primaryNumber").orEmpty().trim()
                val numbers = EmergencyWorkflowExecutor.parseNumbers(call.argument<List<*>>("allNumbers"))
                val message = call.argument<String>("message")

                if (primaryNumber.isEmpty()) {
                    result.error("INVALID_ARGUMENT", "primaryNumber is required", null)
                    return
                }

                val response =
                    emergencyExecutor
                        .execute(
                            primaryNumber = primaryNumber,
                            allNumbers = numbers.ifEmpty { listOf(primaryNumber) },
                            providedMessage = message,
                        ).toMap()

                result.success(response)
            }

            else -> result.notImplemented()
        }
    }
}
