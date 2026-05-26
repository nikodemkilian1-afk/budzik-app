import Foundation
import SwiftData
import Observation

enum AlarmState {
    case idle
    case ringing
    case walking
    case dismissed
}

@Observable
@MainActor
final class ActiveAlarmViewModel {
    // Live state surfaced to views.
    private(set) var state: AlarmState = .idle
    private(set) var stepCount: Int = 0
    private(set) var motionPermissionDenied: Bool = false
    var cheatWarning: String?

    let pedometer = PedometerService()
    let antiCheat = AntiCheatService()

    private let audio = AudioService.shared
    private var modelContext: ModelContext

    private(set) var alarm: AlarmModel?
    private var alarmStartedAt: Date?
    private var movementStartedAt: Date?
    private var pedometerObservation: Task<Void, Never>?
    private var cheatObservation: Task<Void, Never>?

    var stepGoal: Int { alarm?.stepGoal ?? Constants.stepGoal }
    var stepsRemaining: Int { max(0, stepGoal - stepCount) }
    var progress: Double {
        guard stepGoal > 0 else { return 0 }
        return min(1.0, Double(stepCount) / Double(stepGoal))
    }

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Session lifecycle

    func startSession(for alarm: AlarmModel) {
        guard state == .idle else { return }
        self.alarm = alarm
        alarmStartedAt = Date()
        movementStartedAt = nil
        // Explicit pedometer reset before every new session — guards against stale state.
        pedometer.stopCounting()
        stepCount = 0
        state = .ringing
        motionPermissionDenied = (PedometerService().authorizationStatus == .denied)

        // Cancel the rest of the notification chain — the user is now in-app,
        // so AVAudioPlayer takes over. Without this, lock-screen notifications
        // keep firing every ~28s for the duration of the chain.
        AlarmService.shared.cancelAlarm(alarm)

        audio.playAlarm()
        AnalyticsService.log(.alarmStarted, properties: ["alarmId": alarm.id.uuidString])

        startObservers()
    }

    /// User pressed "Wstań i idź" — begins step counting + anti-cheat.
    func beginWalking() {
        guard let alarmStartedAt else { return }
        guard state == .ringing else { return }
        movementStartedAt = Date()
        state = .walking
        pedometer.startCounting(from: alarmStartedAt)
        antiCheat.startMonitoring()
        AnalyticsService.log(.stepsStarted)
    }

    func confirmManualGoal() {
        guard state == .walking else { return }
        pedometer.manuallyConfirmGoal(stepGoal)
        // Manual confirmation triggers goal check via observer on next tick.
        stepCount = stepGoal
        onStepGoalReached()
    }

    private func onStepGoalReached() {
        guard let alarm, let alarmStartedAt, state == .walking else { return }
        state = .dismissed
        AnalyticsService.log(.stepsCompleted, properties: ["steps": stepCount])

        let dismissedAt = Date()
        let record = WakeRecord(
            alarmTime: alarmFireDate(for: alarm),
            alarmStartedAt: alarmStartedAt,
            movementStartedAt: movementStartedAt,
            dismissedAt: dismissedAt,
            stepsTaken: stepCount,
            morningScore: 0
        )
        record.morningScore = MorningScoreCalculator.calculate(record: record)
        save(record: record)

        cleanup()
        AnalyticsService.log(.alarmDismissed, properties: ["score": record.morningScore])
    }

    // MARK: - Observers

    private func startObservers() {
        pedometerObservation?.cancel()
        cheatObservation?.cancel()

        pedometerObservation = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                let newCount = self.pedometer.stepCount
                if newCount != self.stepCount {
                    self.stepCount = newCount
                    self.checkCheatBySpeed()
                    if self.stepCount >= self.stepGoal {
                        self.onStepGoalReached()
                        return
                    }
                }
                try? await Task.sleep(nanoseconds: 200_000_000)
            }
        }

        cheatObservation = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                if self.antiCheat.cheatDetected {
                    self.handleCheatDetected(reason: "Wykryto potrząsanie — zacznij od nowa")
                    self.antiCheat.reset()
                }
                try? await Task.sleep(nanoseconds: 300_000_000)
            }
        }
    }

    private func checkCheatBySpeed() {
        guard let movementStartedAt else { return }
        let elapsed = Date().timeIntervalSince(movementStartedAt)
        if stepCount >= stepGoal && elapsed < Constants.minStepTimeSeconds {
            handleCheatDetected(reason: "Zbyt szybko — to niemożliwe pieszo. Zacznij od nowa.")
        }
    }

    private func handleCheatDetected(reason: String) {
        guard state == .walking, let alarmStartedAt else { return }
        AnalyticsService.log(.cheatDetected, properties: ["reason": reason])
        cheatWarning = reason
        stepCount = 0
        pedometer.reset(from: alarmStartedAt)
    }

    // MARK: - Cleanup

    func dismissCheatWarning() {
        cheatWarning = nil
    }

    func endSession() {
        cleanup()
        state = .idle
        alarm = nil
        stepCount = 0
        movementStartedAt = nil
        alarmStartedAt = nil
    }

    private func cleanup() {
        audio.stopAlarm()
        pedometer.stopCounting()
        antiCheat.stopMonitoring()
        pedometerObservation?.cancel()
        cheatObservation?.cancel()
    }

    private func save(record: WakeRecord) {
        modelContext.insert(record)
        do {
            try modelContext.save()
        } catch {
            print("[ActiveAlarmViewModel] Save wake record failed: \(error)")
        }
    }

    private func alarmFireDate(for alarm: AlarmModel) -> Date {
        let calendar = Calendar.current
        let now = Date()
        var components = calendar.dateComponents([.year, .month, .day], from: now)
        components.hour = alarm.hour
        components.minute = alarm.minute
        return calendar.date(from: components) ?? now
    }
}
