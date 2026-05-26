import Foundation
import CoreMotion
import Observation

/// Detects shaking-style cheats by sampling the accelerometer.
/// Rolls a window of the last `antiCheatWindowSeconds` of peaks
/// and trips when peak rate exceeds `antiCheatPeaksPerSecond`.
@Observable
final class AntiCheatService {
    private(set) var cheatDetected: Bool = false
    private(set) var isMonitoring: Bool = false

    private let motionManager = CMMotionManager()
    private let queue = OperationQueue()
    private var peakTimestamps: [Date] = []

    init() {
        motionManager.accelerometerUpdateInterval = 0.1
        queue.qualityOfService = .userInteractive
    }

    func startMonitoring() {
        guard motionManager.isAccelerometerAvailable, !isMonitoring else { return }
        isMonitoring = true
        cheatDetected = false
        peakTimestamps.removeAll()

        motionManager.startAccelerometerUpdates(to: queue) { [weak self] data, _ in
            guard let self, let data else { return }
            let magnitude = sqrt(
                data.acceleration.x * data.acceleration.x +
                data.acceleration.y * data.acceleration.y +
                data.acceleration.z * data.acceleration.z
            )
            guard magnitude > Constants.antiCheatPeakThreshold else { return }
            self.recordPeak()
        }
    }

    func stopMonitoring() {
        guard isMonitoring else { return }
        motionManager.stopAccelerometerUpdates()
        isMonitoring = false
    }

    func reset() {
        Task { @MainActor in
            self.cheatDetected = false
            self.peakTimestamps.removeAll()
        }
    }

    private func recordPeak() {
        let now = Date()
        let windowStart = now.addingTimeInterval(-Constants.antiCheatWindowSeconds)
        peakTimestamps.append(now)
        peakTimestamps.removeAll { $0 < windowStart }

        let threshold = Int(Constants.antiCheatWindowSeconds) * Constants.antiCheatPeaksPerSecond
        if peakTimestamps.count >= threshold {
            Task { @MainActor in
                self.cheatDetected = true
            }
        }
    }
}
