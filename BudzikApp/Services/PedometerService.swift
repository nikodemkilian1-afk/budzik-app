import Foundation
import CoreMotion
import Observation

/// Wraps CMPedometer to provide a live step count for the current session.
@Observable
final class PedometerService {
    private(set) var stepCount: Int = 0
    private(set) var isAvailable: Bool = CMPedometer.isStepCountingAvailable()
    private(set) var authorizationStatus: CMAuthorizationStatus = CMPedometer.authorizationStatus()
    private(set) var isCounting: Bool = false
    private(set) var lastError: Error?

    private let pedometer = CMPedometer()
    private var sessionStart: Date?
    /// Baseline step count we subtract so stepCount starts at zero for the session.
    private var baselineSteps: Int = 0

    func startCounting(from date: Date) {
        guard CMPedometer.isStepCountingAvailable() else {
            isAvailable = false
            return
        }

        // Always stop any running session and zero the counter before starting a new one.
        // Skipping this guard caused stale step counts to bleed between sessions.
        stopCounting()
        stepCount = 0
        baselineSteps = 0

        sessionStart = date
        isCounting = true
        lastError = nil

        pedometer.startUpdates(from: date) { [weak self] data, error in
            guard let self else { return }
            Task { @MainActor in
                if let error {
                    self.lastError = error
                    return
                }
                guard let data else { return }
                self.stepCount = max(0, data.numberOfSteps.intValue - self.baselineSteps)
            }
        }
    }

    func stopCounting() {
        guard isCounting else { return }
        pedometer.stopUpdates()
        isCounting = false
    }

    /// Reset the live counter (e.g., after a cheat trigger).
    /// Internally we re-baseline against the current pedometer reading.
    func reset(from date: Date) {
        stopCounting()
        stepCount = 0
        startCounting(from: date)
    }

    /// Manual confirmation fallback when Motion permission is denied.
    func manuallyConfirmGoal(_ goal: Int) {
        stepCount = goal
    }
}
