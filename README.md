# ProteqMe

**Android safety companion with on-device voice detection, dead-man's switch timer, and offline rescue mesh.**

ProteqMe is a single-purpose personal safety app for Android. It listens for the word "help" on-device, runs an unbreakable SMS-plus-call escalation loop using your own SIM, arms a Safe Journey timer that auto-escalates if you fail to check in, and broadcasts your location over a Bluetooth mesh to nearby rescuers even when the cellular network is down. The Convex cloud companion is optional and only enables cross-device contact restore, a live family map, and post-incident audit logs.

---

## Highlights

- **Hero SOS button** — tap or long-press the home-screen button to start the unbreakable SOS loop (SMS to all → primary call → repeat every 5–7 minutes).
- **Voice-triggered SOS** — say "help" three times within 10 seconds and the same loop kicks in. Runs entirely on-device via YAMNet (TFLite) + Vosk ASR.
- **Overwatch / Safe Journey timer** — a dead-man's switch. Arm a 15-minute / 30-minute / 1-hour / 2-hour timer with an intended destination; if you don't check in via biometric before it expires, ProteqMe escalates exactly like a real SOS.
- **Offline rescue mesh** — Google Nearby Connections (Bluetooth + Wi-Fi Direct) automatically advertises your location to nearby ProteqMe users during an active SOS. No internet required.
- **Biometric-gated disarm** — every dangerous action (cancel SOS, cancel Overwatch, edit/delete a contact) is gated behind fingerprint, face, or device PIN via `local_auth`.
- **Convex cloud sync (optional)** — OTP login restores your contacts on a new device, mirrors a live GPS pin to family, and logs every incident.
- **Built for Sri Lanka + Poco/HyperOS** — guided device setup with the exact OEM-specific toggles required so the listener doesn't get killed.

---

## Screens

| Screen | What the user sees |
|--------|--------------------|
| **Launch** | Brand splash with ProteqMe logo, transitions to home after ~1.7 s. |
| **Home** | Logo top-left, settings gear top-right, GPS status pill, "SOS Listening Mode" card with toggle and Poco-help hint, hero SOS Emergency button (tap or long-press), Overwatch / Safe Journey card, then a Contacts card and Features card. |
| **Contacts** | List of emergency contacts (name + phone). Add manually or pick from phone book. One contact is marked primary (radio button). Edit/delete require biometric. |
| **Features hub** | All ProteqMe tools in one place: Profile, Contacts, Cloud vault, Rescuer mode, Live family map, Device setup, Permissions, Logs. |
| **Profile** | Set your display name — it appears in every outbound SOS SMS so contacts know who is in danger. Includes a live SMS preview. |
| **Rescuer mode** | Toggle scanning, see a live list of nearby victims (name, GPS, time since discovery) with a "Navigate to victim" button that opens Google Maps. |
| **Permissions** | Granted/denied state for microphone, phone, SMS, location, notifications, with per-row "Allow" buttons. |
| **Device setup** | A 7-step guided checklist tuned for HyperOS / Poco / Xiaomi. Highlights the critical "Send SMS without confirmation" toggle. |
| **Logs** | Recent detection events from the listener (HELP_DETECTED, TRIGGERED, COOLDOWN) and emergency action history. |
| **Emergency overlay** | Full-screen red lock displayed while SOS is active. Single action: "I AM SAFE" → biometric → disarm. Back button is disabled. |
| **Auth (Cloud vault)** | OTP login against Convex to sync contacts across devices. Buildathon OTP stub: `123456`. |

---

## Quick start

### Prerequisites

- **Flutter stable** (`flutter --version` ≥ 3.16 with Dart 3.11+).
- **Android Studio + Android SDK + platform tools.**
- A **real Android device** with USB debugging — the listener service, SMS, calls, GPS, and Bluetooth mesh all require a physical phone with a SIM card. The emulator works only for UI testing.
- Optional: `node` + `npm` for running Convex locally.

### First-time setup

```bash
flutter pub get
flutter doctor
```

