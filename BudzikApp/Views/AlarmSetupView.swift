import SwiftUI
import SwiftData

struct AlarmSetupView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \AlarmModel.hour) private var alarms: [AlarmModel]

    @AppStorage(Constants.UserDefaultsKey.stepGoal) private var defaultStepGoal: Int = Constants.stepGoal

    @State private var newAlarmTime: Date = defaultAlarmTime()
    @State private var selectedDays: Set<Int> = []
    @State private var label: String = ""

    /// Optional callback the parent uses to trigger a manual test run of an alarm.
    var onTestRun: (AlarmModel) -> Void = { _ in }

    private var viewModel: AlarmViewModel {
        AlarmViewModel(modelContext: modelContext)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Nowy alarm") {
                    DatePicker(
                        "Godzina",
                        selection: $newAlarmTime,
                        displayedComponents: .hourAndMinute
                    )
                    .datePickerStyle(.wheel)
                    .labelsHidden()

                    weekdayPicker

                    TextField("Etykieta (opcjonalna)", text: $label)

                    HStack {
                        Text("Cel kroków")
                        Spacer()
                        Text("\(defaultStepGoal)")
                            .foregroundStyle(.secondary)
                    }

                    Button(action: saveAlarm) {
                        Label("Zapisz alarm", systemImage: "plus.circle.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                }

                Section("Twoje alarmy") {
                    if alarms.isEmpty {
                        Text("Brak alarmów. Dodaj pierwszy powyżej.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(alarms) { alarm in
                            alarmRow(alarm)
                        }
                        .onDelete(perform: deleteAlarms)
                    }
                }
            }
            .navigationTitle("Budzik 100 Kroków")
        }
    }

    private var weekdayPicker: some View {
        HStack(spacing: 6) {
            ForEach(weekdayOrder, id: \.self) { day in
                let label = weekdayLetters[day]
                let isSelected = selectedDays.contains(day)
                Button {
                    if isSelected { selectedDays.remove(day) } else { selectedDays.insert(day) }
                } label: {
                    Text(label)
                        .font(.subheadline.weight(.semibold))
                        .frame(width: 36, height: 36)
                        .background(isSelected ? Color.accentColor : Color.secondary.opacity(0.15))
                        .foregroundStyle(isSelected ? .white : .primary)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(weekdayFullNames[day])
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
    }

    private func alarmRow(_ alarm: AlarmModel) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(alarm.timeString)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(alarm.isActive ? .primary : .secondary)
                Text(alarm.repeatDays.repeatDaysLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if !alarm.label.isEmpty {
                    Text(alarm.label)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Text("Cel: \(alarm.stepGoal) kroków")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Toggle("", isOn: Binding(
                get: { alarm.isActive },
                set: { _ in viewModel.toggle(alarm) }
            ))
            .labelsHidden()
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                viewModel.delete(alarm)
            } label: {
                Label("Usuń", systemImage: "trash")
            }
            Button {
                onTestRun(alarm)
            } label: {
                Label("Test", systemImage: "play.fill")
            }
            .tint(.blue)
        }
    }

    private func saveAlarm() {
        let components = Calendar.current.dateComponents([.hour, .minute], from: newAlarmTime)
        let alarm = AlarmModel(
            hour: components.hour ?? 7,
            minute: components.minute ?? 0,
            repeatDays: selectedDays.sorted(),
            stepGoal: defaultStepGoal,
            label: label
        )
        viewModel.save(alarm)
        selectedDays.removeAll()
        label = ""
    }

    private func deleteAlarms(at offsets: IndexSet) {
        for index in offsets {
            viewModel.delete(alarms[index])
        }
    }

    private static func defaultAlarmTime() -> Date {
        Calendar.current.date(bySettingHour: 7, minute: 0, second: 0, of: .now) ?? .now
    }

    // 0 = Sunday, but the display order starts with Monday for Polish users.
    private let weekdayOrder = [1, 2, 3, 4, 5, 6, 0]
    private let weekdayLetters = ["N", "P", "W", "Ś", "C", "P", "S"]
    private let weekdayFullNames = ["Niedziela", "Poniedziałek", "Wtorek", "Środa", "Czwartek", "Piątek", "Sobota"]
}
