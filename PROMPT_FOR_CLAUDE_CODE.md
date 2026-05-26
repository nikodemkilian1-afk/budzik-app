# Prompt dla Claude Code — Budzik 100 Kroków

> **Jak używać:** Umieść oba pliki (`CLAUDE.md` i ten plik) w folderze projektu.
> Następnie uruchom Claude Code w tym folderze i wklej poniższy prompt.

---

## PROMPT (wklej do Claude Code)

```
Przeczytaj plik CLAUDE.md w tym folderze — zawiera pełną specyfikację projektu.

Twoim zadaniem jest zbudowanie od zera kompletnego projektu iOS aplikacji "Budzik 100 Kroków" 
zgodnie ze specyfikacją z CLAUDE.md.

## Co masz zrobić

### 1. Utwórz strukturę projektu Xcode

Wygeneruj wszystkie pliki Swift zgodnie ze strukturą folderów z CLAUDE.md:

```
BudzikApp/
├── BudzikApp.swift
├── Models/
│   ├── AlarmModel.swift
│   ├── WakeRecord.swift
│   └── EmergencyReason.swift
├── ViewModels/
│   ├── AlarmViewModel.swift
│   ├── ActiveAlarmViewModel.swift
│   └── HistoryViewModel.swift
├── Views/
│   ├── RootView.swift
│   ├── AlarmSetupView.swift
│   ├── ActiveAlarmView.swift
│   ├── StepCounterView.swift
│   ├── SuccessView.swift
│   ├── HistoryView.swift
│   ├── MorningScoreView.swift
│   └── SettingsView.swift
├── Services/
│   ├── AlarmService.swift
│   ├── PedometerService.swift
│   ├── AntiCheatService.swift
│   └── AudioService.swift
└── Utilities/
    ├── MorningScoreCalculator.swift
    ├── Constants.swift
    └── Extensions.swift