If you intend to use the Convex cloud features (recommended for the buildathon demo), copy the env template and follow the Convex section below:

```bash
cp .env.local.example .env.local
```

### Running the app

The repo ships a helper script that loads `.env.local` and forwards the right `--dart-define` flags:

```bash
./scripts/run_app.sh                          # runs on the first connected Android device
./scripts/run_app.sh -d <device_id>           # specific device
./scripts/run_app.sh --release                # release build
./scripts/run_app.sh build apk --release      # build APK instead of run
./scripts/run_app.sh test                     # runs flutter test
```

If you'd rather invoke Flutter directly:

```bash
flutter run \
  --dart-define=CONVEX_URL=https://YOUR.convex.cloud \
  --dart-define=CONVEX_DEPLOY_KEY=your_deploy_key
```

Leaving both `--dart-define` values empty is fine — every cloud feature gracefully degrades to a no-op and the rest of the app works fully offline.

---

## Convex backend setup

The Convex companion is optional. Follow these steps to enable it for the demo.

1. **Install dependencies.** From the repo root:

   ```bash
   npm install
   ```

2. **Start the Convex dev deployment.** This is interactive — Convex will prompt you to log in, create or choose a project, and pick a deployment.

   ```bash
   npx convex dev
   ```

   On first run it writes `CONVEX_DEPLOYMENT`, `CONVEX_URL`, and `CONVEX_SITE_URL` into `.env.local`. Keep this process running while developing — schema and function changes hot-reload.

