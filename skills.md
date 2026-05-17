# ProteqMe — Engineering Reference (skills.md)

Canonical technical guide for the ProteqMe Android safety app. Read this when you need to find where a feature is implemented, how the Flutter UI talks to the Kotlin services, what the SMS / call / GPS pipeline looks like end-to-end, and which on-device data stores back each screen.

| Identifier | Value |
|------------|-------|
| Product name | ProteqMe |
| Android application ID | `com.proteqme` |
| Kotlin package | `com.proteqme` |
| Flutter package | `proteqme` |
| Min platform | Android only (iOS support removed) |

---

## 1. Overview

ProteqMe is a single-purpose Android safety companion designed for people who need an SOS workflow that does not depend on a working internet connection or a third-party telephony provider. Every escalation path — SMS, voice call, location attachment, Bluetooth rescue beacon — runs entirely on the device using the user's own SIM card, Google Play Services for location, and a small set of TensorFlow Lite + Vosk models for on-device voice detection. The Convex cloud companion is strictly optional and is used only for OTP login, cross-device contact restore, live family map updates, and post-incident audit logs.

The app is built for users in environments where mobile data may be patchy but a basic 2G voice/SMS signal is available — for example commuters, lone walkers, students travelling between campuses, and women using ride-hailing apps in unfamiliar areas. It is also a "dead-man's switch" for any solo journey: the user arms an Overwatch timer before leaving, and if they fail to check in before it expires the same SOS workflow fires automatically. There is no IoT hardware, panic-button accessory, or carrier integration required.

