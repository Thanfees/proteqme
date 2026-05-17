# ProteqMe Project Diagram

Deep architecture description of the ProteqMe Android safety app.

## Project Architecture

```mermaid
flowchart TD
  User[User on Android Phone] --> Flutter[Flutter UI Layer]

  Flutter --> Riverpod[Riverpod Controllers / Providers]
  Riverpod --> LocalDB[Local Storage: Hive + sqflite]
  Riverpod --> MethodChannels[Flutter MethodChannels]
  Riverpod --> ConvexClient[Convex HTTP Client]

  MethodChannels --> Kotlin[Native Kotlin Android Layer]
  Kotlin --> ListenerService[SosListenerService]
  Kotlin --> SosLoop[EmergencySosLoopService]
  Kotlin --> Overwatch[Overwatch AlarmManager Chain]
  Kotlin --> Rescue[Nearby Rescue Mesh]
  Kotlin --> AndroidAPIs[Android System APIs]

  ListenerService --> VoiceAI[YAMNet + Vosk HELP Detection]
  VoiceAI --> Trigger[TriggerStateMachine]
  Trigger --> SosLoop

  Overwatch --> AlarmManager[AlarmManager RTC_WAKEUP]
  AlarmManager --> OverwatchReceiver[OverwatchExpiredReceiver]
  OverwatchReceiver --> SosLoop

  SosLoop --> SMS[SmsManager Direct SMS]
  SosLoop --> GPS[LocationHelper GPS]
  SosLoop --> Call[Full-screen Intent Call]
  SosLoop --> Notifications[NotificationHelper]

  ConvexClient --> Convex[Convex Backend]
  Convex --> ConvexDB[(Convex Tables)]
```

## Main Layers

ProteqMe is an Android-only Flutter safety app with a native Kotlin emergency engine.

The Flutter side handles UI, navigation, state, forms, permissions, contacts, profile, rescue screens, logs, and settings. Riverpod connects screens to controllers and repositories.

The Kotlin side handles anything that must survive background execution: voice detection, foreground services, SMS sending, calls, GPS lookup, watchdog restart, boot recovery, and Overwatch timer expiry.

Convex is the optional cloud backend for auth, contact sync, SOS event storage, and live location mirroring.

## User Flow

```mermaid
flowchart TD
  Start[Open App] --> Lock{Biometric lock enabled?}
  Lock -->|Yes| Bio[Fingerprint / PIN Auth]
  Lock -->|No| Home[Home Screen]
  Bio -->|Success| Home
  Bio -->|Fail| Locked[Stay Locked]

  Home --> GPS[GPS Status Pill]
  Home --> Listen[SOS Listening Mode Toggle]
  Home --> SOS[SOS Emergency Button]
  Home --> Contacts[Contacts]
  Home --> Features[Features Hub]
  Home --> Overwatch[Safe Journey / Overwatch]

  Listen --> NativeListener[SosListenerService]
  NativeListener --> Detect{HELP / Scream Detected?}
  Detect -->|Yes| Emergency

  SOS --> Emergency[Emergency Workflow]
  Overwatch --> Timer[Native AlarmManager Timer]
  Timer -->|Expires| Emergency

  Emergency --> SMS[Send SMS to all contacts]
  SMS --> Delay[3 second buffer]
  Delay --> Call[Call primary contact]
  Emergency --> Overlay[I AM SAFE Overlay]

  Overlay --> SafeAuth[Biometric / PIN Verification]
  SafeAuth -->|Success| Disarm[Stop SOS Loop]
  SafeAuth -->|Fail| Emergency
```

## Home Screen Layout

```mermaid
flowchart TD
  HomeScreen[Home Screen]
  HomeScreen --> Header[Top Header: Logo + ProteqMe + Settings Icon]
  HomeScreen --> GpsPill[GPS Status Pill]
  HomeScreen --> Listening[SOS Listening Mode Card]
  HomeScreen --> SosButton[Large SOS Emergency Button]
  HomeScreen --> OverwatchCard[Safe Journey / Overwatch Card]
  HomeScreen --> BottomActions[Bottom Actions Row]

  BottomActions --> ContactsCard[Contacts]
  BottomActions --> FeaturesCard[Features]
```

The home screen is designed around emergency-first hierarchy. The logo and settings are at the top, GPS state is shown immediately, listening mode is clearly visible, and the SOS button is the visual center. Manual trigger UI was removed so the emergency action is simpler.

## Emergency Workflow

```mermaid
sequenceDiagram
  participant UI as Flutter UI
  participant Native as Kotlin EmergencySosLoopService
  participant GPS as LocationHelper
  participant SMS as SmsManagerHelper
  participant Call as CallManager
  participant Notify as NotificationHelper

  UI->>Native: triggerEmergencyWorkflow()
  Native->>GPS: getBestLocation()
  GPS-->>Native: lat/lng or unavailable

  Native->>SMS: send SMS to all contacts
  SMS-->>Native: sent/delivered callbacks

  Native->>Native: wait 3 seconds
  Native->>Notify: show full-screen call notification
  Notify->>Call: launch EmergencyActionActivity
  Call->>Call: call primary contact

  Native->>UI: SOS active state
  UI->>UI: show I AM SAFE overlay
```

The emergency loop prioritizes SMS first, then call. This is important because SMS can carry location, timestamp, user name, and emergency context before the phone starts dialing.

## Voice Detection Pipeline

