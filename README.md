# Budzik 100 Kroków — iOS MVP

Mobile alarm clock for iOS. The alarm can only be dismissed after the user walks **100 steps**, forcing them to physically get out of bed.

- Swift 5.9 + SwiftUI + SwiftData
- iOS 17+, iPhone only
- Step counting via `CMPedometer`, anti-cheat via `CMAccelerometer`
- Polish UI

---

## Quickstart

There are two ways to open this in Xcode:

### Option A — Use XcodeGen (recommended)

```bash
brew install xcodegen        # if you don't have it
cd budzik-app
xcodegen generate            # produces BudzikApp.xcodeproj
open BudzikApp.xcodeproj
```

### Option B — Create a fresh Xcode project manually

1. Open Xcode → **File ▸ New ▸ Project… ▸ iOS ▸ App**.
2. Product Name: `BudzikApp`, Interface: SwiftUI, Storage: SwiftData, Language: Swift, Minimum Deployment: iOS 17.
3. Delete the auto-generated `ContentView.swift` and the `App.swift` stub Xcode created.
4. Drag the `BudzikApp/` folder from this repo into the Xcode project navigator → *Copy items if needed*, *Create groups*.
5. In the target's **Info** tab, paste in the `NSMotionUsageDescription` and `NSMicrophoneUsageDescription` strings (or replace the generated `Info.plist` with `BudzikApp/Resources/Info.plist`).

---

## Required capabilities

In Xcode → target `BudzikApp` → **Signing & Capabilities**, add:

- **Background Modes**
  - ✅ Audio, AirPlay, and Picture in Picture
  - ✅ Background processing
- **Push Notifications** (optional, future-proofing)

Then set your **Apple Developer Team** under *Signing*.

---

## Running

| Target | Notes |
|---|---|
| **Simulator** | App boots, UI is fully usable. `CMPedometer` returns `isStepCountingAvailable = false` and no real steps. A manual *"Potwierdź 100 kroków"* fallback button is shown. Anti-cheat does nothing because the accelerometer is static. |
| **Real iPhone** | Required for the full loop. Set an alarm 1 minute in the future, lock the phone, wait for the notification, open the app, walk 100 steps. |

> **Tip:** test alarms quickly by swiping left on an alarm in the list and tapping **Test** — it skips the notification and goes straight to the active-alarm flow.

---

## Project structure

```
BudzikApp/
├── BudzikApp.swift             # @main entry, ModelContainer, UN delegate
├── Models/
│   ├── AlarmModel.swift        # SwiftData @Model — alarm config
│   ├── WakeRecord.swift        # SwiftData @Model — one wake session
│   └── EmergencyReason.swift   # enum
├── ViewModels/
│   ├── AlarmViewModel.swift          # CRUD + scheduling
│   ├── ActiveAlarmViewModel.swift    # session state machine
│   └── HistoryViewModel.swift        # aggregates
├── Views/
│   ├── RootView.swift              # TabView + fullScreenCover
│   ├── AlarmSetupView.swift        # time picker, weekday picker, list
│   ├── ActiveAlarmView.swift       # ringing screen
│   ├── StepCounterView.swift       # 100-step walk screen
│   ├── SuccessView.swift           # post-dismissal score
│   ├── HistoryView.swift           # past wake records
│   ├── MorningScoreView.swift      # SwiftCharts bar chart
│   └── SettingsView.swift          # defaults, clear history
├── Services/
│   ├── AlarmService.swift          # UNUserNotificationCenter wrapper
│   ├── PedometerService.swift      # CMPedometer wrapper
│   ├── AntiCheatService.swift      # shake / cadence detection
│   ├── AudioService.swift          # AVAudioSession + alarm playback
│   └── AnalyticsService.swift      # console logging stub
└── Utilities/
    ├── MorningScoreCalculator.swift
    ├── Constants.swift
    └── Extensions.swift
```

---

## Architecture notes

- **State machine** in `ActiveAlarmViewModel`: `idle → ringing → walking → dismissed`, with `snoozed` and `emergencyStopped` side states.
- The **dismiss button is never shown until `steps ≥ stepGoal`** — `StepCounterView` simply doesn't render it, so it's not skippable.
- **Anti-cheat** runs only during the `.walking` state. On detection the pedometer session is rebased to zero and a Polish warning alert appears.
- **Snooze** uses an in-app timer for the MVP, not a separate scheduled notification. For background reliability (lock-screen snooze), wire it through `UNUserNotificationCenter` in a follow-up sprint.
- **Audio** drops in `AVAudioSession(.playback)` so the alarm sound continues from background. Add an `alarm.caf` / `alarm.wav` / `alarm.mp3` to the target if you want a custom sound — otherwise the system fallback kicks in.

---

## Known MVP limitations

- The dismiss-from-background flow depends on the user opening the notification banner. iOS does not allow apps to take over the screen from the background — Apple’s alarm-style apps use `UNNotificationContent.interruptionLevel = .timeSensitive` (already set) plus a looping audio session.
- No iCloud sync yet. Schema is CloudKit-ready (no required relationships, all properties have defaults). To enable, replace the `ModelConfiguration` line in `BudzikApp.swift` with `cloudKitDatabase: .private("iCloud.com.example.Budzik")` and add the CloudKit + Push Notifications capabilities.
- Anti-cheat is intentionally simple — it'll catch shaking and impossibly-fast counts, not someone strapping the phone to a metronome.
- `SuccessView` recomputes a display score from session state for simplicity; the persisted `WakeRecord.morningScore` is the source of truth shown in `HistoryView`.

---

## Testing the golden path

1. Set an alarm 1 minute in the future on a real iPhone.
2. Lock the phone, wait.
3. Tap the notification banner — `ActiveAlarmView` appears, sound loops.
4. Tap **WSTAŃ I IDŹ** → `StepCounterView`.
5. Walk 100 steps. Counter climbs in real time.
6. At 100, the success screen shows your Morning Score.
7. Tap **Zakończ** → returns to home tab. The session appears in **Historia**.

---

## Tech stack summary

| Layer | Technology |
|-------|-----------|
| Language | Swift 5.9+ |
| UI | SwiftUI + Charts |
| Persistence | SwiftData (`@Model`) |
| Steps | CoreMotion `CMPedometer` |
| Anti-cheat | CoreMotion `CMMotionManager` |
| Alarms | `UNUserNotificationCenter` + `AVAudioSession(.playback)` |
| Minimum iOS | 17.0 |
