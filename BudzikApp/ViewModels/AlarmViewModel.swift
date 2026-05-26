import Foundation
import SwiftData
import Observation

@Observable
@MainActor
final class AlarmViewModel {
    private var modelContext: ModelContext
    private let alarmService = AlarmService.shared

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func save(_ alarm: AlarmModel) {
        modelContext.insert(alarm)
        do {
            try modelContext.save()
        } catch {
            print("[AlarmViewModel] Save failed: \(error)")
            return
        }
        AnalyticsService.log(.alarmCreated, properties: [
            "hour": alarm.hour,
            "minute": alarm.minute,
            "repeatDays": alarm.repeatDays
        ])
        Task { await schedule(alarm) }
    }

    func update(_ alarm: AlarmModel) {
        do {
            try modelContext.save()
        } catch {
            print("[AlarmViewModel] Update save failed: \(error)")
        }
        Task { await schedule(alarm) }
    }

    func delete(_ alarm: AlarmModel) {
        alarmService.cancelAlarm(alarm)
        modelContext.delete(alarm)
        do {
            try modelContext.save()
        } catch {
            print("[AlarmViewModel] Delete failed: \(error)")
        }
    }

    func toggle(_ alarm: AlarmModel) {
        alarm.isActive.toggle()
        update(alarm)
    }

    private func schedule(_ alarm: AlarmModel) async {
        do {
            try await alarmService.scheduleAlarm(alarm)
        } catch {
            print("[AlarmViewModel] Scheduling failed: \(error)")
        }
    }

    func rescheduleAll() async {
        let descriptor = FetchDescriptor<AlarmModel>(predicate: #Predicate { $0.isActive })
        guard let alarms = try? modelContext.fetch(descriptor) else { return }
        for alarm in alarms {
            await schedule(alarm)
        }
    }
}
