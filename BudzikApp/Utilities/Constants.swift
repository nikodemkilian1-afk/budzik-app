import Foundation

enum Constants {
    static let stepGoal = 100
    static let antiCheatPeakThreshold = 2.5     // G-force
    static let antiCheatWindowSeconds = 3.0
    static let antiCheatPeaksPerSecond = 3
    static let minStepTimeSeconds = 15.0        // 100 steps faster than this = cheat
    static let antiCheatMaxCadence = 200        // steps per minute
    static let antiCheatCadenceWindowSeconds = 5.0

    /// Threshold below which we treat the alarm as being "turned down" and
    /// force the AVAudioPlayer volume back to 1.0.
    static let alarmMinVolume: Float = 0.5

    enum NotificationCategory {
        static let alarm = "BUDZIK_ALARM"
    }

    enum NotificationAction {
        static let openApp = "OPEN_APP"
    }

    enum UserDefaultsKey {
        static let stepGoal = "settings.stepGoal"
    }
}
