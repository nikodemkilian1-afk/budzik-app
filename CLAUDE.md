# Budzik 100 Kroków — Project Context

## Overview

Mobile alarm clock app for **iOS** (Swift + SwiftUI + SwiftData). The core mechanic: the alarm can only be dismissed after the user walks **100 steps**. This forces users to physically get out of bed.

**Target:** MVP / Proof of Concept for investor/stakeholder demo.  
**Timeline:** 2-week sprint.  
**Platform:** iOS 17+, iPhone only.

---

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Language | Swift 5.9+ |
| UI Framework | SwiftUI |
| Persistence | SwiftData (CloudKit-ready via `@Model` — enable iCloud sync in a later sprint) |
| Step Counting | CoreMotion — `CMPedometer` |
| Alarms | `UNUserNotificationCenter` + background audio (`AVFoundation`) |
| Anti-Cheat | CoreMotion — `CMAccelerometer` rhythm analysis |
| Background Tasks | `BackgroundTasks` framework |
| Minimum iOS | iOS 17.0 |
| Xcode | 15+ |

---

## App Architecture

Pattern: **MVVM** (Model–View–ViewModel)

```
BudzikApp/
├── BudzikApp.swift                  # @main App entry, SwiftData container setup
├── CLAUDE.md                        # This file
│
├── Models/                          # SwiftData @Model classes
│   ├── AlarmModel.swift             # Alarm configuration (time, repeat days, snooze settings)
│   ├── WakeRecord.swift             # One wake-up session record
│   └── EmergencyReason.swift        # Enum for emergency stop reasons
│
├── ViewModels/
│   ├── AlarmViewModel.swift         # Alarm CRUD, scheduling UNNotifications
│   ├── ActiveAlarmViewModel.swift   # Live session: steps, timer, state machine
│   └── HistoryViewModel.swift       # Aggregation, Morning Score calculation
│
├── Views/
│   ├── RootView.swift               # Tab bar / navigation root
│   ├── AlarmSetupView.swift         # Set alarm time + repeat days
│   ├── ActiveAlarmView.swift        # Full-screen alarm: ringing state
│   ├── StepCounterView.swift        # Walk 100 steps — live counter
│   ├── SuccessView.swift            # Alarm dismissed — Morning Score shown
│   ├── HistoryView.swift            # List of past wake records
│   ├── MorningScoreView.swift       # Score breakdown chart
│   └── SettingsView.swift           # Step goal, snooze limit, emergency reasons
│
├── Services/
│   ├── AlarmService.swift           # UNUserNotificationCenter wrapper
│   ├── PedometerService.swift       # CMPedometer wrapper — live step feed
│   ├── AntiCheatService.swift       # Shake detection, rhythm validation
│   └── AudioService.swift           # AVAudioSession + alarm sound playback
│
└── Utilities/
    ├── MorningScoreCalculator.swift # Score formula (0–100)
    ├── Constants.swift              # Step goal = 100, snooze limit = 2, etc.
    └── Extensions.swift             # Date, Color, etc. helpers
```

---

## Data Models (SwiftData)

### AlarmModel
```swift
@Model class AlarmModel {
    var id: UUID
    var hour: Int
    var minute: Int
    var repeatDays: [Int]          // 0=Sun … 6=Sat, empty = once
    var isActive: Bool
    var snoozeLimit: Int           // default: 2
    var snoozeDuration: Int        // minutes, default: 5
    var stepGoal: Int              // default: 100
    var label: String              // optional user label
    var createdAt: Date
}
```

### WakeRecord
```swift
@Model class WakeRecord {
    var id: UUID
    var alarmTime: Date            // scheduled alarm time
    var alarmStartedAt: Date       // moment alarm started ringing
    var movementStartedAt: Date?   // moment user started walking
    var dismissedAt: Date?         // moment alarm was dismissed
    var stepsTaken: Int            // steps until dismissal
    var snoozeCount: Int
    var wasEmergencyStopped: Bool
    var emergencyReason: String?   // from EmergencyReason enum
    var morningScore: Int          // 0–100
}
```

### EmergencyReason (enum)
```swift
enum EmergencyReason: String, CaseIterable {
    case traveling       = "Jestem w podróży"
    case badStepCount    = "Telefon źle liczy kroki"
    case emergency       = "Sytuacja awaryjna"
    case testing         = "Testuję aplikację"
}
```

---

## Business Logic

### Alarm State Machine

```
IDLE → SCHEDULED → RINGING → WALKING → DISMISSED
                           ↓        ↑
                        SNOOZED ────┘
                           ↓
                     EMERGENCY_STOP (from RINGING or WALKING)
```

