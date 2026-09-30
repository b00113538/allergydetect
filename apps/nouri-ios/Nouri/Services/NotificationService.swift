import UserNotifications

/// Post-meal check-ins: local notifications scheduled on-device after each meal. They fire even
/// when the app isn't running and need no network. Server-sent pushes (evening reminder, weekly
/// summary) live in `PushService` / `sendScheduledPushes`.
enum NotificationService {
    static func requestAuthorization() async -> Bool {
        (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    /// Nudges the user a few hours after a meal — inside the 0–8h detection window.
    static func scheduleCheckIn(for meal: MealEntry, after delay: TimeInterval = 3 * 3600) {
        let content = UNMutableNotificationContent()
        content.title = "How are you feeling?"
        content.body = "It's been a few hours since your \(meal.mealType.label.lowercased()). Log any symptoms — or that you feel fine."
        content.sound = .default
        content.userInfo = ["mealEntryId": meal.id]

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: delay, repeats: false)
        let request = UNNotificationRequest(identifier: "checkin-\(meal.id)", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    static func cancelCheckIn(forMealId id: String) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["checkin-\(id)"])
    }
}
