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
    /// Posted when the user taps a meal check-in reminder. `object` is the meal id.
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
        let mealId = response.notification.request.content.userInfo["mealEntryId"] as? String
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .nouriOpenSymptomLog, object: mealId)
        }
        completionHandler()
    }
}