On-device behaviour is split between a Flutter Riverpod UI layer (home, contacts, permissions, settings, logs, rescue mode, emergency overlay, auth) and a set of Kotlin foreground services and broadcast receivers (`SosListenerService` for voice detection, `EmergencySosLoopService` for the unbreakable SMS+call escalation loop, `OverwatchScheduler`/`OverwatchExpiredReceiver` for the dead-man's switch, `BootReceiver` and `ListenerWatchdogReceiver` for resilience). The two layers are bridged by two MethodChannels (`com.proteqme/service`, `com.proteqme/overwatch`) and two EventChannels (`com.proteqme/service/events`, `com.proteqme/overwatch/events`). Cloud-only features (Convex) live behind `lib/services/convex_service.dart` and degrade gracefully when `CONVEX_URL` / `CONVEX_DEPLOY_KEY` are not provided.

---

## 2. App architecture

### 2.1 Layer diagram

```
┌─────────────────────────────────────────────────────────────────┐
│  Flutter UI (Material 3, Google Fonts/Lexend, ProteqMe palette) │
│  lib/features/**/presentation/*                                 │
└─────────────────────────────────────────────────────────────────┘
                ▲                              │
                │ Riverpod NotifierProvider    │
                ▼                              ▼
┌─────────────────────────────────────────────────────────────────┐
│  Riverpod controllers (state) — listener, emergency, contacts,  │
│  permissions, overwatch (in progress)                           │
│  lib/features/**/presentation/*_controller.dart                 │
└─────────────────────────────────────────────────────────────────┘
                ▲                              │
                │ Use-cases / repositories     │
                ▼                              ▼
┌─────────────────────────────────────────────────────────────────┐
│  Domain (use-cases, repositories, entities)                     │
│  lib/features/**/domain/*                                       │
└─────────────────────────────────────────────────────────────────┘
                ▲                              │
                │                              │
                ▼                              ▼
┌──────────────────────────────┐  ┌──────────────────────────────┐
│  Local data (Hive + sqflite) │  │  Platform channel datasources│
│  lib/data/local/             │  │  lib/features/**/data/*      │
│  lib/features/**/data/       │  │  → MethodChannel             │
└──────────────────────────────┘  └──────────────────────────────┘
                                                │
                                                ▼
                              ┌───────────────────────────────────┐
                              │  Kotlin native layer              │
                              │  android/app/src/main/kotlin/...  │
                              │                                   │
                              │  • SosListenerService (FGS)       │
                              │  • EmergencySosLoopService (FGS)  │
                              │  • OverwatchScheduler / Receiver  │
                              │  • CallEscalationManager          │
                              │  • LocationHelper / SmsManagerH.  │
                              │  • BootReceiver / Watchdog        │
                              └───────────────────────────────────┘
                                                │
                                                ▼
                              ┌───────────────────────────────────┐
                              │  Android system APIs              │
                              │  AudioRecord, FusedLocation,      │
                              │  SmsManager, TelephonyManager,    │
                              │  AlarmManager, PowerManager,      │
                              │  NotificationManager, Biometric   │
                              └───────────────────────────────────┘
```

### 2.2 Cloud companion (optional)

The Convex backend lives in `convex/` and is opt-in. It powers:

- **OTP login** so the user can restore their emergency contacts on a new device (`auth.ts`, stub code `123456`).
- **Contact mirror** (`contacts.ts`) so a phone wipe doesn't lose the SOS roster.
- **Live family map** (`liveLocation.ts`) — while SOS is active and the device has internet, the Flutter `LiveLocationService` pushes a GPS fix every 30 s.
- **Post-incident audit** (`sosEvents.ts`) — drained from sqflite `pending_sync` once connectivity returns.

If `CONVEX_URL` / `CONVEX_DEPLOY_KEY` are empty (`lib/core/config/secrets.dart` → `Secrets.hasConvex == false`) every Convex code-path becomes a no-op and the app remains fully usable offline.

---

## 3. Permissions & manifest

All permissions are declared in `android/app/src/main/AndroidManifest.xml`. The list is intentionally aggressive because every emergency feature has a strict permission dependency. Permission UI is centralised in `lib/features/permissions/`, runtime requests use `permission_handler` (and `local_auth` for biometric).

| Permission | Why ProteqMe needs it | Fallback if denied |
|------------|----------------------|--------------------|
| `RECORD_AUDIO` | Microphone for `SosListenerService` (YAMNet + Vosk HELP detection) | Voice trigger disabled; SOS button still works |
| `FOREGROUND_SERVICE_MICROPHONE` | Required FGS type for the always-listening service on Android 14+ | Service cannot start |
| `FOREGROUND_SERVICE_LOCATION` | Required FGS type for `EmergencySosLoopService` so it can read GPS while in background | SOS loop runs without GPS, SMS says "Location unavailable" |
| `FOREGROUND_SERVICE_DATA_SYNC` | Second FGS type for the SOS loop (it also drains pending Convex events / multiplexes SMS dispatch) | SOS loop still works in pure microphone mode |
| `FOREGROUND_SERVICE` | Generic FGS umbrella | Both services fail to start |
| `CALL_PHONE` | Direct `ACTION_CALL` from `EmergencyActionActivity` | Falls back to `ACTION_DIAL` (user must press call) |
| `SEND_SMS` | Direct `SmsManager.sendTextMessage` from `SmsManagerHelper` / `EmergencyActionActivity` | Falls back to opening the SMS composer with `ACTION_SENDTO` |
| `READ_PHONE_STATE` | `CallEscalationManager` listens to `PhoneStateListener` so we know when a call ends and the 40 s "answered" heuristic | Sequential escalation can't tell if a call connected |
| `ACCESS_FINE_LOCATION` + `ACCESS_COARSE_LOCATION` | Fused current-location fix for SOS messages and live push | SMS sent without map link |
| `ACCESS_BACKGROUND_LOCATION` | Required on Android 10+ so `EmergencySosLoopService` keeps fixing GPS when app is backgrounded | SOS loop GPS becomes stale after a few minutes |
| `POST_NOTIFICATIONS` | Foreground service notification, SOS alerts, Overwatch warning, full-screen-intent call | FGS still runs but invisible (user assumes app is off) |
| `USE_FULL_SCREEN_INTENT` | `NotificationHelper.showEmergencyCallNotification` + `showOverwatchWarningNotification` post full-screen-intent notifications. On Android 10+/HyperOS this is the only reliable way for a background FGS to launch an Activity (the emergency call) | Call notification still posts but cannot wake the device |
| `WAKE_LOCK` | `SosListenerService` holds a `PARTIAL_WAKE_LOCK` so the mic pipeline keeps running while the screen is off | Listening pauses when screen sleeps |
| `RECEIVE_BOOT_COMPLETED` | `BootReceiver` re-arms the listener, the SOS loop, and the Overwatch alarms after a reboot | None of those resume after a power cycle |
| `SCHEDULE_EXACT_ALARM` + `USE_EXACT_ALARM` | `OverwatchScheduler` and `ListenerWatchdogScheduler` use `setExactAndAllowWhileIdle` so the dead-man's switch and watchdog tick fire on time even in Doze | Falls back to `setAndAllowWhileIdle` (may drift by minutes) |
| `USE_BIOMETRIC` + `USE_FINGERPRINT` | `local_auth` for "I AM SAFE" disarm, contact edit/delete, Overwatch cancel | App refuses sensitive operation, asks user to set a screen lock |
| `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` | `DeviceSetupScreen` lets the user surrender battery optimization so HyperOS doesn't kill the listener | HyperOS will likely kill the FGS within ~minutes |
| `INTERNET` + `ACCESS_NETWORK_STATE` | Convex HTTP calls, `Connectivity` checks before draining `pending_sync` | Cloud features disabled |
| `BLUETOOTH`, `BLUETOOTH_ADMIN`, `BLUETOOTH_SCAN`, `BLUETOOTH_CONNECT`, `BLUETOOTH_ADVERTISE`, `NEARBY_WIFI_DEVICES`, `ACCESS_WIFI_STATE`, `CHANGE_WIFI_STATE` | Google Nearby Connections mesh used by `RescueModeService` (victim advertising + rescuer discovery) | Rescue mesh disabled |
| `READ_CONTACTS` | `flutter_contacts` phone-book picker in `ContactsController.pickFromPhone()` | Only manual contact entry works |

### 3.1 Components registered

```
<service .SosListenerService             android:foregroundServiceType="microphone|location" />
<service .EmergencySosLoopService        android:foregroundServiceType="location|dataSync" />
<activity .EmergencyActionActivity       android:showWhenLocked="true" android:turnScreenOn="true" />
<activity .MainActivity                  android:launchMode="singleTop" />
<receiver .BootReceiver                  filters BOOT_COMPLETED + QUICKBOOT_POWERON />
<receiver .ListenerWatchdogReceiver      filters com.proteqme.action.LISTENER_WATCHDOG />
<receiver .OverwatchExpiredReceiver      filters com.proteqme.OVERWATCH_EXPIRED + .OVERWATCH_WARNING />
```

---

## 4. Native services (foreground + background)

All Kotlin sources live in `android/app/src/main/kotlin/com/proteqme/`.

### 4.1 `SosListenerService.kt` — voice keyword detection

- Foreground service of type `microphone|location`.
- On `onCreate` loads `RuntimeConfig` (from `assets/ml/runtime_config.json`), builds a `TriggerStateMachine`, instantiates `YAMNetRunner`, `HelpClassifierRunner`, and `HelpAsrRunner` (Vosk), and acquires a `PARTIAL_WAKE_LOCK` named `proteqme:listener` for up to 10 hours so the mic pipeline keeps running while the screen is off.
- Audio is captured by `AudioRecorder` (16 kHz, 16 000-sample chunks ≈ 1 s) and dispatched into `processAudioChunk`.
- For every chunk:
  1. `YAMNetRunner.run(chunk)` → `screamConfidence` + 1024-d embedding.
  2. `HelpClassifierRunner.predictHelpConfidence(embedding)` → optional secondary HELP confidence from `help_classifier.tflite` if present.
  3. `HelpAsrRunner.process(chunk)` → Vosk ASR transcription with per-word confidence; HELP-token confidence merged with the classifier.
  4. The max of the two HELP confidences is fed into `TriggerStateMachine.process(help, scream, now)`.
  5. The state machine emits `HELP_DETECTED`, `WINDOW_RESET`, `TRIGGERED`, or `COOLDOWN` events that go to `ListenerEventStreamHandler` → Flutter EventChannel.
- On `TRIGGERED` it calls `startUnbreakableSosLoop(numbers)` which seeds `SosLoopPrefs` with all known contacts and launches `EmergencySosLoopService`.
- On `onTaskRemoved` (user swipes the app away) it re-schedules the watchdog so the listener gets restarted within ~90 s.
- Companion `isServiceRunning()` and `cooldownRemainingSeconds()` are read by Flutter via the `getServiceStatus` MethodChannel call.

### 4.2 `EmergencySosLoopService.kt` — unbreakable SOS loop

- Foreground service of type `location|dataSync`. Runs all blocking work (GPS, SMS dispatch) on a dedicated `HandlerThread` named `EmergencySosLoopWorker` so the main thread is never blocked (avoids ANR / FGS timeout).
- State lives in `SosLoopPrefs` (SharedPreferences `proteqme_sos_loop`) so the loop survives process death and reboots.
- On `ACTION_START`:
  1. `applyStartExtras` loads `userName`, `smsIntervalSec` (clamped 300–420, default 360), and `contactsJson` from intent extras into `SosLoopPrefs`.
  2. Service goes foreground with the persistent `proteqme_sos_loop` notification (PRIORITY_MAX, CATEGORY_ALARM).
  3. `pendingFirstDial = true` so the first call only happens AFTER the first SMS burst.
  4. Posts `smsRunnable` which calls `tickSmsAndGps()` and then re-schedules itself every `smsIntervalSec`.
- `tickSmsAndGps()`:
  1. Loads contacts from `SosLoopPrefs.loadContacts()`.
  2. Asks `LocationHelper.getBestLocation(timeoutMs = 8_000L)` (capped at 8 s on the tick so we never starve the FGS timeout).
  3. For each contact, schedules an SMS at `index * 1_500 ms` to avoid carrier rate-limiting. Messages use `SosMessageTemplates.ongoing(userName, lat, lng, language)` per-contact language (`en` / `si` / `ta`). If no GPS, an English fallback "URGENT ONGOING SOS: {name} is in danger! Location unavailable." goes out.
  4. After all SMS are queued and `pendingFirstDial == true`, schedules `maybeDialNext()` at `smsDispatchMs + 3_000 ms` so the first call always lands after the first SMS burst (~3 s buffer).
- `maybeDialNext()` calls `callEscalation.dial(contact.phone)` which delegates to `CallEscalationManager`.
- `CallEscalationManager` listens to `PhoneStateListener.LISTEN_CALL_STATE`. If `CALL_STATE_IDLE` happens within 40 s of `CALL_STATE_OFFHOOK` the contact "didn't answer" → it bumps `prefs.callIndex` and dials the next priority. If ≥ 40 s, `onHumanAnswered` fires and the dial loop pauses (`prefs.callPaused = true`) while SMS keep sending.
- On `ACTION_DISARM`: every contact gets a `SosMessageTemplates.resolved(userName, language)` SMS spaced 1.5 s apart, `SosLoopPrefs.clearLoop()` is called, the call escalation listener is torn down, and the FGS is stopped.

### 4.3 Overwatch — dead-man's switch alarm chain

- `OverwatchScheduler.kt` (singleton, no service) arms two `AlarmManager` `RTC_WAKEUP` alarms via `setExactAndAllowWhileIdle` (falls back to `setAndAllowWhileIdle` if `canScheduleExactAlarms()` returns false, e.g. on tightened Android 14 ROMs):
  - **Expiry alarm** → `OverwatchExpiredReceiver` with action `com.proteqme.OVERWATCH_EXPIRED`.
  - **Warning alarm** → `OverwatchExpiredReceiver` with action `com.proteqme.OVERWATCH_WARNING`, scheduled 60 s before the expiry.
- All state (`startAtMs`, `endAtMs`, `destination`, `userName`, `primaryNumber`, `contactsJson`) is persisted in `OverwatchPrefs` (SharedPreferences `overwatch_prefs`) so the receiver can still escalate even if Flutter has been killed.
- `OverwatchExpiredReceiver.onReceive` immediately calls `goAsync()` and runs the heavy work on a dedicated `HandlerThread` so the receiver never blocks Android.
  - **Warning** path: builds an `Overwatch expiring` full-screen-intent notification via `NotificationHelper.showOverwatchWarningNotification(remainingSeconds)` and emits `{type: EXPIRING_SOON, remainingMs}` on `OverwatchEventBus`.
  - **Expired** path: snapshots all prefs, clears them, then calls `EmergencyWorkflowExecutor.execute(...)` with the message produced by `SosMessageTemplates.overwatchExpired(userName, destination, mapsLink, timestamp)` — i.e. exactly the same SMS-then-call path that YAMNet uses. After the one-shot blast it also seeds `SosLoopPrefs` and starts `EmergencySosLoopService` so the recipients keep getting location pings until biometric disarm. Emits `{type: EXPIRED, escalated, smsSent, callStarted}` on `OverwatchEventBus`.
- `BootReceiver.onReceive` calls `OverwatchScheduler.rescheduleAfterBoot(context)`. If the timer expired while the phone was off it fires the EXPIRED broadcast immediately; otherwise it re-arms the surviving alarms.

### 4.4 `BootReceiver.kt` + `ListenerWatchdogReceiver.kt`

- `BootReceiver` fires on `ACTION_BOOT_COMPLETED` and `QUICKBOOT_POWERON`. Order of recovery:
  1. `OverwatchScheduler.rescheduleAfterBoot` (so a missed timer fires immediately).
  2. If `ListenerPrefs.userWantsListening == true` and `SosListenerService` isn't already running, re-launch the listening FGS and re-schedule the watchdog.
  3. If `SosLoopPrefs.isActive == true`, re-start `EmergencySosLoopService` and launch `MainActivity` so the user can see the SOS state.
- `ListenerWatchdogReceiver` is fired by an exact alarm scheduled in `ListenerWatchdogScheduler.schedule(context)` 90 s in the future. Each tick it checks `ListenerPrefs.userWantsListening && !SosListenerService.isServiceRunning()`, restarts the listening FGS if the OS killed it, and re-schedules itself. The scheduler gracefully falls back to `setInexactRepeating` if exact alarms are denied.

### 4.5 `NotificationHelper.kt` — channels + critical notifications

Four channels created on first run:

| Channel ID | Importance | Used for |
|------------|------------|----------|
| `sos_listener_foreground` | LOW | Persistent `SosListenerService` notification — silent, ongoing, shows current status ("Listening active", "Emergency audio detected (n/3)", cooldown remaining). |
| `sos_listener_alerts` | HIGH | One-off alerts (mic permission lost, SOS triggered banner). Also hosts the full-screen-intent emergency call notification. |
| `proteqme_sos_loop` | HIGH | The SOS-active loop notification (PRIORITY_MAX, CATEGORY_ALARM, ongoing) shown while `EmergencySosLoopService` is running. |
| `proteqme_overwatch` | HIGH | The 60-second Overwatch warning notification (PRIORITY_MAX, CATEGORY_ALARM, full-screen-intent into `MainActivity`). |

Notable helpers:

- `showEmergencyCallNotification(phone)` — builds a CATEGORY_CALL full-screen-intent notification whose target is `EmergencyActionActivity` with `ACTION_CALL`. This is the ONLY reliable way to start a call Activity from a background FGS on Android 10+/HyperOS.
- `showOverwatchWarningNotification(remainingSeconds)` — the 60-second warning posted by `OverwatchExpiredReceiver`. Also uses full-screen-intent so the user is interrupted even on a locked screen.
- `clearOverwatchWarningNotification()` — called by the receiver after `EXPIRED` fires and by `MainActivity.handleOverwatchCall("cancel")` on user disarm.

---

## 5. Emergency workflow

The single canonical workflow is implemented in `EmergencyWorkflowExecutor.kt`:

```
execute(primaryNumber, allNumbers, providedMessage?)
  └─ build SMS message
       ├─ providedMessage if supplied (used by Overwatch expiry template)
       └─ else: "Emergency! I need immediate help. ... Location: <maps link> Timestamp: ..."
  └─ smsManagerHelper.sendEmergencySms(allNumbers, message)        # SmsManager.sendTextMessage / sendMultipartTextMessage
  └─ callManager.makeEmergencyCall(primary)                        # full-screen-intent → EmergencyActionActivity → ACTION_CALL
```

For a `triggerEmergencyWorkflow` MethodChannel call (Flutter side: `EmergencyPlatformDatasource.triggerEmergencyWorkflow`) this is a single shot: SMS to all → call primary → done.

For the home-screen SOS button the Flutter side calls `HiveEmergencyRepository.executeWorkflow` which actually invokes **`SosLoopDatasource.startLoop`** instead — that hands off to `EmergencySosLoopService` so the SMS+call sequence repeats every `smsIntervalSec` until biometric disarm.

### 5.1 Order of operations (SOS loop)

1. `tickSmsAndGps()` queues SMS to every contact, staggered 1.5 s apart, with per-language template from `SosMessageTemplates`.
2. After all SMS are dispatched, a **3-second buffer** elapses before any call is placed (`callDelayMs = smsDispatchMs + 3_000`).
3. The first contact (priority 1, i.e. the user's primary) is called via full-screen-intent → `EmergencyActionActivity` → `ACTION_CALL`.
4. `CallEscalationManager` listens for call state changes. If the call ends in < 40 s it's deemed unanswered → wait 5 s → dial the next priority.
5. If a call lasts ≥ 40 s, dial loop pauses but the periodic SMS loop continues.
6. Every `smsIntervalSec` seconds (default 360, clamped 300–420) a new SMS burst goes out with a fresh GPS fix.
7. Cooldown / disarm only happens when the user authenticates on `EmergencyOverlayScreen` → "I AM SAFE".

### 5.2 SMS templates (`SosMessageTemplates.kt`)

- **ongoing** (`en` / `si` / `ta`) — used inside the loop. Example (en): `URGENT SOS (15 May, 14:22): Nimal is in danger! Location: https://maps.google.com/?q=6.93,79.85`
- **resolved** (`en` / `si` / `ta`) — sent to every contact on disarm. Example (en): `RESOLVED (15 May, 14:35): Nimal is safe and has verified their identity via biometrics.`
- **overwatchExpired** — fired by `OverwatchExpiredReceiver`. Always English. Example: `URGENT: Nimal's Safe Journey timer has expired without a check-in! They may be in danger. Intended destination: Campus library. Last known location: https://maps.google.com/?q=6.93,79.85. (2026-05-17 00:42:10)`
- **One-shot fallback** in `EmergencyWorkflowExecutor.buildEmergencyMessage()` (used by the legacy `triggerEmergencyWorkflow`): `Emergency! I need immediate help. This alert was triggered from my SOS app. My current location: <link> Timestamp: <iso>`.

---

## 6. Voice detection rules

`SosListenerService` + `TriggerStateMachine` + `RuntimeConfig` (loaded from `android/app/src/main/assets/ml/runtime_config.json`):

| Knob | Default | Source |
|------|---------|--------|
| Sample rate | 16 000 Hz | `runtime_config.json#sample_rate` |
| Chunk size | 16 000 samples (≈ 1 s) | `chunk_samples` |
| HELP threshold | 0.7 | `help_threshold` |
| Scream threshold | 0.45 | `scream_threshold` |
| Use Vosk ASR for HELP | true | `use_asr_help` |
| Vosk model dir | `vosk-model-small-en-us-0.15` | `asr_model_dir` |
| Vosk per-word confidence threshold | 0.55 | `asr_word_confidence_threshold` |
| Vosk fallback confidence (no word-level conf) | 0.72 | `asr_fallback_confidence` |
| Required detections in window | 3 | `required_detections` |
| Window | 10 000 ms | `window_ms` |
| Debounce between detections | 2 000 ms | `debounce_ms` |
| Cooldown after trigger | 60 000 ms | `cooldown_ms` |
| Trigger mode | `HELP_ONLY` | `trigger_mode` (also accepts `ANY`, `SCREAM_ONLY`, `BOTH_REQUIRED`) |

Detection events emitted on `com.proteqme/service/events`:

- `HELP_DETECTED` — confidence over threshold, debounce passed, counter incremented.
- `WINDOW_RESET` — 10 s window expired before reaching 3 detections, counter cleared.
- `TRIGGERED` — counter reached 3 within the window → `EmergencySosLoopService` starts.
- `COOLDOWN` — emitted while the 60 s post-trigger cooldown is in effect.

The Flutter `HelpDetectionStateMachine` in `lib/features/listener/domain/help_detection_state_machine.dart` is the Dart equivalent used in unit tests; native is the source of truth at runtime.

---

## 7. Feature catalogue

### 7.1 SOS button (home screen hero button)

- One paragraph: a hero pink/red button on the home screen. A tap OR a long-press both fire the same action — call `EmergencyController.trigger(triggerType: emergencyButton, ...)` which goes through `HiveEmergencyRepository.executeWorkflow` and ultimately calls `SosLoopDatasource.startLoop` so the unbreakable loop begins immediately. After the workflow returns the app pushes `EmergencyOverlayScreen` full-screen.
- Files:
  - `lib/features/listener/presentation/home_screen.dart` (`_SosButton`, `_onEmergencyTrigger`)
  - `lib/features/emergency/presentation/emergency_controller.dart`
  - `lib/features/emergency/data/hive_emergency_repository.dart`
  - `lib/features/emergency/data/sos_loop_datasource.dart`
  - Kotlin: `MainActivity.handleMethodCall("startSosLoop")`, `EmergencySosLoopService`, `EmergencyWorkflowExecutor`, `EmergencyActionActivity`
- User flow: open app → ensure ≥ 1 contact and primary set → tap or long-press SOS → permission dialog if any of phone/SMS/location are missing → button shows spinner while workflow starts → emergency overlay appears.

### 7.2 Voice trigger (always-on listening)

- One paragraph: the "SOS Listening Mode" card on the home screen toggles `SosListenerService`. When active, the FGS continuously records mic input and runs YAMNet + Vosk on-device. After 3 HELP detections within 10 s the service starts `EmergencySosLoopService` exactly as if the user had pressed the SOS button.
- Files:
  - `lib/features/listener/presentation/listener_controller.dart`
  - `lib/features/listener/data/method_channel_listener_service_repository.dart`
  - Kotlin: `SosListenerService`, `AudioRecorder`, `AudioPreprocessor`, `YAMNetRunner`, `HelpAsrRunner`, `HelpClassifierRunner`, `TriggerStateMachine`, `ListenerEventStreamHandler`
- User flow: home → flip "SOS Listening Mode" switch → app requests mic permission if missing → FGS starts with persistent notification → keyword detection runs forever (auto-restarted by watchdog and boot receiver).

### 7.3 Manual trigger (removed from UI — internal only)

- One paragraph: the `EmergencyTriggerType.manualTrigger` enum value still exists and the underlying `executeWorkflow` path supports it, but the **manual trigger button has been removed from the home screen**. It remains available for programmatic callers (e.g. future automation or testing harness) and is logged distinctly in the `EmergencyEventLog` Hive box.
- Files: `lib/features/emergency/domain/entities/emergency_trigger_type.dart`, `lib/features/emergency/data/hive_emergency_repository.dart`.
- User flow: not user-facing anymore.

### 7.4 Overwatch / Safe Journey (dead-man's switch)

- One paragraph: the user picks a duration (15 m / 30 m / 1 h / 2 h) and an optional destination, then taps "Start Overwatch". Native `OverwatchScheduler` arms an exact `AlarmManager` `RTC_WAKEUP` alarm plus a "60 s warning" alarm. 60 s before expiry the card pulses orange (`OverwatchPhase.expiringSoon`) and a full-screen-intent notification fires. If the user doesn't disarm via biometric/PIN, the expiry alarm runs the exact same SMS-then-call workflow used by YAMNet and the SOS button, using the dedicated `SosMessageTemplates.overwatchExpired` template that includes the intended destination. `BootReceiver` re-arms remaining time after a reboot; if the timer expired while the device was off it fires immediately.
- Files:
  - Kotlin (complete): `OverwatchScheduler.kt`, `OverwatchExpiredReceiver.kt`, `OverwatchPrefs.kt`, `OverwatchEventBus.kt`, plus the `com.proteqme/overwatch` MethodChannel and `com.proteqme/overwatch/events` EventChannel in `MainActivity.kt`; `BootReceiver.kt`; `NotificationHelper.showOverwatchWarningNotification` / `clearOverwatchWarningNotification`; `SosMessageTemplates.overwatchExpired`.
  - Flutter (in progress): `lib/features/overwatch/domain/overwatch_state.dart` (entity), plus an Overwatch presentation card on the home screen, an `OverwatchController` Riverpod NotifierProvider, and a `OverwatchDatasource` MethodChannel wrapper — all marked "(in progress)" at the time these docs were written.
- User flow:
  1. Home → tap "Start Overwatch" on the Overwatch card.
  2. Choose duration + (optional) destination.
  3. `MethodChannel('com.proteqme/overwatch').invokeMethod('start', { durationSeconds, destination, userName, primaryNumber, contactsJson })`.
  4. Card switches to active state, countdown ticks from the `com.proteqme/overwatch/events` EventChannel.
  5. 60 s before expiry: full-screen warning notification + UI turns orange.
  6. To disarm: tap "I Arrived Safely" → `local_auth` biometric / device PIN → `MethodChannel.invokeMethod('cancel')` → card flips to green "Journey complete".
  7. If user fails to disarm: `OverwatchExpiredReceiver` runs the SOS workflow with the `overwatchExpired` template and starts the unbreakable SOS loop. The user can still disarm via the emergency overlay (`I AM SAFE` biometric).

### 7.5 Contact management

- One paragraph: emergency contacts live in a Hive box (`contacts_box`) backed by `HiveContactRepository`. The user can add manually (`ContactFormDialog`) or pick one from the phone book via `flutter_contacts` (`ContactsController.pickFromPhone`). Exactly one contact is marked primary at any time — they are called first during SOS. Edit and delete require biometric/PIN confirmation via `LocalAuthentication.authenticate` to prevent a malicious actor from silently disabling the user's safety net.
- Files:
  - `lib/features/contacts/presentation/contacts_screen.dart`
  - `lib/features/contacts/presentation/contacts_controller.dart`
  - `lib/features/contacts/presentation/widgets/contact_form_dialog.dart`
  - `lib/features/contacts/data/hive_contact_repository.dart`
  - `lib/features/contacts/domain/entities/emergency_contact.dart`
- User flow: home → Contacts card → add manually OR pick from phone → contact is saved → tap radio button to mark primary → edit/delete prompt biometric.

### 7.6 Profile (display name in SMS)

- One paragraph: the user's display name is stored in the sqflite `sos_state.user_name` column and is injected into every outbound SOS SMS via `SosMessageTemplates.ongoing(userName, ...)`. The Profile screen also previews how the message will look.
- Files:
  - `lib/features/settings/profile_screen.dart`
  - `lib/data/local/app_database.dart` (`getUserDisplayName` / `setUserDisplayName`)
- User flow: home → Settings (gear) → "Your profile (name)" → type name → save → next SOS SMS reads `URGENT SOS (...): <name> is in danger! ...`.

### 7.7 Emergency overlay screen + "I AM SAFE" biometric disarm

- One paragraph: while `SosLoopPrefs.isActive == true`, `_ProteqMeRoot` polls every 2 s and force-displays `EmergencyOverlayScreen` regardless of which route is active. `PopScope(canPop: false)` blocks the back gesture. The single action — "I AM SAFE" — runs `local_auth.authenticate` (allows PIN/pattern/password if biometric isn't enrolled), then calls `SosLoopDatasource.disarm` (Kotlin `EmergencySosLoopService.disarm`), stops rescue advertising, marks `sos_state.is_active = 0`, and drains the Convex `pending_sync` queue.
- Files:
  - `lib/features/emergency/presentation/emergency_overlay_screen.dart`
  - `lib/features/emergency/data/sos_loop_datasource.dart`
  - `lib/app/app.dart` (`_ProteqMeRoot` polls SOS state every 2 s)
  - Kotlin: `EmergencySosLoopService.disarm`, `SosMessageTemplates.resolved`
- User flow: SOS active → app forces overlay → user taps "I AM SAFE" → biometric prompt → success → RESOLVED SMS to all contacts → overlay closes → home reappears.

### 7.8 Rescue mode (offline mesh)

- One paragraph: a P2P Bluetooth + Wi-Fi Direct mesh built on `nearby_connections`. The **victim** side starts advertising automatically every time SOS is triggered (`HiveEmergencyRepository.executeWorkflow` → `rescueModeService.startAdvertising`), broadcasting their GPS + name. The **rescuer** side is a dedicated screen (`RescuerModeScreen`) where another ProteqMe user toggles discovery and sees a list of nearby victims with a "Navigate" button that opens Google Maps. The mesh is the offline fallback for areas without cellular coverage.
- Files:
  - `lib/features/rescue/rescue_mode_service.dart`
  - `lib/features/rescue/presentation/rescuer_mode_screen.dart`
- User flow:
  - Victim: triggers SOS by any means → advertising starts automatically.
  - Rescuer: home → Settings → "I am rescuing someone" → toggle scanning → see victim list → tap "Navigate to victim" → external Maps opens.

### 7.9 Permissions screen

- One paragraph: a checklist UI that surfaces every runtime permission ProteqMe depends on (microphone, phone, SMS, location, notifications). Each row shows granted/denied with an "Allow" button; the "Continue" button only enables once microphone is granted.
- Files:
  - `lib/features/permissions/presentation/permissions_screen.dart`
  - `lib/features/permissions/presentation/permission_controller.dart`
  - `lib/features/permissions/data/permission_handler_repository.dart`
- User flow: home → Settings → "Permissions" → grant each → tap Continue.

### 7.10 Device setup (HyperOS / Poco / Xiaomi)

- One paragraph: a 7-step guided checklist specific to HyperOS / MIUI quirks: battery → No restrictions, autostart, lock in recents, "Display pop-up while in background", notifications, "Send SMS without confirmation" (CRITICAL — without this every background SMS shows a confirmation dialog and is silently dropped during an actual emergency), and a SIM-credit sanity check. The screen also provides a one-tap shortcut to `Permission.ignoreBatteryOptimizations.request()`.
- Files: `lib/features/settings/device_setup_screen.dart`.
- User flow: home → Settings → "Poco / Xiaomi device setup" → tap through each step → open native settings → return.

### 7.11 Logs screen

- One paragraph: a live feed of `DetectionEvent`s streamed from the listener service plus the `EmergencyEventLog` Hive entries. Each row shows the event type (HELP_DETECTED / WINDOW_RESET / TRIGGERED / COOLDOWN) and the ISO timestamp.
- Files:
  - `lib/features/listener/presentation/logs_screen.dart`
  - `lib/features/listener/presentation/listener_controller.dart` (streams events into state)
  - `lib/features/emergency/domain/entities/emergency_event_log.dart` (Hive `emergency_logs_box`)
- User flow: home → Settings → "Detection & emergency logs".

### 7.12 Auth screen (Convex OTP)

- One paragraph: a two-step OTP flow against `convex/auth.ts`. The OTP itself is a **stub `123456`** for the buildathon; replace with a real SMS provider for production. After verification the user's contacts are fetched from `contacts:listByUser` and upserted into the local Hive box. Auth session (userId, phone, displayName) is persisted in the sqflite `auth_session` row.
- Files:
  - `lib/features/auth/presentation/auth_screen.dart`
  - `lib/services/convex_service.dart`
  - `convex/auth.ts`
- User flow: home → Settings → "Cloud vault (Convex)" → enter phone → "Send OTP" → enter `123456` → "Verify & sync contacts".

### 7.13 Convex cloud sync (live location + sos events + contacts upsert)

- One paragraph: while SOS is active and the device has internet, `LiveLocationService` pushes a GPS fix every 30 s to `liveLocation:update`. Disarm fires `sosEvents:record` (via `ConvexSyncWorker.drainPending`). Contact add/edit/delete from `ContactsController` mirror to Convex via `contacts:addOne` / `contacts:updateOne` / `contacts:deleteOne`. Bulk phone-book imports use `contacts:upsertBatch`.
- Files:
  - `lib/services/live_location_service.dart`
  - `lib/features/sync/convex_sync_worker.dart`
  - `convex/liveLocation.ts`, `convex/sosEvents.ts`, `convex/contacts.ts`
- User flow: cloud-only — invisible to the user once they're signed in.

---

## 8. Flutter MethodChannel contract

Two MethodChannels are registered in `MainActivity.configureFlutterEngine`. Channel name constants live in Dart at `lib/core/constants/app_constants.dart` (`serviceMethodChannel`, `serviceEventChannel`) and are hard-coded as strings on the Kotlin side.

### 8.1 `com.proteqme/service`

| Method | Args | Returns | Native handler | Flutter caller |
|--------|------|---------|----------------|----------------|
| `startService` | `primaryNumber: String`, `allNumbers: List<String>` | `null` | `MainActivity.handleMethodCall` → starts `SosListenerService` with `ACTION_START` + schedules watchdog + persists `ListenerPrefs` | `MethodChannelListenerServiceRepository.startService` |
| `stopService` | — | `null` | Stops listener + cancels watchdog + clears `ListenerPrefs.userWantsListening` | `MethodChannelListenerServiceRepository.stopService` |
| `updatePrimaryNumber` | `primaryNumber: String`, `allNumbers: List<String>` | `null` | Persists payload to `ListenerPrefs`; if listener already running, sends `ACTION_UPDATE_PRIMARY` to update in-flight contacts | `MethodChannelListenerServiceRepository.updatePrimaryNumber` |
| `getServiceStatus` | — | `{ running: bool, cooldownRemaining: int, userWantsListening: bool, primaryNumber: String, allNumbers: List<String> }` | Reads `SosListenerService.isServiceRunning()` and `ListenerPrefs` | Same |
| `makeEmergencyCall` | `phoneNumber: String` | `bool` | `EmergencyWorkflowExecutor.makeEmergencyCall` → `CallManager.makeEmergencyCall` → full-screen-intent → `EmergencyActionActivity` | `EmergencyPlatformDatasource.makeEmergencyCall` |
| `sendEmergencySms` | `numbers: List<String>`, `message: String` | `bool` | `EmergencyWorkflowExecutor.sendSms` → `SmsManagerHelper.sendEmergencySms` | `EmergencyPlatformDatasource.sendEmergencySms` |
| `triggerEmergencyWorkflow` | `primaryNumber: String`, `allNumbers: List<String>`, `message: String?` | `{ callStarted: bool, smsSent: bool, locationIncluded: bool, message: String }` | One-shot: SMS to all → call primary, no loop | `EmergencyPlatformDatasource.triggerEmergencyWorkflow` (legacy path; SOS button now uses `startSosLoop` instead) |
| `startSosLoop` | `userName: String`, `smsIntervalSec: int`, `contactsJson: String` (JSON array of `{phone, name, priority, language}`) | `true` | Seeds `SosLoopPrefs`, starts `EmergencySosLoopService` with `ACTION_START` | `SosLoopDatasource.startLoop` |
| `disarmSosLoop` | — | `true` | `EmergencySosLoopService.disarm` → RESOLVED SMS to all → clear `SosLoopPrefs` | `SosLoopDatasource.disarm` |
| `getSosLoopStatus` | — | `{ active: bool, callPaused: bool, smsIntervalSec: int, triggeredAtMs: long }` | Reads `SosLoopPrefs` | `SosLoopDatasource.isActive` |

### 8.2 `com.proteqme/overwatch`

| Method | Args | Returns | Native handler | Flutter caller |
|--------|------|---------|----------------|----------------|
| `start` | `durationSeconds: int`, `destination: String`, `userName: String`, `primaryNumber: String`, `contactsJson: String` | `null` | `OverwatchScheduler.schedule` arms the two `AlarmManager` alarms and persists `OverwatchPrefs` | Flutter `OverwatchDatasource.start` (in progress) |
| `cancel` | — | `null` | Cancels both alarms, clears `OverwatchPrefs`, clears the warning notification, emits `{type: CANCELLED}` on `OverwatchEventBus` | `OverwatchDatasource.cancel` (in progress) |
| `getStatus` | — | `{ active: bool, remainingMs: long, destination: String, endAtMs: long, startAtMs: long }` | Reads `OverwatchPrefs` | `OverwatchDatasource.getStatus` (in progress) |

---

## 9. EventChannels

### 9.1 `com.proteqme/service/events`

Handled by `ListenerEventStreamHandler`. Events:

| Type | Trigger | Payload extras |
|------|---------|----------------|
| `HELP_DETECTED` | `TriggerStateMachine` accepted a HELP/scream above threshold after debounce | `count: int`, `timestamp: long` |
| `WINDOW_RESET` | 10 s window expired before reaching 3 detections | `count: 0`, `timestamp: long` |
| `TRIGGERED` | counter reached 3 in the window → SOS loop will start | `count: int`, `timestamp: long` |
| `COOLDOWN` | post-trigger 60 s cooldown is in effect | `count: int`, `timestamp: long`, `cooldownRemaining: int` |

Flutter side: `MethodChannelListenerServiceRepository.events` → `DetectionEvent.fromMap` → `ListenerController.logs`.

### 9.2 `com.proteqme/overwatch/events`

Handled by `OverwatchEventBus`. Events emitted by `OverwatchScheduler`, `OverwatchExpiredReceiver`, and `MainActivity` (cancel):

| Type | Trigger | Payload extras |
|------|---------|----------------|
| `TICK` | (reserved) periodic countdown from native — Flutter side will derive its own tick from `getStatus.remainingMs` if the native tick stream is not wired | `remainingMs: long` |
| `EXPIRING_SOON` | 60 s warning alarm fired by `OverwatchExpiredReceiver.handleWarning` | `remainingMs: long` |
| `EXPIRED` | expiry alarm fired and emergency workflow attempted | `escalated: bool`, `smsSent: bool`, `callStarted: bool`, optional `reason: String` |
| `CANCELLED` | user disarmed via `MethodChannel.cancel` | — |

---

## 10. Local data model

### 10.1 Hive boxes

- `contacts_box` → `EmergencyContact` (`typeId = 1`)
  - `id: String` — millisecond timestamp ID, or `<flutter_contact_id>_<ms>` for phone-book imports
  - `name: String`
  - `phone: String` — E.164 ideally, validated by `PhoneValidator` (`^\+?\d+$`)
  - `isPrimary: bool` — exactly one contact is primary
  - `language: String` — `en` / `si` / `ta`, drives `SosMessageTemplates`
- `emergency_logs_box` → `EmergencyEventLog` (`typeId = 2`)
  - `id: String`, `type: String` (one of `emergency_button`, `voice_trigger`, `manual_trigger`), `timestampMs: int`, `callAttempted: bool`, `smsAttempted: bool`, `locationIncluded: bool`
  - Capped to `AppConstants.emergencyLogLimit = 50` in repo `_sortedLogs`.

### 10.2 sqflite (`proteqme.db` v1) — `lib/data/local/app_database.dart`

| Table | Columns | Purpose |
|-------|---------|---------|
| `sos_state` | `id INTEGER PRIMARY KEY (= 1)`, `is_active INTEGER`, `user_name TEXT DEFAULT 'ProteqMe User'`, `sms_interval_sec INTEGER DEFAULT 360`, `call_paused INTEGER`, `triggered_at_ms INTEGER` | Single-row mirror of the SOS loop state and the user's display name (used in SMS templates) |
| `gps_log` | `id`, `timestamp_ms`, `lat REAL`, `lng REAL`, `source TEXT` | Local GPS trail appended both by `HiveEmergencyRepository.executeWorkflow` and `LiveLocationService._tick` |
| `pending_sync` | `id`, `payload_json TEXT`, `created_at_ms` | Queue of post-incident events to push to Convex when the device gets back online; drained by `ConvexSyncWorker.drainPending` |
| `auth_session` | `id INTEGER PRIMARY KEY (= 1)`, `user_id`, `phone`, `display_name` | Single-row Convex session (`userId` is the `users` document ID) |

### 10.3 Native SharedPreferences

| Pref file | Owner | Keys |
|-----------|-------|------|
| `proteqme_listener` | `ListenerPrefs` | `enabled: bool`, `primary: String`, `all_numbers: Set<String>` |
| `proteqme_sos_loop` | `SosLoopPrefs` | `active`, `user_name`, `sms_interval_sec`, `call_paused`, `call_index`, `triggered_at`, `contacts_json` |
| `overwatch_prefs` | `OverwatchPrefs` | `active`, `start_at_ms`, `end_at_ms`, `destination`, `user_name`, `primary_number`, `contacts_json` |

These three pref files are the persistence layer that lets the app survive a reboot or a HyperOS background kill without losing in-flight state.

---

## 11. Convex backend functions

All Convex modules are in `convex/`. Functions are reachable from Flutter via `ConvexService` HTTP calls (`/api/query`, `/api/mutation`).

| Module | Function | Type | Args | Returns / shape |
|--------|----------|------|------|-----------------|
| `auth.ts` | `requestOtp` | mutation | `{ phone: string }` | `{ ok: true, debugCode: '123456' }` — **buildathon stub**, replace with SMS provider |
| `auth.ts` | `verifyOtp` | mutation | `{ phone: string, code: string }` | `{ userId: Id<'users'>, displayName: string }` or throws on bad OTP |
| `auth.ts` | `me` | query | `{ userId: Id<'users'> }` | full users row |
| `contacts.ts` | `listByUser` | query | `{ userId: Id<'users'> }` | `Array<{ _id, name, phone, priority, language }>` |
| `contacts.ts` | `addOne` | mutation | `{ userId, name, phone, priority, language }` | `{ id: Id<'contacts'> }` |
| `contacts.ts` | `updateOne` | mutation | `{ contactId, name?, phone?, priority?, language? }` | `{ ok: true }` |
| `contacts.ts` | `deleteOne` | mutation | `{ contactId }` | `{ ok: true }` |
| `contacts.ts` | `upsertBatch` | mutation | `{ userId, contacts: Array<{name, phone, priority, language}> }` | `{ count: number }` — replaces all existing contacts for the user |
| `liveLocation.ts` | `update` | mutation | `{ userId, lat, lng, sosActive, timestampMs }` | upserts the per-user `live_locations` row |
| `liveLocation.ts` | `watchUser` | query | `{ userId }` | most recent row, ordered desc by `_creationTime` |
| `sosEvents.ts` | `record` | mutation | `{ userId?, triggeredAtMs, disarmedAtMs?, gpsPoints?, payload? }` | inserts `sos_events` row (skips if no `userId`) |

Schema (`convex/schema.ts`):

- `users` indexed `by_phone`.
- `contacts` indexed `by_user`.
- `sos_events` indexed `by_user`.
- `live_locations` indexed `by_user`.

---

## 12. Build & run

The convenience launcher is `scripts/run_app.sh`. It reads `.env.local`, extracts `CONVEX_URL` and `CONVEX_DEPLOY_KEY`, and `exec`s `flutter run --dart-define=CONVEX_URL=... --dart-define=CONVEX_DEPLOY_KEY=...`. It also forwards the first argument as a flutter subcommand (`run`, `build`, `test`, `drive`, `attach`, `analyze`, `pub`) so you can call:

```
./scripts/run_app.sh                          # flutter run on default device
./scripts/run_app.sh -d <id>                  # flutter run on specific device
./scripts/run_app.sh build apk --release      # flutter build apk --release
./scripts/run_app.sh test                     # flutter test
```

Recognised `--dart-define` knobs:

| Define | Read by | Effect |
|--------|---------|--------|
| `CONVEX_URL` | `lib/core/config/secrets.dart::Secrets.convexUrl` | Base URL for `ConvexService` HTTP calls. Empty → cloud features disabled. |
| `CONVEX_DEPLOY_KEY` | `Secrets.convexDeployKey` | Sent as `Authorization: Convex <key>` header. Empty → ConvexService.tryCreate() returns null. |

See `README.md` for the end-to-end "first run" walkthrough (Convex link, etc.).

---

## 13. Brand UI system

All non-home, non-overlay screens share a single visual scaffolding system defined in `lib/core/widgets/brand_scaffold.dart`:

- `BrandScaffold({title, body, actions, floatingActionButton, showGlow, contentPadding, scroll, leading})` — the gradient background + pink/magenta glow blobs + styled AppBar wrapper.
- `BrandCard({child, padding, borderColor, margin, onTap})` — glass-style card with `Color(0xD6221232) → Color(0xD6171128)` gradient and pink border.
- `BrandSectionHeader({label, icon})` — small uppercase pink-purple section heading used inside the scaffold body.
- `BrandTile({icon, title, subtitle, accent, onTap, trailing})` — icon + title + subtitle row inside a `BrandCard`.

These widgets are used in: contacts, permissions, logs, profile, features hub, device setup, rescuer mode, auth. The home screen (`lib/features/listener/presentation/home_screen.dart`) and the full-screen emergency overlay (`lib/features/emergency/presentation/emergency_overlay_screen.dart`) intentionally bypass `BrandScaffold` because they need their own bespoke layouts (hero SOS button + dark-red emergency lock).

### Color palette

| Hex | Role |
|-----|------|
| `#FF2C7A` | Seed color → ColorScheme.fromSeed primary |
| `#FF6FA8` | Secondary accent |
| `#4BEA89` | Tertiary / success (rescue mesh blue alt is `#4FC3F7`) |
| `#FF6B6B` | Error |
| `#08030F` | Scaffold background base |
| `#14071F → #0E0618 → #06030D` | BrandScaffold vertical gradient |
| `#1B1126` | Material card / dialog / bottom-sheet surface |
| `#221232 → #171128` | BrandCard gradient (with alpha `0xD6`) |
| `#FFE7F2` | Primary foreground text |
| `#D9C5E9` | Secondary foreground text |
| `#B59BC9` | Tertiary foreground text |
| `#8A7A9B` | Disabled foreground / hint text |
| `#FF6AA7` | Primary pink accent (icons, borders, focus) |
| `#FF3B5C` | Danger red (emergency, contact delete, primary alarms) |
| `#FFB347` | Warning orange (cooldown, denied permission) |
| `#3BE77A` | Success green (granted permission, "I am safe" disarm) |
| `#4FC3F7` | Rescue mesh / Bluetooth blue |

---

## 14. Edge cases & resilience

- **Boot recovery.** `BootReceiver` re-arms Overwatch, the listener FGS (if `userWantsListening`), and the SOS loop (if `isActive`) in that order. Anything still mid-flight after the reboot continues exactly where it left off because every piece of state is in SharedPreferences.
- **HyperOS background kill.** `ListenerWatchdogScheduler` schedules an exact alarm 90 s out; on each tick `ListenerWatchdogReceiver` restarts the listener FGS if the OS killed it. The user is also nagged through `DeviceSetupScreen` to set battery → No restrictions, autostart, lock-in-recents.
- **Background calls.** Android 10+ refuses `ACTION_CALL` from a background `Service`. ProteqMe works around this by posting a `CATEGORY_CALL` full-screen-intent notification (`NotificationHelper.showEmergencyCallNotification`) whose target is `EmergencyActionActivity` with `showWhenLocked=true` + `turnScreenOn=true`. The OS then promotes the transparent activity, which dials immediately and finishes itself 800 ms later.
- **Direct `SmsManager.sendTextMessage`.** On HyperOS the "Send SMS without confirmation" toggle must be ON or the OS shows a confirmation dialog for every background SMS. `DeviceSetupScreen` step 6 is marked CRITICAL for this reason. `SmsManagerHelper` registers a broadcast receiver for the per-message `SENT` / `DELIVERED` PendingIntents and logs `RESULT_OK` / `NO_SERVICE` / `RADIO_OFF` to help debug carrier-side rejections.
- **Exact-alarm fallback.** `OverwatchScheduler` checks `alarmManager.canScheduleExactAlarms()` on Android 12+ and falls back to `setAndAllowWhileIdle` when exact alarms are denied. The watchdog scheduler additionally falls back to `setInexactRepeating` on `SecurityException`.
- **Biometric not enrolled.** All sensitive prompts (`EmergencyOverlayScreen._disarm`, `ContactsScreen._verifyIdentity`, Overwatch disarm) use `AuthenticationOptions(biometricOnly: false)` so the OS automatically falls through to the device PIN/pattern/password. If `isDeviceSupported() == false` (no lock screen set at all) the app shows a snackbar pointing the user at Settings.
- **No GPS.** `LocationHelper.getBestLocation` first asks `FusedLocationProviderClient.getCurrentLocation` (high accuracy, 25 s default / 8 s during SOS ticks), then iterates `GPS_PROVIDER`, `NETWORK_PROVIDER`, `PASSIVE_PROVIDER` last-known. If still null, the SMS template says "Location unavailable."
- **Carrier SMS failures.** Surfaced in logcat via `SmsManagerHelper`'s registered receiver — typical failures are `NO_SERVICE` (no signal), `RADIO_OFF` (airplane mode), and HyperOS's silent drop when the SMS-without-confirmation toggle is off.

---

## 15. Known limitations

- **Android only.** iOS support was removed — there is no reliable way on iOS to do always-on microphone listening, silent background `ACTION_CALL`, or `SmsManager`-style background SMS without a third-party gateway. `lib/core/platform/platform_utils.dart` hard-codes `isAndroid = true`.
- **HyperOS "Send SMS without confirmation" required.** Without it, every background SMS spawns a system dialog and is silently dropped during a real emergency. `DeviceSetupScreen` step 6 walks the user through it.
- **Zero-battery death.** Once the device is fully dead, nothing on this phone can keep escalating. A future enhancement is to mirror the same SMS burst through Convex → Twilio so the loop survives a dead battery; tracked in the roadmap but not built today.
- **OTP stub.** `convex/auth.ts` accepts the hard-coded code `123456`. Production deployments must wire a real SMS provider.
- **Manual trigger is internal only.** The MANUAL TRIGGER button has been removed from the home screen UI. The underlying `EmergencyTriggerType.manualTrigger` value is still used for log differentiation and remains reachable programmatically.
- **Vosk English model only.** The bundled Vosk model is `vosk-model-small-en-us-0.15`. Sinhala and Tamil HELP detection are not yet wired (the SMS templates are localised, but the trigger keyword is English-only).
- **Single device per Convex user.** The auth/contacts flow assumes one phone number = one user. Family sharing is not modelled in the schema.

---

## 16. File map

### `lib/`

```
lib/
├── main.dart                                 # Hive init, app entry, registers two TypeAdapters
├── app/
│   ├── app.dart                              # ProteqMeApp + _ProteqMeRoot (polls SOS state, force-shows overlay)
│   ├── router.dart                           # named routes: /launch, /, /permissions, /contacts, /logs, /auth, /features, /device-setup, /rescuer-mode, /profile
│   └── theme.dart                            # Material 3 dark theme tuned to brand palette
├── core/
│   ├── config/secrets.dart                   # Secrets.convexUrl / Secrets.convexDeployKey via dart-define
│   ├── constants/app_constants.dart          # box names, channel constants, log limits
│   ├── constants/app_strings.dart            # status text shown on home listening card
│   ├── platform/platform_utils.dart          # isAndroid constant (always true)
│   ├── utils/phone_validator.dart            # regex ^\+?\d+$
│   └── widgets/brand_scaffold.dart           # BrandScaffold + BrandCard + BrandSectionHeader + BrandTile
├── data/local/app_database.dart              # sqflite proteqme.db: sos_state, gps_log, pending_sync, auth_session
├── services/
│   ├── convex_service.dart                   # HTTP client for Convex queries/mutations
│   └── live_location_service.dart            # 30 s GPS push while SOS active + online
└── features/
    ├── auth/
    │   └── presentation/auth_screen.dart     # Convex OTP login + contact restore
    ├── contacts/
    │   ├── data/hive_contact_repository.dart
    │   ├── domain/entities/emergency_contact.dart   # Hive TypeAdapter (typeId = 1), includes language field
    │   ├── domain/repositories/contact_repository.dart
    │   ├── domain/usecases/{save_contact,delete_contact,get_primary_contact,set_primary_contact}_usecase.dart
    │   └── presentation/{contacts_controller, contacts_screen, widgets/contact_form_dialog}.dart
    ├── emergency/
    │   ├── data/emergency_platform_datasource.dart  # MethodChannel for one-shot trigger/SMS/call
    │   ├── data/hive_emergency_repository.dart      # ties workflow → SOS loop + rescue + Convex push
    │   ├── data/location_datasource.dart            # geolocator wrapper, mapsLink helper
    │   ├── data/sos_loop_datasource.dart            # MethodChannel for startSosLoop/disarm/isActive
    │   ├── domain/entities/{emergency_event_log, emergency_execution_result, emergency_trigger_type}.dart
    │   ├── domain/repositories/emergency_repository.dart
    │   ├── domain/usecases/{execute_emergency_workflow, watch_emergency_logs}_usecase.dart
    │   └── presentation/{emergency_controller, emergency_overlay_screen}.dart
    ├── listener/
    │   ├── data/method_channel_listener_service_repository.dart   # MethodChannel + EventChannel adapter
    │   ├── domain/entities/{detection_event, listener_service_status}.dart
    │   ├── domain/help_detection_state_machine.dart               # Dart-side reference state machine (unit tests)
    │   ├── domain/repositories/listener_service_repository.dart
    │   ├── domain/usecases/{start_listening, stop_listening, update_primary_number, get_service_status}_usecase.dart
    │   └── presentation/{home_screen, launch_screen, listener_controller, logs_screen}.dart
    ├── overwatch/                                                 # (in progress) Flutter side of dead-man's switch
    │   └── domain/overwatch_state.dart                            # OverwatchPhase enum + OverwatchState entity
    ├── permissions/
    │   ├── data/permission_handler_repository.dart                # permission_handler adapter
    │   ├── domain/{permission_repository, permission_state}.dart
    │   └── presentation/{permission_controller, permissions_screen}.dart
    ├── rescue/
    │   ├── rescue_mode_service.dart                               # nearby_connections advertise/discover
    │   └── presentation/rescuer_mode_screen.dart
    ├── settings/
    │   ├── device_setup_screen.dart                               # 7-step HyperOS checklist
    │   ├── features_hub_screen.dart                               # ProteqMe features hub (settings gear destination)
    │   └── profile_screen.dart                                    # display name (used in SOS SMS)
    └── sync/
        └── convex_sync_worker.dart                                # drains pending_sync to Convex on disarm
```

### `android/app/src/main/kotlin/com/proteqme/`

```
android/app/src/main/kotlin/com/proteqme/
├── MainActivity.kt                 # FlutterFragmentActivity; wires two MethodChannels + two EventChannels
├── EmergencyActionActivity.kt      # transparent activity that runs ACTION_CALL / SmsManager from a foreground context
├── EmergencyActionManager.kt       # thin wrapper for EmergencyWorkflowExecutor
├── EmergencyWorkflowExecutor.kt    # SMS to all → call primary, with optional providedMessage (used by Overwatch)
├── EmergencySosLoopService.kt      # FGS (location|dataSync) — unbreakable SMS+call loop on HandlerThread
├── CallManager.kt                  # builds the full-screen-intent call notification (delegates to NotificationHelper)
├── CallEscalationManager.kt        # PhoneStateListener: 40 s answered heuristic, sequential dial
├── SmsManagerHelper.kt             # SmsManager.sendTextMessage / sendMultipartTextMessage with SENT/DELIVERED receivers
├── LocationHelper.kt               # Fused current-location with 25 s / 8 s timeouts + last-known fallback
├── NotificationHelper.kt           # four channels (foreground / alerts / sos loop / overwatch) + full-screen-intent helpers
├── PhoneNormalizer.kt              # trim + dedupe + reject empties; preserves leading '+'
├── BootReceiver.kt                 # ACTION_BOOT_COMPLETED — re-arm overwatch, listener, sos loop
├── ListenerEventStreamHandler.kt   # EventChannel sink for the listener
├── ListenerPrefs.kt                # SharedPreferences proteqme_listener
├── ListenerWatchdogReceiver.kt     # restart listener FGS if killed
├── ListenerWatchdogScheduler.kt    # schedules the watchdog alarm 90 s out
├── SosListenerService.kt           # FGS (microphone|location) — YAMNet + Vosk pipeline
├── SosLoopPrefs.kt                 # SharedPreferences proteqme_sos_loop (active, contacts json, call index, ...)
├── SosMessageTemplates.kt          # ongoing / resolved / overwatchExpired templates (en/si/ta where applicable)
├── TriggerStateMachine.kt          # RuntimeConfig + state machine (3 detections in 10 s → trigger, 60 s cooldown)
├── DetectionEvent.kt               # enum + data class for events emitted on the listener EventChannel
├── DetectionStateMachine.kt        # legacy state machine (kept for reference)
├── AudioRecorder.kt                # AudioRecord wrapper; pushes 1-s chunks into the callback
├── AudioPreprocessor.kt            # any normalisation / windowing before YAMNet inference
├── YAMNetRunner.kt                 # TFLite YAMNet inference; returns scream confidence + embedding
├── HelpAsrRunner.kt                # Vosk ASR; extracts per-word HELP confidence from continuous PCM
├── HelpClassifierRunner.kt         # optional secondary HELP classifier on YAMNet embeddings
├── OverwatchScheduler.kt           # arms expiry + 60 s warning AlarmManager alarms
├── OverwatchExpiredReceiver.kt     # handles both WARNING and EXPIRED, fires emergency workflow + starts SOS loop
├── OverwatchPrefs.kt               # SharedPreferences overwatch_prefs
└── OverwatchEventBus.kt            # singleton EventChannel sink for overwatch events
```

### `convex/`

```
convex/
├── schema.ts        # users, contacts, sos_events, live_locations (with by_phone / by_user indexes)
├── auth.ts          # requestOtp (stub 123456) + verifyOtp + me
├── contacts.ts      # listByUser, addOne, updateOne, deleteOne, upsertBatch
├── liveLocation.ts  # update + watchUser (family live map subscription)
└── sosEvents.ts     # record (drained from sqflite pending_sync after disarm)
```
