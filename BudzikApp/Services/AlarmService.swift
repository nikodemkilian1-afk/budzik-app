import Foundation
import UserNotifications

enum AlarmServiceError: Error {
    case permissionDenied
    case schedulingFailed(Error)
}

/// Wraps UNUserNotificationCenter for scheduling and cancelling alarms.
///
/// Lock-screen ringing is delivered via a *chain* of back-to-back time-sensitive
/// notifications, each playing the ~28-second `alarm_loop.caf` sound. The chain
/// adds up to several minutes of continuous-feeling ringing without needing the
/// app to be awake — iOS schedules and fires each notification independently.
///
/// One AlarmModel may produce many notification requests:
///   - non-repeating alarm  → `chainLength` requests at fireDate, +28s, +56s, …
///   - repeating alarm      → same chain, replicated per weekday in `repeatDays`
///
/// Budget: iOS keeps at most 64 pending notifications per app. The current
/// settings (chainLength = 10, ~5 min ringing) easily fit even with several
/// repeating alarms.
final class AlarmService {
    static let shared = AlarmService()
    private let center = UNUserNotificationCenter.current()

    /// Per-alarm notifications in the chain. 10 × 28s ≈ 4 min 40 s of ringing.
    private let chainLength: Int = 10
    /// Seconds between consecutive notification fires — match the looped sound length.
    private let chainSpacing: TimeInterval = 28
    private let soundName = "alarm_loop.caf"

    private init() {
        registerCategories()
    }

    private func registerCategories() {
        let openAction = UNNotificationAction(
            identifier: Constants.NotificationAction.openApp,
            title: "Otwórz aplikację",
            options: [.foreground]
        )
        let category = UNNotificationCategory(
            identifier: Constants.NotificationCategory.alarm,
            actions: [openAction],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )
        center.setNotificationCategories([category])
    }

    func requestPermission() async -> Bool {
        do {
            return try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    func scheduleAlarm(_ alarm: AlarmModel) async throws {
        cancelAlarm(alarm)
        guard alarm.isActive else { return }

        if alarm.repeatDays.isEmpty {
            guard let fire = alarm.nextFireDate else { return }
            try await scheduleChain(for: alarm, startingAt: fire, weekday: nil)
        } else {
            for weekday in alarm.repeatDays {
                try await scheduleChain(for: alarm, startingAt: nil, weekday: weekday)
            }
        }
    }

    /// Schedule `chainLength` notifications back-to-back so the alarm rings for several minutes.
    /// - `startingAt`: absolute date for one-shot alarms. Triggers each request at offset `i * chainSpacing`.
    /// - `weekday`: for repeating alarms, the 0=Sun…6=Sat weekday. Triggers each request via
    ///   `UNCalendarNotificationTrigger` matching that weekday + the alarm time offset by `i * chainSpacing`.
    private func scheduleChain(for alarm: AlarmModel, startingAt: Date?, weekday: Int?) async throws {
        let calendar = Calendar.current

        for index in 0..<chainLength {
            let content = buildContent(for: alarm, chainIndex: index)
            let trigger: UNNotificationTrigger

            if let weekday {
                // Repeating: base time is alarm.hour:alarm.minute on the given weekday,
                // shifted by `index * chainSpacing` seconds.
                var base = DateComponents()
                base.weekday = weekday + 1 // model uses 0=Sun, DateComponents uses 1=Sun
                base.hour = alarm.hour
                base.minute = alarm.minute
                base.second = 0
                guard let baseDate = calendar.nextDate(after: Date(), matching: base, matchingPolicy: .nextTime) else { continue }
                let shifted = baseDate.addingTimeInterval(Double(index) * chainSpacing)
                let parts = calendar.dateComponents([.weekday, .hour, .minute, .second], from: shifted)
                trigger = UNCalendarNotificationTrigger(dateMatching: parts, repeats: true)
            } else if let startingAt {
                let fire = startingAt.addingTimeInterval(Double(index) * chainSpacing)
                let parts = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: fire)
                trigger = UNCalendarNotificationTrigger(dateMatching: parts, repeats: false)
            } else {
                continue
            }

            let request = UNNotificationRequest(
                identifier: requestIdentifier(for: alarm, weekday: weekday, chainIndex: index),
                content: content,
                trigger: trigger
            )
            try await center.add(request)
        }
    }

    private func buildContent(for alarm: AlarmModel, chainIndex: Int) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = "⏰ Czas wstawać!"
        content.body = alarm.label.isEmpty
            ? "Otwórz aplikację i przejdź \(alarm.stepGoal) kroków, żeby wyłączyć alarm."
            : alarm.label
        content.sound = UNNotificationSound(named: UNNotificationSoundName(soundName))
        content.interruptionLevel = .timeSensitive
        content.categoryIdentifier = Constants.NotificationCategory.alarm
        content.userInfo = [
            "alarmId": alarm.id.uuidString,
            "chainIndex": chainIndex
        ]
        return content
    }

    func cancelAlarm(_ alarm: AlarmModel) {
        let ids = allPossibleIdentifiers(for: alarm)
        center.removePendingNotificationRequests(withIdentifiers: ids)
        center.removeDeliveredNotifications(withIdentifiers: ids)
    }

    func cancelAll() {
        center.removeAllPendingNotificationRequests()
        center.removeAllDeliveredNotifications()
    }

    // MARK: - Identifier helpers

    private func requestIdentifier(for alarm: AlarmModel, weekday: Int?, chainIndex: Int) -> String {
        let base = alarm.id.uuidString
        if let weekday {
            return "\(base)-w\(weekday)-c\(chainIndex)"
        }
        return "\(base)-c\(chainIndex)"
    }

    /// Every identifier this alarm might own — used for cancellation.
    private func allPossibleIdentifiers(for alarm: AlarmModel) -> [String] {
        var ids: [String] = []
        let base = alarm.id.uuidString
        // Legacy single-shot ids from before the chain rewrite — harmless if absent.
        ids.append(base)
        for w in 0..<7 { ids.append("\(base)-\(w)") }
        // Current chain ids.
        for c in 0..<chainLength {
            ids.append("\(base)-c\(c)")
            for w in 0..<7 {
                ids.append("\(base)-w\(w)-c\(c)")
            }
        }
        return ids
    }
}