### Step Counter Rules
- Use `CMPedometer.startUpdates(from: alarmStartTime)` — counts from when alarm started
- Required: 100 steps (configurable via `Constants.stepGoal`)
- Pedometer updates every ~1 second
- **Cannot skip walking** — the dismiss button is hidden until `steps >= stepGoal`

### Snooze Rules
- Duration: 5 minutes (configurable)
- Max per session: 2 (configurable)
- After max snoozes: snooze button disappears, must walk
- Each snooze increments `WakeRecord.snoozeCount`

### Emergency Stop
- Always available (small button, requires reason selection)
- Shows modal with `EmergencyReason` options
- `WakeRecord.wasEmergencyStopped = true`, score = 0

### Morning Score Formula (0–100)
```
base = 100
- snooze penalty:     snoozeCount × 15
- reaction penalty:   max(0, (reactionTime - 60) / 10) × 2   // reactionTime in seconds
- emergency penalty:  wasEmergencyStopped ? 100 : 0
+ speed bonus:        stepTime < 120s ? 10 : 0                // dismissed in under 2 min of walking

score = clamp(base - penalties + bonuses, 0, 100)
```

Where:
- `reactionTime` = `movementStartedAt - alarmStartedAt` (seconds)
- `stepTime` = `dismissedAt - movementStartedAt` (seconds)

---

## Anti-Cheat Service

Goal: block simple cheats for the MVP. Not perfect, just good enough.

### Detection Rules
1. **Shake detection**: If accelerometer peaks > 2.5G more than 3× per second for 3+ seconds → flag as cheating, reset step count to 0, show warning.
2. **Speed check**: 100 steps in < 15 seconds is physically impossible → reject, reset, show warning.
3. **Rhythm check**: If `CMPedometer` cadence > 200 steps/min for > 5 seconds → flag.

### Implementation
- `CMMotionManager` with `accelerometerUpdateInterval = 0.1`
- Running window of 3 seconds, count peaks
- On cheat detected: reset `CMPedometer` session, show `"Wykryto potrząsanie — zacznij od nowa"` alert

---

## UX Copy (Polish)

| Moment | Message |
|--------|---------|
| Walking, 70 steps left | "Zostało Ci 70 kroków — daj radę!" |
| Walking, 30 steps left | "Już blisko! Jeszcze 30 kroków" |
| Walking, 10 steps left | "10 kroków! Prawie jesteś!" |
| Alarm dismissed | "Brawo! Alarm wyłączony 🎉" |
| Cheat detected | "Wykryto potrząsanie — zacznij od nowa" |
| Snooze (1 left) | "Ostatnia drzemka!" |
| No snoozes left | "Brak drzemek — czas wstawać! 💪" |

---

## Analytics Events (log to console / local for MVP)

| Event | Triggered when |
|-------|---------------|
| `alarm_created` | User saves new alarm |
| `alarm_started` | Alarm begins ringing |
| `alarm_snoozed` | User taps snooze |
| `steps_started` | Pedometer starts counting |
| `steps_completed` | 100 steps reached |
| `alarm_dismissed` | Alarm fully dismissed |
| `emergency_stop` | Emergency button used |
| `cheat_detected` | Anti-cheat triggered |

For MVP: `print()` to console is fine. Wrap in `AnalyticsService` so it's easy to swap for Firebase/Mixpanel later.

---

## Permissions Required (Info.plist)

```xml
<key>NSMotionUsageDescription</key>
<string>Aplikacja liczy Twoje kroki, żeby wyłączyć alarm.</string>

<key>NSMicrophoneUsageDescription</key>
<string>Wymagane do odtwarzania dźwięku alarmu w tle.</string>
```

Background modes (Xcode target capabilities):
- `audio` — alarm sound in background
- `processing` — BackgroundTasks

---

## Key Constraints

- **Alarm must ring even when app is in background** — use `UNUserNotificationCenter` + `AVAudioSession` with `.playback` category
- **Step counter must work from lock screen** — `CMPedometer` works in background
- **App must not crash if user denies Motion permission** — graceful fallback with manual "I walked" button (not ideal, but acceptable for MVP)
- **No network required** — fully offline MVP
- **SwiftData schema** — mark models as `@Model`, use `ModelContainer` in `BudzikApp.swift`; CloudKit sync can be enabled later by adding `cloudKitContainerIdentifier` to the container configuration

---

## Out of Scope (do NOT implement in this sprint)

- Social features / sharing
- Apple Health integration (too complex for MVP)
- watchOS companion app
- Widgets
- In-app purchases
- Push notifications from server
- Android version
