import Foundation
import SwiftData

@Model
final class AlarmModel {
    @Attribute(.unique) var id: UUID
    var hour: Int
    var minute: Int
    /// Comma-separated weekday indices (0=Sun … 6=Sat). Stored as String because
    /// SwiftData on iOS 17 fails to materialize `[Int]` ("Could not materialize
    /// Objective-C class named Array from declared attribute value type Array<Int>").
    /// Access via the `repeatDays` computed overlay.
    var repeatDaysRaw: String = ""
    var isActive: Bool
    var stepGoal: Int              // default: 100
    var label: String
    var createdAt: Date

    var repeatDays: [Int] {
        get { repeatDaysRaw.isEmpty ? [] : repeatDaysRaw.split(separator: ",").compactMap { Int($0) } }
        set { repeatDaysRaw = newValue.map(String.init).joined(separator: ",") }
    }

    init(
        id: UUID = UUID(),
        hour: Int,
        minute: Int,
        repeatDays: [Int] = [],
        isActive: Bool = true,
        stepGoal: Int = Constants.stepGoal,
        label: String = "",
        createdAt: Date = .now
    ) {
        self.id = id
        self.hour = hour
        self.minute = minute
        self.repeatDaysRaw = repeatDays.map(String.init).joined(separator: ",")
        self.isActive = isActive
        self.stepGoal = stepGoal
        self.label = label
        self.createdAt = createdAt
    }

    var timeString: String {
        String(format: "%02d:%02d", hour, minute)
    }

    /// Next scheduled fire date from now, honoring `repeatDays` (0=Sun…6=Sat).
    /// Returns nil if alarm is inactive.
    var nextFireDate: Date? {
        guard isActive else { return nil }
        let calendar = Calendar.current
        let now = Date()

        if repeatDays.isEmpty {
            var components = calendar.dateComponents([.year, .month, .day], from: now)
            components.hour = hour
            components.minute = minute
            components.second = 0
            guard let candidate = calendar.date(from: components) else { return nil }
            if candidate > now { return candidate }
            return calendar.date(byAdding: .day, value: 1, to: candidate)
        }

        // Find soonest weekday match (today through 7 days).
        let weekdayToday = calendar.component(.weekday, from: now) - 1 // 0=Sun
        for offset in 0..<8 {
            let weekday = (weekdayToday + offset) % 7
            guard repeatDays.contains(weekday) else { continue }
            guard let base = calendar.date(byAdding: .day, value: offset, to: now) else { continue }
            var components = calendar.dateComponents([.year, .month, .day], from: base)
            components.hour = hour
            components.minute = minute
            components.second = 0
            guard let candidate = calendar.date(from: components) else { continue }
            if candidate > now { return candidate }
        }
        return nil
    }
}
