import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext

    @AppStorage(Constants.UserDefaultsKey.stepGoal) private var stepGoal: Int = Constants.stepGoal

    @State private var showClearConfirmation = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Domyślne ustawienia alarmu") {
                    Stepper(value: $stepGoal, in: 50...200, step: 10) {
                        labelRow(title: "Cel kroków", value: "\(stepGoal)")
                    }
                    Text("Liczba ta dotyczy nowych alarmów. Istniejące alarmy zachowują swój własny cel.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Dane") {
                    Button(role: .destructive) {
                        showClearConfirmation = true
                    } label: {
                        Label("Wyczyść historię", systemImage: "trash")
                    }
                }

                Section("O aplikacji") {
                    HStack {
                        Text("Wersja")
                        Spacer()
                        Text(Bundle.main.shortVersion).foregroundStyle(.secondary)
                    }
                    Text("Budzik 100 Kroków — MVP")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Ustawienia")
            .onChange(of: stepGoal) { _, newValue in
                applyStepGoalToExistingAlarms(newValue)
            }
            .confirmationDialog(
                "Wyczyścić całą historię?",
                isPresented: $showClearConfirmation,
                titleVisibility: .visible
            ) {
                Button("Wyczyść", role: .destructive) { clearHistory() }
                Button("Anuluj", role: .cancel) {}
            } message: {
                Text("Usuniemy wszystkie zapisane pobudki. Nie można tego cofnąć.")
            }
        }
    }

    private func labelRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value).foregroundStyle(.secondary)
        }
    }

    private func clearHistory() {
        let descriptor = FetchDescriptor<WakeRecord>()
        guard let records = try? modelContext.fetch(descriptor) else { return }
        for record in records {
            modelContext.delete(record)
        }
        try? modelContext.save()
    }

    /// Push the new default into every saved alarm so the active session reads the latest goal.
    private func applyStepGoalToExistingAlarms(_ goal: Int) {
        let descriptor = FetchDescriptor<AlarmModel>()
        guard let alarms = try? modelContext.fetch(descriptor) else { return }
        for alarm in alarms {
            alarm.stepGoal = goal
        }
        try? modelContext.save()
    }
}

private extension Bundle {
    var shortVersion: String {
        (infoDictionary?["CFBundleShortVersionString"] as? String) ?? "1.0"
    }
}