3. **Add a deploy key.** Open the [Convex dashboard](https://dashboard.convex.dev) → your project → Settings → Deploy Keys → generate a development deploy key. Paste it into `.env.local`:

   ```env
   CONVEX_DEPLOY_KEY=convex-...
   ```

4. **Run the app with the helper.**

   ```bash
   ./scripts/run_app.sh
   ```

5. **Sign in inside the app.** Home → Settings (gear) → "Cloud vault (Convex)" → enter your phone number → "Send OTP" → enter `123456` → "Verify & sync contacts". Your contacts are restored from `contacts:listByUser` and your user document ID is cached in the local sqflite `auth_session` table.

> **Note.** The OTP is a buildathon stub. `convex/auth.ts` hard-codes `123456`. For production, wire `requestOtp` to a real SMS provider (Twilio, MessageBird, Notify.lk, etc.) and replace the `OTP_STORE` map with a per-phone code with expiry.

---

## Permissions to grant on the phone

ProteqMe asks for a lot of permissions because every escalation path has a strict dependency. The Permissions screen guides the user through each one.

| Permission | What ProteqMe does with it | If denied |
|------------|----------------------------|-----------|
| Microphone (`RECORD_AUDIO`) | Always-on YAMNet + Vosk HELP detection in `SosListenerService`. | Voice trigger disabled — SOS button and Overwatch still work. |
| Phone (`CALL_PHONE`) | Direct `ACTION_CALL` during emergency workflow. | App falls back to opening the dialer (`ACTION_DIAL`) — the user must press call. |
| SMS (`SEND_SMS`) | Background `SmsManager.sendTextMessage` to every contact. | Opens the SMS composer (`ACTION_SENDTO`) instead. |
| Location (fine + coarse + background) | Fused current location attached to every SOS SMS and pushed to Convex live map. | SMS still sends with "Location unavailable". |
| Notifications | Persistent listening notification, SOS loop alarm, Overwatch 60 s warning, full-screen-intent emergency call. | Foreground service keeps running but invisible — the user assumes it's off. |
| Biometric / fingerprint | "I AM SAFE" disarm, Overwatch cancel, contact edit/delete. | Falls back to device PIN/pattern if a screen lock is set; refuses sensitive operations if not. |
| Bluetooth + Nearby Wi-Fi | Google Nearby Connections rescue mesh (victim advertising and rescuer discovery). | Rescue mesh disabled. |
| Contacts | Phone-book picker in Add Contact. | Only manual entry works. |
| Boot completed + Exact alarms + Battery optimization exemption | Re-arming the listener, the SOS loop, and the Overwatch timer after reboot or HyperOS background kill. | The app cannot self-restart. |

---

## Poco / Xiaomi / HyperOS specific setup

HyperOS aggressively kills background apps. The `Device setup` screen (Features hub → "Poco / Xiaomi device setup") walks the user through every required toggle. Skipping any of these will silently break SOS during a real emergency.

1. **Battery: No restrictions** — Settings → Apps → ProteqMe → Battery saver → No restrictions.
2. **Autostart** — Security app → Autostart → enable ProteqMe (or Settings → Apps → Autostart).
3. **Lock in Recents** — open the Recents view → long-press the ProteqMe card → Lock. Prevents swipe-kill.
4. **Display pop-up while in background** — Apps → ProteqMe → Other permissions → Display pop-up windows → Allow. Required for the full-screen-intent emergency call.
5. **Notifications** — Allow notifications. Required for the listening foreground notification and SOS alerts.
6. **Send SMS without confirmation (CRITICAL)** — Apps → ProteqMe → Other permissions → Send SMS → Allow always. Without this, HyperOS shows a confirmation dialog on every background SMS and silently drops it if no human dismisses the dialog during an emergency.
7. **Verify the SIM has SMS credit** — free / data-only SIMs cannot send SMS. Test by sending a normal SMS from your dialer before relying on ProteqMe.

The screen also exposes a one-tap `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` shortcut.

---

## How each feature works

### SOS button + voice trigger

The home screen hero SOS button and the YAMNet voice-trigger fire the same workflow under the hood. Both end up calling `MethodChannel('com.proteqme/service').invokeMethod('startSosLoop', { userName, smsIntervalSec, contactsJson })`, which seeds `SosLoopPrefs` and starts `EmergencySosLoopService`. The service then dispatches a localised SMS (English / Sinhala / Tamil per contact) to every contact, waits ~3 s, fires a full-screen-intent emergency call to the primary, and repeats the SMS burst every `smsIntervalSec` (default 360 s, clamped 300–420 s). Sequential calling uses a 40-second "answered" heuristic via `PhoneStateListener`. See `skills.md` §5 for the exact ordering and §6 for the voice detection thresholds.

### Overwatch / Safe Journey timer (dead-man's switch)

The user picks a duration (15 m / 30 m / 1 h / 2 h) and an optional destination, then taps "Start Overwatch". Flutter calls `MethodChannel('com.proteqme/overwatch').invokeMethod('start', { durationSeconds, destination, userName, primaryNumber, contactsJson })`. The Kotlin `OverwatchScheduler` arms an exact `AlarmManager` `RTC_WAKEUP` alarm at expiry plus a "warning" alarm 60 s before. 60 s before expiry the card pulses orange and a full-screen-intent notification fires. To disarm, the user taps "I Arrived Safely" → biometric / device PIN → `cancel()`. If they fail to disarm, `OverwatchExpiredReceiver` runs the same SMS+call workflow used by YAMNet, with a dedicated message template that includes the intended destination and last-known location. `BootReceiver` re-arms the remaining timer if the phone reboots; if it expired while the device was off, escalation fires immediately on boot.

### Emergency overlay & "I AM SAFE" biometric disarm

Whenever `SosLoopPrefs.isActive == true`, the Flutter root widget polls every 2 seconds and force-displays the full-screen `EmergencyOverlayScreen` regardless of route. The back gesture is blocked. The single action — "I AM SAFE" — runs `local_auth.authenticate` (PIN/pattern/password fallback if biometric isn't enrolled), then calls `disarmSosLoop`, stops rescue mesh advertising, marks the local SOS state inactive, and drains any queued Convex events.

### Rescue mode (victim auto-advertises, rescuer discovers)

The victim does nothing — every SOS automatically calls `RescueModeService.startAdvertising` so their GPS + display name are broadcast over Google Nearby Connections (Bluetooth + Wi-Fi Direct, P2P_CLUSTER strategy). The rescuer opens Features → "I am rescuing someone" → toggles scanning. Discovered victims appear with a "Navigate to victim" button that opens Google Maps. Effective range is roughly 100 m. The mesh is the offline fallback for areas without cellular coverage.

### Contact management (manual + phone-book import, biometric for edit/delete)

Contacts live in a local Hive box. Add manually via `ContactFormDialog` or pick from the OS contact picker via `flutter_contacts`. Exactly one contact is marked primary at any time — they are called first during SOS. Edit and delete both require biometric or device PIN confirmation through `LocalAuthentication.authenticate(sensitiveTransaction: true)` so a malicious actor with momentary access to the phone cannot silently disable the user's safety net.

### Profile name → personalised SOS messages

The user's display name is stored in the local sqflite `sos_state.user_name` column and is injected into every outbound SOS SMS via `SosMessageTemplates.ongoing(userName, lat, lng, language)`. The Profile screen also shows a live preview of how the SMS will look.

---

## Model assets

The voice pipeline ships with the app bundle.

- `android/app/src/main/assets/ml/yamnet.tflite` — TensorFlow Lite YAMNet model used by `YAMNetRunner`.
- `android/app/src/main/assets/ml/yamnet_class_map.csv` — class map (optional, default ships).
- `android/app/src/main/assets/ml/runtime_config.json` — every detection knob (sample rate, chunk size, HELP / scream thresholds, debounce, window, cooldown, trigger mode). Edit this file to retune the listener without rebuilding the model.
- `android/app/src/main/assets/vosk/vosk-model-small-en-us-0.15/` — extracted Vosk ASR model used by `HelpAsrRunner` for exact HELP-token detection.

If `help_classifier.tflite` is missing the pipeline still works — Vosk ASR alone handles the HELP detection.

---

## MethodChannel contract

Two MethodChannels are exposed by `MainActivity`:

- `com.proteqme/service` — listener start/stop, SOS loop control, one-shot emergency workflow, direct SMS / call (legacy).
- `com.proteqme/overwatch` — Safe Journey timer start / cancel / status.

Two EventChannels:

- `com.proteqme/service/events` — listener detection events (HELP_DETECTED, WINDOW_RESET, TRIGGERED, COOLDOWN).
- `com.proteqme/overwatch/events` — Overwatch lifecycle events (TICK, EXPIRING_SOON, EXPIRED, CANCELLED).

For the full method-by-method contract (args, return shapes, native handlers) see `skills.md` §8–§9.

---

## Build APK

Release APK via the helper:

```bash
./scripts/run_app.sh build apk --release
```

Or directly via Flutter:

```bash
flutter build apk --release \
  --dart-define=CONVEX_URL=https://YOUR.convex.cloud \
  --dart-define=CONVEX_DEPLOY_KEY=your_deploy_key
```

Output: `build/app/outputs/flutter-apk/app-release.apk` (or `app-debug.apk` for debug builds).

If you intend to distribute the APK, set up a key signing config in `android/key.properties` and reference it from `android/app/build.gradle`. The shipped configuration is debug-keyed.

---

## Tests

```bash
flutter test
```

The repository includes unit tests for the Dart-side detection state machine in `test/features/listener/domain/help_detection_state_machine_test.dart`, covering window resets, debounce, trigger threshold, and cooldown.

---

## Project status / roadmap

- **Android only by design.** iOS support was removed because iOS does not support always-on background microphone listening, silent background `ACTION_CALL`, or `SmsManager`-equivalent background SMS without a paid telephony gateway.
- **Convex + Twilio mirror for zero-battery death (planned).** Today, once the device dies, escalation stops. The plan is to mirror the same SMS burst through Convex → Twilio so the loop survives a dead battery.
- **Production OTP provider (planned).** `convex/auth.ts` currently accepts the hard-coded `123456` code. Wire a real SMS provider before any user-facing deployment.
- **Real WorkManager-backed cloud retry queue (planned).** `ConvexSyncWorker.drainPending` currently runs only on disarm; a WorkManager-scheduled retry would close the gap when the device is offline at disarm time.

---

## License / credits

License: see `LICENSE`.

Credits placeholder — fill in for the buildathon submission.
