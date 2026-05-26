import Foundation
import SwiftData
import Observation

@Observable
@MainActor
final class HistoryViewModel {
    private var modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func fetchRecords() -> [WakeRecord] {
        let descriptor = FetchDescriptor<WakeRecord>(
            sortBy: [SortDescriptor(\WakeRecord.alarmStartedAt, order: .reverse)]
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    var totalWakeUps: Int { fetchRecords().count }

    var averageMorningScore: Double {
        let records = fetchRecords()
        guard !records.isEmpty else { return 0 }
        return Double(records.map(\.morningScore).reduce(0, +)) / Double(records.count)
    }

    var bestScore: Int {
        fetchRecords().map(\.morningScore).max() ?? 0
    }

    func delete(_ record: WakeRecord) {
        modelContext.delete(record)
        try? modelContext.save()
    }

    func deleteAll() {
        for record in fetchRecords() {
            modelContext.delete(record)
        }
        try? modelContext.save()
    }

    /// Most recent 7 records for the score chart.
    func recentRecords(limit: Int = 7) -> [WakeRecord] {
        Array(fetchRecords().prefix(limit)).reversed()
    }
}