```

Utwórz też plik `Package.swift` lub `BudzikApp.xcodeproj` (wybierz podejście które możesz 
w pełni wygenerować bez GUI Xcode — jeśli nie możesz stworzyć .xcodeproj, stwórz 
Package.swift jako Swift Package Manager project z targetem aplikacji iOS).

---

### 2. Zaimplementuj każdy plik

**BudzikApp.swift**
- `@main` App struct
- Konfiguracja `ModelContainer` dla `AlarmModel` i `WakeRecord`
- Inject `modelContext` do środowiska
- Obsługa `UNUserNotificationCenter` delegate

**Models/AlarmModel.swift**
- SwiftData `@Model` class zgodnie ze specyfikacją z CLAUDE.md
- Computed property `nextFireDate: Date?` — oblicza następne zaplanowane odpalenie

**Models/WakeRecord.swift**
- SwiftData `@Model` class zgodnie ze specyfikacją
- Computed property `reactionTime: TimeInterval?`
- Computed property `stepTime: TimeInterval?`

**Models/EmergencyReason.swift**
- Enum z `rawValue: String`, `CaseIterable`
- 4 przypadki z polskimi opisami jak w CLAUDE.md

**Services/AlarmService.swift**
- Wrapper na `UNUserNotificationCenter`
- `func scheduleAlarm(_ alarm: AlarmModel) async throws`
- `func cancelAlarm(_ alarm: AlarmModel)`
- `func requestPermission() async -> Bool`
- Obsługa powtarzających się alarmów (repeatDays)
- Używaj `UNCalendarNotificationTrigger`

**Services/PedometerService.swift**
- Wrapper na `CMPedometer`
- `@Published var stepCount: Int`
- `@Published var isAvailable: Bool`
- `func startCounting(from: Date)`
- `func stopCounting()`
- Fallback: jeśli brak uprawnień motion, pokaż manual "Potwierdź 100 kroków" button
- Sprawdź `CMPedometer.isStepCountingAvailable()`

**Services/AntiCheatService.swift**
- `CMMotionManager` z `accelerometerUpdateInterval = 0.1`
- `@Published var cheatDetected: Bool`
- Logika okna 3-sekundowego jak w CLAUDE.md
- `func startMonitoring()`
- `func stopMonitoring()`
- `func reset()` — resetuje flagę i liczy od nowa

**Services/AudioService.swift**
- `AVAudioSession` z kategorią `.playback`
- `func playAlarm()` — odtwarza systemowy dźwięk alarmu w pętli
- `func stopAlarm()`
- Obsługa przerwań audio (telefon, Siri)

**ViewModels/AlarmViewModel.swift**
- `@Observable` class (iOS 17 Observation framework)
- CRUD dla `AlarmModel` przez SwiftData `modelContext`
- `func save(_ alarm: AlarmModel)`
- `func delete(_ alarm: AlarmModel)`
- `func toggle(_ alarm: AlarmModel)` — włącz/wyłącz bez usuwania

**ViewModels/ActiveAlarmViewModel.swift**
- `@Observable` class — zarządza sesją aktywnego alarmu
- State machine: `AlarmState` enum (idle, ringing, walking, snoozed, dismissed, emergencyStopped)
- `func startSession(for alarm: AlarmModel)`
- `func snooze()` — sprawdza limit, ustawia nowy timer
- `func emergencyStop(reason: EmergencyReason)`
- `func onStepGoalReached()` — dismiss + zapis WakeRecord
- Nasłuchuje `PedometerService.$stepCount` i `AntiCheatService.$cheatDetected`
- Oblicza i zapisuje `morningScore` przez `MorningScoreCalculator`

**ViewModels/HistoryViewModel.swift**
- Pobiera `WakeRecord` z SwiftData
- Sortuje po dacie (najnowsze pierwsze)
- `var averageMorningScore: Double`
- `var totalWakeUps: Int`
- `var bestScore: Int`

**Views/RootView.swift**
- `TabView` z 3 zakładkami: "Alarm" (AlarmSetupView), "Historia" (HistoryView), "Ustawienia" (SettingsView)
- Nasłuchuje `UNUserNotificationCenter` żeby wykryć odpalenie alarmu i przejść do `ActiveAlarmView`
- `fullScreenCover` dla `ActiveAlarmView` gdy alarm aktywny

**Views/AlarmSetupView.swift**
- `DatePicker` (tryb `.hourAndMinute`) do ustawienia godziny
- Toggle dni tygodnia (Pn–Nd) — jeśli żaden nie wybrany = jednorazowy
- `Toggle` włącz/wyłącz alarm
- Przycisk "Zapisz alarm"
- Lista aktywnych alarmów poniżej

**Views/ActiveAlarmView.swift**
- Pełnoekranowy widok (`.ignoresSafeArea()`)
- Duży czas aktualny (zegar)
- Godzina alarmu
- Przycisk "DRZEMKA (N/2)" — wyszarzony gdy brak drzemek
- Przycisk "WSTAŃ I IDŹ" → przechodzi do StepCounterView
- Mały przycisk "Awaryjne wyłączenie" na dole
- Animacja pulsowania / wibracje przez `.sensoryFeedback`

**Views/StepCounterView.swift**
- Duży licznik kroków (np. "47 / 100")
- Progress ring (`Circle` z `trim`)
- Motywacyjna wiadomość zależna od postępu (z UX Copy w CLAUDE.md)
- Przycisk wyłączenia pojawia się dopiero gdy `steps >= stepGoal`
- Wykryte oszustwo → alert z resetem
- Mały przycisk "Awaryjne wyłączenie"

**Views/SuccessView.swift**
- Komunikat "Brawo! Alarm wyłączony 🎉"
- Duży wynik Morning Score (np. "85/100")
- Statystyki sesji: czas do ruchu, czas chodzenia, drzemki
- Przycisk "Zakończ" → wraca do głównego widoku

**Views/HistoryView.swift**
- `List` rekordów `WakeRecord` (SwiftData query)
- Każdy wiersz: data/godzina, Morning Score, kroki, drzemki
- Header z średnim score i liczbą pobudek
- SwipeAction do usunięcia rekordu

**Views/MorningScoreView.swift**
- Wykres słupkowy (SwiftCharts) ostatnich 7 dni
- Kolor słupka zależny od score (czerwony < 40, żółty < 70, zielony ≥ 70)
- Legenda punktów: baza, kary za drzemki, kara za czas reakcji

**Views/SettingsView.swift**
- `Stepper` cel kroków (50–200, domyślnie 100)
- `Stepper` limit drzemek (0–5, domyślnie 2)
- `Stepper` czas drzemki (1–15 min, domyślnie 5)
- Sekcja "O aplikacji"
- Przycisk "Wyczyść historię" z potwierdzeniem

**Utilities/MorningScoreCalculator.swift**
- `static func calculate(record: WakeRecord) -> Int`
- Implementacja formuły z CLAUDE.md:
  ```
  base = 100
  - snooze penalty:     snoozeCount × 15
  - reaction penalty:   max(0, (reactionTime - 60) / 10) × 2
  - emergency penalty:  wasEmergencyStopped ? 100 : 0
  + speed bonus:        stepTime < 120s ? 10 : 0
  score = clamp(base - penalties + bonuses, 0, 100)
  ```

**Utilities/Constants.swift**
```swift
enum Constants {
    static let stepGoal = 100
    static let defaultSnoozeLimit = 2
    static let defaultSnoozeDuration = 5        // minutes
    static let antiCheatPeakThreshold = 2.5     // G-force
    static let antiCheatWindowSeconds = 3.0
    static let antiCheatPeaksPerSecond = 3
    static let minStepTimeSeconds = 15.0        // 100 steps faster = cheat
}
```

**Utilities/Extensions.swift**
- `Date` extension: `formatted(style:)`, `timeString` (HH:mm)
- `Color` extension: `morningScoreColor(score:)` — red/yellow/green
- `Int` extension: `morningScoreLabel` — "Słaby" / "Dobry" / "Świetny"

---

### 3. Wymagania implementacyjne

1. **Zero force unwraps** (`!`) — używaj `guard let` lub `if let`
2. **Async/await** wszędzie gdzie możliwe (permissions, scheduling)
3. **@Observable** (nie ObservableObject) dla iOS 17+
4. **SwiftData** zamiast CoreData
5. **Obsługa błędów** — każdy serwis ma `throws` lub `Result<>` gdzie potrzeba
6. **Polskie UI** — wszystkie komunikaty po polsku zgodnie z CLAUDE.md
7. **Dark mode** — użyj semantycznych kolorów systemu (`Color.primary`, `.secondary`, etc.)
8. **Dostępność** — `.accessibilityLabel` na kluczowych elementach
9. **Info.plist** — dodaj wpisy NSMotionUsageDescription i NSMicrophoneUsageDescription
10. **Capabilities** — w komentarzu w BudzikApp.swift napisz które Background Modes trzeba włączyć ręcznie w Xcode (audio, processing)

---

### 4. Po wygenerowaniu kodu

1. Sprawdź czy wszystkie pliki się kompilują (`swift build` jeśli SPM, lub opisz potencjalne błędy kompilacji)
2. Upewnij się że nie ma circular imports
3. Sprawdź że `ModelContainer` zawiera oba modele: `AlarmModel` i `WakeRecord`
4. Napisz krótki `README.md` z instrukcją:
   - Jak otworzyć projekt w Xcode
   - Które Background Modes włączyć ręcznie
   - Jak uruchomić na symulatorze vs fizycznym iPhonie
   - Znane ograniczenia symulatora (CMPedometer symuluje kroki, anti-cheat może nie działać)

---

### Dodatkowy kontekst

- Aplikacja ma być **działającym prototypem** — priorytet to działający core loop (alarm → kroki → wyłączenie), nie perfekcyjny design
- Jeśli coś jest za złożone na MVP, zaimplementuj prosty placeholder z komentarzem `// TODO: Sprint 2`
- Anti-cheat nie musi być perfekcyjny — ma blokować tylko najprostsze próby oszustwa
- Morning Score to motywacyjna liczba, nie medyczna metryka — lekkie podejście jest OK
```

---

## Struktura folderu przed uruchomieniem Claude Code

```
budzik-app/
├── CLAUDE.md              ← specyfikacja projektu (ten plik)
├── PROMPT_FOR_CLAUDE_CODE.md  ← ten plik (tylko do wglądu)
└── (reszta wygeneruje Claude Code)
```

## Jak uruchomić

```bash
# 1. Zainstaluj Claude Code (jeśli nie masz)
npm install -g @anthropic-ai/claude-code

# 2. Wejdź do folderu projektu
mkdir budzik-app && cd budzik-app

# 3. Skopiuj CLAUDE.md do tego folderu

# 4. Uruchom Claude Code
claude

# 5. Wklej cały blok z sekcji "PROMPT" powyżej
```

## Po wygenerowaniu przez Claude Code

1. Otwórz `BudzikApp.xcodeproj` (lub `Package.swift`) w Xcode 15+
2. W target → Signing & Capabilities → dodaj:
   - **Background Modes**: zaznacz `Audio, AirPlay, and Picture in Picture` + `Background processing`
3. Ustaw swój Team w Signing
4. Uruchom na fizycznym iPhonie (pedometr nie działa w pełni na symulatorze)
5. Przetestuj: ustaw alarm za 1 minutę → poczekaj → przejdź 100 kroków
