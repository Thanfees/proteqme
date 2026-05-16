# ProteqMe device test matrix

Use a **physical Android device** for SMS, calls, and `phone_state`. Emulator telephony is limited.

| # | Scenario | Steps | Expected |
|---|----------|-------|----------|
| 1 | Debug SOS | Home → **Simulate SOS** or long-press screen | Emergency overlay; FGS notification; SMS sent (if SIM grants) |
| 2 | SMS copy | Inspect sent SMS | EN/SI/TA template + `https://maps.google.com/?q=lat,lng` |
| 3 | Call escalation | Two test numbers; answer first <40s | Next contact dialed after 5s |
| 4 | Call pause | Answer ≥40s | No further dials; SMS loop continues |
| 5 | Disarm | **I AM SAFE** + biometric/PIN | Timers stop; RESOLVED SMS; overlay closes |
| 6 | Boot resume | Active SOS → reboot | App launches; service resumes; overlay on open |
| 7 | Offline sync | Airplane mode through incident → disarm → online | `pending_sync` drains; row in Convex `sos_events` |

## Commands

```bash
flutter pub get
flutter clean
flutter analyze
flutter run \
  --dart-define=CONVEX_URL=https://YOUR.convex.cloud \
  --dart-define=CONVEX_DEPLOY_KEY=YOUR_KEY
```

If Gradle fails on `:telephony` with **Namespace not specified**, the project already patches this in `android/build.gradle.kts` (AGP 8 + discontinued `telephony` 0.2.0). Run `flutter clean` and rebuild.

## Known limits

- `telephony` package is discontinued; sideload/buildathon only.
- Background SMS may require Play Emergency declaration for store release.
- ML detectors are NoOp until flags and assets are enabled.
