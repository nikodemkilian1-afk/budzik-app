import SwiftUI
import SwiftData
import UserNotifications

// MARK: - Xcode capabilities required
// In Xcode → target BudzikApp → Signing & Capabilities, enable:
//   • Background Modes → Audio, AirPlay, and Picture in Picture
//   • Background Modes → Background processing
//   • Push Notifications (optional, for future server alarms)
// Info.plist already declares NSMotionUsageDescription and NSMicrophoneUsageDescription.

@main
struct BudzikApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    let sharedModelContainer: ModelContainer = {
        let schema = Schema([AlarmModel.self, WakeRecord.self])
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false
            // To enable iCloud sync later, add: cloudKitDatabase: .private("iCloud.com.example.Budzik")
        )
        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Failed to initialize ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(sharedModelContainer)
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    // Show banner + play sound when app is foregrounded so the user notices the alarm.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        let alarmId = notification.request.content.userInfo["alarmId"] as? String
        NotificationCenter.default.post(
            name: .budzikAlarmFired,
            object: nil,
            userInfo: alarmId.map { ["alarmId": $0] } ?? [:]
        )
        completionHandler([.banner, .sound, .list])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let alarmId = response.notification.request.content.userInfo["alarmId"] as? String
        NotificationCenter.default.post(
            name: .budzikAlarmFired,
            object: nil,
            userInfo: alarmId.map { ["alarmId": $0] } ?? [:]
        )
        completionHandler()
    }
}