```mermaid
flowchart LR
  Mic[Microphone AudioRecord] --> PCM[PCM Audio Chunks]
  PCM --> Vosk[Vosk ASR HELP Detection]
  PCM --> YAMNet[YAMNet Sound Classifier]
  Vosk --> StateMachine[TriggerStateMachine]
  YAMNet --> StateMachine
  StateMachine -->|Threshold + debounce + count passed| SOS[Emergency Workflow]
```

Voice detection runs natively in `SosListenerService` as a foreground service. It uses microphone audio chunks, ASR HELP recognition, and YAMNet-style sound classification. The state machine prevents accidental triggers using debounce, trigger windows, and cooldowns.

## Overwatch / Safe Journey

```mermaid
flowchart TD
  User[User starts Safe Journey] --> FlutterCard[Overwatch Flutter Card]
  FlutterCard --> Channel[MethodChannel com.proteqme/overwatch]
  Channel --> Scheduler[OverwatchScheduler]
  Scheduler --> Prefs[OverwatchPrefs SharedPreferences]
  Scheduler --> Alarm[AlarmManager Exact Alarm]

  Alarm --> Warning{60 seconds left?}
  Warning -->|Yes| WarnNotify[Warning Notification + UI Event]
  WarnNotify --> UserCheck[User taps I Arrived Safely]

  UserCheck --> Bio[Biometric / PIN Auth]
  Bio -->|Success| Cancel[cancelOverwatchTimer]
  Cancel --> Clear[Clear Alarm + Prefs]

  Alarm -->|Expired| Receiver[OverwatchExpiredReceiver]
  Receiver --> Emergency[Emergency WorkflowExecutor]
  Emergency --> OverwatchSMS[Overwatch-specific SOS SMS]
```

Overwatch is the dead-man's switch. The timer is native, not just a Flutter timer, so it can still fire if the app is closed. It stores the end timestamp in preferences and re-arms after reboot.

## Contact + Profile Data Flow

```mermaid
flowchart TD
  ContactsUI[Contacts Screen] --> Controller[ContactsController]
  Controller --> LocalRepo[Hive Contact Repository]
  LocalRepo --> Hive[(Local Contacts)]

  Controller --> ConvexService[ConvexService]
  ConvexService --> ConvexContacts[Convex contacts.ts]

  ProfileUI[Profile Screen] --> AppDB[AppDatabase sqflite]
  AppDB --> SosState[(sos_state table)]
  ProfileUI --> ConvexProfile[Convex user profile]

  AppDB --> SMSName[User Name in SOS SMS]
  Hive --> EmergencyContacts[Emergency Workflow Contacts]
```

Contacts are primarily local so emergency behavior works offline. Convex acts as sync and backup. The user display name is stored locally and used in SMS templates, then mirrored to Convex when available.

## Rescue Mode

```mermaid
flowchart LR
  VictimSOS[Victim triggers SOS] --> Advertise[Auto Nearby Advertising]
  Advertise --> Nearby[Google Nearby Connections]

  Rescuer[Rescuer opens Rescuer Mode] --> Discover[Manual Discovery]
  Discover --> Nearby
  Nearby --> VictimCard[Discovered Victim Card]
  VictimCard --> Navigate[Open Maps / Navigate]
```

Rescue mode is split into victim and rescuer roles. The victim device advertises automatically after SOS. Rescuers manually scan nearby and see victim location/details.

## Convex Backend

```mermaid
erDiagram
  users {
    string phone
    string displayName
    number createdAt
    string username
    string passwordHash
    string passwordSalt
  }

  contacts {
    id userId
    string name
    string phone
    number priority
    string language
  }

  sos_events {
    id userId
    number triggeredAtMs
    number disarmedAtMs
    array gpsPoints
    any payload
  }

  live_locations {
    id userId
    number lat
    number lng
    boolean sosActive
    number timestampMs
  }

  users ||--o{ contacts : owns
  users ||--o{ sos_events : creates
  users ||--o{ live_locations : updates
```

Convex stores cloud-side user profile, contacts, SOS events, and live location. The app still keeps emergency-critical data locally so it can operate during network loss.

## Native Android Components

```mermaid
flowchart TD
  MainActivity[MainActivity] --> ServiceChannel[com.proteqme/service]
  MainActivity --> OverwatchChannel[com.proteqme/overwatch]
  MainActivity --> EventChannels[EventChannels]

  ServiceChannel --> Listener[SosListenerService]
  ServiceChannel --> SosLoop[EmergencySosLoopService]

  Listener --> Boot[BootReceiver]
  Boot --> Watchdog[ListenerWatchdogScheduler]
  Watchdog --> WatchdogReceiver[ListenerWatchdogReceiver]

  SosLoop --> SmsHelper[SmsManagerHelper]
  SosLoop --> CallManager[CallManager]
  SosLoop --> LocationHelper[LocationHelper]
  SosLoop --> NotificationHelper[NotificationHelper]
```

The native layer exists because Android background limits make pure Flutter timers and background work unreliable. Foreground services, AlarmManager, receivers, and full-screen notifications are used for safety-critical paths.

## Key Design Principle

ProteqMe follows this split:

- Flutter: UI, state, forms, user flows, settings, local auth prompts.
- Kotlin: background-safe emergency execution.
- Local database: emergency-critical offline state.
- Convex: optional cloud backup, sync, and future remote escalation.
- Biometric/PIN: required for sensitive actions like disarming SOS, modifying contacts, and opening the app when lock is enabled.
