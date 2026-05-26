import Foundation

/// Lightweight wrapper for analytics. Prints to console for MVP — swap implementation later.
enum AnalyticsEvent: String {
    case alarmCreated     = "alarm_created"
    case alarmStarted     = "alarm_started"
    case stepsStarted     = "steps_started"
    case stepsCompleted   = "steps_completed"
    case alarmDismissed   = "alarm_dismissed"
    case cheatDetected    = "cheat_detected"
}

enum AnalyticsService {
    static func log(_ event: AnalyticsEvent, properties: [String: Any] = [:]) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        if properties.isEmpty {
            print("[Analytics][\(timestamp)] \(event.rawValue)")
        } else {
            print("[Analytics][\(timestamp)] \(event.rawValue) — \(properties)")
        }
    }
}
