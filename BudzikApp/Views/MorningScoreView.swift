import SwiftUI
import Charts

struct MorningScoreView: View {
    let records: [WakeRecord]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Ostatnie 7 dni")
                .font(.headline)
                .padding(.horizontal)

            if records.isEmpty {
                Text("Brak danych")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
            } else {
                Chart(records) { record in
                    BarMark(
                        x: .value("Dzień", record.alarmStartedAt, unit: .day),
                        y: .value("Score", record.morningScore)
                    )
                    .foregroundStyle(Color.morningScoreColor(score: record.morningScore))
                    .cornerRadius(6)
                }
                .chartYScale(domain: 0...100)
                .chartYAxis {
                    AxisMarks(values: [0, 50, 100])
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day)) { value in
                        AxisGridLine()
                        AxisValueLabel(format: .dateTime.weekday(.narrow))
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}

