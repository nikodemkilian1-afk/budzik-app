import SwiftUI
import SwiftData

struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @State private var activeAlarmVM: ActiveAlarmViewModel?
    @State private var showActiveAlarm = false
    @State private var pendingAlarm: AlarmModel?

    @Query(sort: \AlarmModel.createdAt, order: .reverse) private var alarms: [AlarmModel]

    var body: some View {
        TabView {
            AlarmSetupView(onTestRun: triggerTestRun)
                .tabItem { Label("Alarm", systemImage: "alarm.fill") }

            HistoryView()
                .tabItem { Label("Historia", systemImage: "clock.arrow.circlepath") }

            SettingsView()
                .tabItem { Label("Ustawienia", systemImage: "gear") }
        }
        .fullScreenCover(isPresented: $showActiveAlarm) {
            if let vm = activeAlarmVM, let alarm = pendingAlarm {
                ActiveAlarmView(viewModel: vm, alarm: alarm, onFinish: handleSessionFinish)
            }
        }
        .onAppear(perform: requestPermissionsIfNeeded)
        .onReceive(NotificationCenter.default.publisher(for: .budzikAlarmFired)) { notif in
            handleAlarmFired(notif)
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                Task { await rescheduleAlarms() }
            }
        }
    }

    private func requestPermissionsIfNeeded() {
        Task {
            _ = await AlarmService.shared.requestPermission()
        }
    }

    private func rescheduleAlarms() async {
        let vm = AlarmViewModel(modelContext: modelContext)
        await vm.rescheduleAll()
    }

    private func handleAlarmFired(_ notification: Notification) {
        let alarmId = notification.userInfo?["alarmId"] as? String
        let matched = alarms.first { $0.id.uuidString == alarmId } ?? alarms.first { $0.isActive }
        guard let alarm = matched else { return }
        startSession(for: alarm)
    }

    private func triggerTestRun(_ alarm: AlarmModel) {
        startSession(for: alarm)
    }

    private func startSession(for alarm: AlarmModel) {
        if activeAlarmVM == nil {
            activeAlarmVM = ActiveAlarmViewModel(modelContext: modelContext)
        }
        pendingAlarm = alarm
        activeAlarmVM?.startSession(for: alarm)
        showActiveAlarm = true
    }

    private func handleSessionFinish() {
        activeAlarmVM?.endSession()
        showActiveAlarm = false
        pendingAlarm = nil
    }
}

extension Notification.Name {
    static let budzikAlarmFired = Notification.Name("budzikAlarmFired")
}
