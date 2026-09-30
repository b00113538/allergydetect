import SwiftUI
import FirebaseCore
import UserNotifications

@main
struct NouriApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var appState: AppState

    init() {
        // Must run before AppState creates FirebaseService (which touches Auth/Firestore).
        if AppEnvironment.isFirebaseConfigured {
            FirebaseApp.configure()
            PushService.shared.configure()
        }
        _appState = StateObject(wrappedValue: AppState.live())
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
                .tint(Color.nouriPrimary)
        }
    }
}

extension Notification.Name {
    /// Posted when the user taps a meal check-in reminder (local notification). `object` is the meal id.
    static let nouriOpenSymptomLog = Notification.Name("nouri.openSymptomLog")
}

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        DispatchQueue.main.async {
            if let route = (userInfo["route"] as? String).flatMap(NotificationRoute.init(rawValue:)) {
                // Remote push from `sendScheduledPushes`.
                NotificationCenter.default.post(name: .nouriOpenRoute, object: route)
            } else {
                // Local post-meal check-in.
                NotificationCenter.default.post(name: .nouriOpenSymptomLog, object: userInfo["mealEntryId"] as? String)
            }
        }
        completionHandler()
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        if AppEnvironment.isFirebaseConfigured { PushService.shared.setAPNSToken(deviceToken) }
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        // Expected in the simulator without a push-capable setup; local check-ins still work.
        print("[Push] APNs registration failed: \(error.localizedDescription)")
    }
}
