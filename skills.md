# ProteqMe: Required Skills & Technologies

This document outlines the technical skills, frameworks, and domain knowledge required to develop **ProteqMe**, an offline-first, voice-activated emergency application.

## 1. Mobile Frontend Development
*   **Cross-Platform Frameworks:** Proficiency in **React Native** (understanding both Expo and Bare workflows) or **Flutter**.
*   **State Management:** Handling complex app states, particularly managing the transition between online (syncing) and offline (emergency) modes.
*   **Background Execution:** Building and managing continuous background workers/services that consume minimal battery life.

## 2. On-Device Machine Learning & Audio Processing
*   **Edge AI/ML:** Implementing lightweight, on-device machine learning models without relying on cloud APIs.
*   **Audio Frameworks:** Integrating **Picovoice Porcupine** for precise wake-word detection ("help help help").
*   **Custom ML Models:** Utilizing **TensorFlow Lite** for custom audio classification (e.g., high-frequency scream detection) and tuning confidence interval thresholds (e.g., > 0.85).
*   **Audio Stream Management:** Handling continuous microphone buffering and processing efficiently on mobile devices.

## 3. Backend & Cloud Database (Convex)
*   **Convex Platform:** Building reactive backend services using **Convex**.
*   **Schema Design:** Defining strict database schemas using Convex's TypeScript definitions (e.g., `users`, `contacts`, `sos_events`).
*   **Data Synchronization:** Writing Convex Queries for data fetching and Mutations for post-emergency event logging.
*   **TypeScript/JavaScript:** Core language proficiency for backend logic and schema configuration.

## 4. Offline-First Architecture & Local Storage
*   **Local Databases:** Implementing robust local caching using **SQLite**, **WatermelonDB**, or **MMKV**.
*   **Data Consistency:** Designing logic to cache user contacts locally upon network connection and reading from this cache during offline emergencies.
*   **Queued Syncing:** Building network listeners to queue offline events (like an SOS trigger) and automatically sync them to Convex once a connection is restored.

## 5. Native Hardware & OS-Specific APIs
*   **Telephony integration:** 
    *   *Android:* Utilizing native `CALL_PHONE` intents for background calling.
    *   *iOS:* Implementing `tel://` URL schemes for the native dialer.
*   **SMS Management:**
    *   *Android:* Deep understanding of the native `SmsManager` API for silent, background carrier messaging.
    *   *iOS:* Utilizing `MFMessageComposeViewController` for pre-filling native SMS layouts.
*   **Hardware GPS:** Interacting directly with the device's physical GPS chip, handling "cold locks," and managing Assisted GPS (A-GPS) fallback logic.

## 6. Security, Permissions & OS Guardrails
*   **Advanced Permission Handling:** Requesting, verifying, and gracefully degrading functionality for critical permissions:
    *   `RECORD_AUDIO`
    *   `ACCESS_FINE_LOCATION` / `ACCESS_BACKGROUND_LOCATION`
    *   `SEND_SMS` / `CALL_PHONE`
*   **App Store Policies:** Understanding Google Play exceptions for "Physical safety/emergency alerts" to allow background SMS.
*   **Battery Optimization Bypass:** Navigating Android's strict Doze mode and battery optimization settings to ensure the background audio listener is not killed by the OS.