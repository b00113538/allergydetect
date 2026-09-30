import UIKit
import UserNotifications
import FirebaseMessaging

/// What the user wants pushed. Stored on-device and copied onto each registered device document.
struct PushPreferences: Codable, Equatable {
    /// Evening reminder, sent only on days with nothing logged.
    var dailyReminder = true
    /// Sunday summary of the week (replaces that evening's reminder).
    var weeklySummary = true
    /// Local hour (0–23) for both.
    var reminderHour = 20

    private static let key = "nouri.pushPreferences"

    static func load(from defaults: UserDefaults = .standard) -> PushPreferences {
        defaults.data(forKey: key).flatMap { try? JSONDecoder().decode(PushPreferences.self, from: $0) } ?? PushPreferences()
    }

    func save(to defaults: UserDefaults = .standard) {
        if let data = try? JSONEncoder().encode(self) { defaults.set(data, forKey: Self.key) }
    }

    /// UTC hour at which local `hour` falls for a device `offsetMinutes` east of UTC. Mirrors
    /// `reminderUtcHour` in `firebase/functions/src/pushLogic.ts` — the hourly job queries on it.
    static func utcHour(localHour hour: Int, offsetMinutes: Int) -> Int {
        let minutes = ((hour * 60 - offsetMinutes) % 1440 + 1440) % 1440
        return minutes / 60
    }

    /// Fields for `users/{uid}/devices/{fcmToken}`. Refreshed on every launch so a DST change or a
    /// trip abroad moves the reminder with the user.
    func deviceFields(timeZone: TimeZone = .current, now: Date = .now) -> [String: Any] {
        let offset = timeZone.secondsFromGMT(for: now) / 60
        return [
            "platform": "ios",
            "timeZone": timeZone.identifier,
            "utcOffsetMinutes": offset,
            "reminderHour": reminderHour,
            "reminderUtcHour": Self.utcHour(localHour: reminderHour, offsetMinutes: offset),
            "dailyReminder": dailyReminder,
            "weeklySummary": weeklySummary,
            "updatedAt": now,
        ]
    }
}

/// Remote push via Firebase Cloud Messaging (APNs underneath).
///
/// The app registers with APNs, FCM turns the APNs token into an FCM registration token, and the
/// token is stored at `users/{uid}/devices/{token}` with the user's preferences. The hourly
/// `sendScheduledPushes` function reads those documents. Post-meal check-ins are *not* sent from the
/// server: they stay local (`NotificationService`) so they work offline.
final class PushService: NSObject, MessagingDelegate {
    static let shared = PushService()

    /// Current FCM registration token, once FCM has issued one.
    private(set) var token: String?
    /// Called on the main thread whenever FCM issues or rotates the token.
    var onTokenChange: ((String) -> Void)?

    /// Call once, after `FirebaseApp.configure()`.
    func configure() {
        Messaging.messaging().delegate = self
    }

    /// Asks APNs for a device token if the user has allowed notifications. FCM calls back with its
    /// own token via `messaging(_:didReceiveRegistrationToken:)`.
    @MainActor
    func registerIfAuthorized() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        guard [.authorized, .provisional, .ephemeral].contains(settings.authorizationStatus) else { return }
        UIApplication.shared.registerForRemoteNotifications()
    }

    /// From `application(_:didRegisterForRemoteNotificationsWithDeviceToken:)` (app delegate
    /// swizzling is disabled in Info.plist, so the token is handed over explicitly).
    func setAPNSToken(_ deviceToken: Data) {
        Messaging.messaging().apnsToken = deviceToken
    }

    /// On sign-out: invalidate the FCM token so this device stops receiving the old account's pushes.
    func reset() async {
        token = nil
        try? await Messaging.messaging().deleteToken()
    }

    // MARK: MessagingDelegate

    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let fcmToken else { return }
        DispatchQueue.main.async {
            self.token = fcmToken
            self.onTokenChange?(fcmToken)
        }
    }
}

/// Where a tapped notification should take the user.
enum NotificationRoute: String {
    case logMeal, insights
}

extension Notification.Name {
    /// Posted when a remote notification with a `route` is tapped. `object` is the `NotificationRoute`.
    static let nouriOpenRoute = Notification.Name("nouri.openRoute")
}
