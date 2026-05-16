# sos_help_listener

Flutter emergency-response app with:
- emergency contacts (Hive)
- one primary contact
- Android background YAMNet + offline ASR emergency audio detection in a Foreground Service
- emergency workflow (call + SMS + location link)
- Home screen Emergency and Manual Trigger buttons

## Setup

1. Install Flutter stable and Android Studio (with SDK + platform tools).
2. From project root:

```bash
flutter clean
flutter pub get
```

3. Verify tooling:

```bash
flutter doctor
```

## Run

### Run on Chrome (UI testing only)

```bash
flutter run -d chrome
```

Chrome is for UI/testing only. Background listener, native Foreground Service, native SMS, and native call are Android features and are not available on web.

### Run on Android phone (full functionality)

1. Enable Developer Options and USB Debugging on the phone.
2. Connect phone by USB.
3. Confirm device is visible:

```bash
flutter devices
```

4. Run app:

```bash
flutter run -d <android_device_id>
```

5. (Optional) Build APK:

```bash
flutter build apk --debug
```

APK output:
- `build/app/outputs/flutter-apk/app-debug.apk`

## Permissions

The app requests:
- `RECORD_AUDIO`: HELP detection
- `CALL_PHONE`: direct `ACTION_CALL`
- `SEND_SMS`: direct SMS send
- `ACCESS_FINE_LOCATION`, `ACCESS_COARSE_LOCATION`: include map link in SOS message
- `FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_MICROPHONE`, `FOREGROUND_SERVICE_LOCATION`: Android background listener
- `POST_NOTIFICATIONS`: service/trigger notifications

Behavior with missing permissions:
- No mic permission: listener cannot start.
- No call permission: fallback to dialer (`ACTION_DIAL`).
- No SMS permission: fallback to SMS composer where possible.
- No location permission: SMS still sends without location and states location unavailable.

## Emergency Workflow

Single reusable emergency workflow is used by:
- Voice/audio trigger (YAMNet scream + HELP classifier)
- Home `EMERGENCY` button
- Home `MANUAL TRIGGER` button

Workflow steps:
1. Validate contacts and primary contact
2. Build emergency message with timestamp
3. Include Google Maps link if location is available:
   - `https://maps.google.com/?q=<lat>,<lng>`
4. Send SMS to all emergency contacts
5. Call primary contact
6. Apply cooldown

## Voice Detection Rules

- Runtime uses Android `AudioRecord` chunks (`1s` by default at `16kHz`).
- `HelpAsrRunner` (pretrained Vosk model) performs exact token-level HELP recognition from continuous PCM stream.
- `YAMNetRunner` computes scream confidence and embeddings.
- `HelpClassifierRunner` is optional. If provided, its help confidence is combined with ASR.
- Valid detection count follows configurable trigger mode:
  - `ANY` (default): scream OR help confidence crosses threshold
  - `HELP_ONLY`
  - `SCREAM_ONLY`
  - `BOTH_REQUIRED`
- Trigger count: 3 detections within 10 seconds
- Debounce: 2 seconds
- Cooldown: 60 seconds
- Window reset if 10s expires before reaching the trigger count.

## Android Background Notes

- Listener runs in `SosListenerService` foreground service with persistent notification.
- Service continuously captures microphone audio and performs on-device inference.
- On trigger, Android native workflow executes call + SMS immediately.

### Model Assets Required

Place these model files in `android/app/src/main/assets/ml/`:
- `yamnet.tflite`
- `yamnet_class_map.csv` (optional override is already included)
- `runtime_config.json` (included, editable thresholds/rules)

Place pretrained Vosk ASR model folder in `android/app/src/main/assets/vosk/`:
- `vosk-model-small-en-us-0.15/` (full extracted folder)

Current default runtime config is tuned for exact HELP token triggering:
- `trigger_mode: HELP_ONLY`
- `use_asr_help: true`

If `help_classifier.tflite` is missing, exact HELP detection still works via Vosk ASR.

### Battery Optimization (important)

For stable background behavior:
1. Open app info for `com.proteqme` (ProteqHer).
2. Battery usage -> set to `Unrestricted` (or vendor equivalent).
3. Allow auto-start/background activity on OEM ROMs (Samsung/Xiaomi/Huawei/etc).

## iOS Limitations

iOS build supports:
- UI, contacts management, manual trigger flows

iOS does not reliably support:
- continuous background always-listening
- silent background auto-call
- Android-style foreground service speech detection

Best effort on iOS:
- manual call via `tel:` flow
- manual SMS compose flow

## MethodChannel Contract

Channel: `com.proteqme/service`

Flutter -> Android methods:
- `startService`
  - args: `primaryNumber: String`, `allNumbers: List<String>`
- `stopService`
- `updatePrimaryNumber`
  - args: `primaryNumber: String`, `allNumbers: List<String>`
- `getServiceStatus`
  - returns: `running: bool`, `cooldownRemaining: int`
- `makeEmergencyCall`
  - args: `phoneNumber: String`
- `sendEmergencySms`
  - args: `numbers: List<String>`, `message: String`
- `triggerEmergencyWorkflow`
  - args: `primaryNumber: String`, `allNumbers: List<String>`, `message: String`

EventChannel:
- `com.proteqme/service/events`
- emits `HELP_DETECTED`, `WINDOW_RESET`, `TRIGGERED`, `COOLDOWN`

## Tests

Run:

```bash
flutter test
```

Included:
- `test/features/listener/domain/help_detection_state_machine_test.dart`

Coverage includes detection rules: window, debounce, trigger, cooldown, confidence behavior.
