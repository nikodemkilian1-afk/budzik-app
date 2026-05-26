import SwiftUI
import SwiftData

struct HistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WakeRecord.alarmStartedAt, order: .reverse) private var records: [WakeRecord]

    var body: some View {
        NavigationStack {
            Group {
                if records.isEmpty {
                    ContentUnavailableView(
                        "Brak historii",
                        systemImage: "moon.zzz",
                        description: Text("Twoje pobudki pojawią się tutaj.")
                    )
                } else {
                    List {
                        statsHeader
                        MorningScoreView(records: Array(records.prefix(7)).reversed())
                            .frame(height: 220)
                            .listRowInsets(EdgeInsets())
                            .padding(.vertical, 8)
                        Section("Pobudki") {
                            ForEach(records) { record in
                                row(for: record)
                            }
                            .onDelete(perform: delete)
                        }
                    }
                }
            }
            .navigationTitle("Historia")
        }
    }

    private var statsHeader: some View {
        Section {
            HStack(spacing: 12) {
                statTile(label: "Średni", value: String(format: "%.0f", averageScore))
                statTile(label: "Pobudki", value: "\(records.count)")
                statTile(label: "Najlepszy", value: "\(bestScore)")
            }
            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            .listRowBackground(Color.clear)
        }
    }

    private func statTile(label: String, value: String) -> some View {
        VStack(spacing: 6) {
            Text(value)
                .font(.title2.weight(.bold))
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func row(for record: WakeRecord) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(record.alarmStartedAt.fullDateTimeString)
                    .font(.subheadline.weight(.medium))
                HStack(spacing: 10) {
                    Label("\(record.stepsTaken)", systemImage: "figure.walk")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(record.morningScore)")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(Color.morningScoreColor(score: record.morningScore))
                Text(record.morningScore.morningScoreLabel)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private var averageScore: Double {
        guard !records.isEmpty else { return 0 }
        return Double(records.map(\.morningScore).reduce(0, +)) / Double(records.count)
    }

    private var bestScore: Int {
        records.map(\.morningScore).max() ?? 0
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(records[index])
        }
        try? modelContext.save()
    }
}
