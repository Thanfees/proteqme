# ProteqMe: Required Skills & Technologies

This document outlines the technical skills, Flutter packages, and domain-specific knowledge required to develop **ProteqMe**, an offline-first, continuous-execution emergency application tailored for the Sri Lankan demographic.

## 1. Flutter & Dart Core Development
*   **App Framework:** Deep proficiency in **Flutter** and **Dart**.
*   **Isolate Management:** Experience handling heavy computational tasks (like audio processing) off the main UI thread using Dart Isolates.
*   **State Management:** Managing complex application states, specifically transitioning between Idle, Active SOS (Looping), and Disarmed states.

## 2. Persistent Background Execution
*   **Background Services:** Mastery of `flutter_background_service`.
*   **Foreground Processing (Android):** Creating persistent, high-priority foreground notifications to prevent the OS from killing the app.
*   **OS Workarounds:** Knowledge of bypassing aggressive battery optimization and "Doze Mode" on heavily modified Android OS versions prevalent in Sri Lanka (e.g., Xiaomi MIUI/HyperOS, Samsung OneUI, Vivo FuntouchOS).
*   **Boot Receivers:** Configuring Android `RECEIVE_BOOT_COMPLETED` intents to auto-resume the SOS loop if a device restarts.

## 3. On-Device Machine Learning & Audio Pipeline
*   **Audio Stream Management:** Buffering raw 16kHz PCM audio frames continuously without causing memory leaks.
*   **Wake-Word Engines:** Integrating **whisper and openai models
*   **TensorFlow Lite:** Utilizing `tflite_flutter` to run Google **YAMNet** (for acoustic scream detection) and custom localized models (for Sinhala/Tamil wake words like "Udaw" and "Kappathunga").

## 4. Telephony, SMS, & Hardware APIs (No Third-Party APIs)
*   **Background SMS:** Utilizing the Android `telephony` package to send local carrier text messages silently in the background.
*   **Call Intent Handling:** Triggering native voice calls using `url_launcher`.
*   **Call State Monitoring:** Using `phone_state` to monitor telephony hardware (detecting `CALL_STATE_OFFHOOK` and `CALL_STATE_IDLE`) to calculate call duration and implement smart sequential escalation.
*   **Geolocation:** Using `geolocator` to access raw physical GPS satellites (handling cold locks without internet) and calculating Haversine distances.

## 5. Security & Biometric Disarming
*   **Biometric Authentication:** Implementing the `local_auth` package to lock the app's "I Am Safe" disarm button behind FaceID, Fingerprint, or secure device PIN.
*   **Uninterruptible UI:** Designing full-screen, system-overlay dashboards that cannot be easily dismissed by swiping.

## 6. Offline P2P Mesh Networking (Rescue Mode)
*   **Device-to-Device Comm:** Implementing Google's `nearby_connections` API for offline device discovery.
*   **Hardware Radios:** Managing Bluetooth Low Energy (BLE) and Wi-Fi Direct payloads.
*   **Byte Serialization:** Converting GPS payloads into `Uint8List` byte arrays for local, off-grid transmission between victims and rescuers.

## 7. Cloud Vault & Local Caching (Convex)
*   **Convex Backend:** Writing TypeScript backend schemas, Queries, and Mutations for the Convex platform.
*   **Local-First Architecture:** Using `sqflite` (SQLite) or `isar` to maintain a robust local cache of emergency contacts and user preferences.
*   **Cross-Device Syncing:** Designing network-aware listeners (`connectivity_plus`) that queue offline event logs and push them to Convex the moment an internet connection is restored.
*   **Authentication:** Integrating OTP (Phone Number) login flows (via Firebase Auth or Clerk) to securely map users to their Convex data vault across multiple devices.