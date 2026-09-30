import SwiftUI
import UserNotifications

struct SettingsView: View {
    @EnvironmentObject private var app: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var knownGroups: Set<AllergenGroup> = []
    @State private var otherConditions = ""
    @State private var confirmSignOut = false
    @State private var push = PushPreferences()
    @State private var notificationStatus: UNAuthorizationStatus = .notDetermined
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        NavigationStack {
            Form {
                if let user = app.user {
                    Section("Account") {
                        LabeledContent("Name", value: user.name)
                        if !user.email.isEmpty { LabeledContent("Email", value: user.email) }
                        if app.isDemoMode { LabeledContent("Mode", value: "Demo (on-device only)") }
                    }
                }
                Section {
                    FlowLayout {
                        ForEach(AllergenGroup.allCases) { group in
                            Chip(title: group.label, isSelected: knownGroups.contains(group), tint: .nouriDanger) {
                                knownGroups.formSymmetricDifference([group])
                            }
                        }
                    }
                    .padding(.vertical, 4)
                    TextField("Other (comma separated)", text: $otherConditions)
                } header: {
                    Text("Known allergies")
                } footer: {
                    Text("These are always included on your Dine Code as confirmed allergies.")
                }
                notificationsSection
                if app.isDemoMode {
                    Section("Demo") {
                        Button("Load sample history") { app.loadSampleData() }
                    }
                }
                Section {
                    Button("Sign out", role: .destructive) { confirmSignOut = true }
                } footer: {
                    Text(app.isDemoMode ? "Signing out deletes all data on this device." : "Your data stays in your account and syncs back when you sign in.")
                }
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveConditions()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
            .confirmationDialog("Sign out?", isPresented: $confirmSignOut) {
                Button("Sign out", role: .destructive) {
                    dismiss()
                    Task { await app.signOut() }
                }
            }
            .onAppear {
                loadConditions()
                push = app.pushPreferences
            }
            .task { await refreshNotificationStatus() }
            .onChange(of: scenePhase) { _, phase in
                // Coming back from the system Settings app after enabling notifications.
                if phase == .active { Task { await refreshNotificationStatus() } }
            }
            .onChange(of: push) { _, new in
                if new != app.pushPreferences { app.updatePushPreferences(new) }
            }
        }
    }

    @ViewBuilder
    private var notificationsSection: some View {
        Section {
            switch notificationStatus {
            case .denied:
                Label("Notifications are off for Nouri", systemImage: "bell.slash")
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                }
            case .notDetermined:
                Button("Turn on notifications") {
                    Task {
                        _ = await NotificationService.requestAuthorization()
                        await refreshNotificationStatus()
                        await app.refreshPushRegistration()
                    }
                }
            default:
                if app.isPushAvailable {
                    Toggle("Evening reminder", isOn: $push.dailyReminder)
                    Toggle("Weekly summary", isOn: $push.weeklySummary)
                    if push.dailyReminder || push.weeklySummary {
                        Picker("Time", selection: $push.reminderHour) {
                            ForEach(16...22, id: \.self) { hour in
                                Text(Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: .now)?
                                    .formatted(date: .omitted, time: .shortened) ?? "\(hour):00").tag(hour)
                            }
                        }
                    }
                } else {
                    Label("Check-in reminders are on", systemImage: "bell")
                }
            }
        } header: {
            Text("Notifications")
        } footer: {
            Text(app.isPushAvailable
                 ? "A check-in a few hours after each meal, always. The evening reminder only comes on days you haven't logged anything; on Sundays it's replaced by your weekly summary."
                 : "A check-in a few hours after each meal. Evening reminders and weekly summaries need Firebase (demo mode is on-device only).")
        }
    }

    private func refreshNotificationStatus() async {
        notificationStatus = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    private func loadConditions() {
        let conditions = app.user?.knownConditions ?? []
        knownGroups = Set(conditions.compactMap(AllergenGroup.init(rawValue:)))
        otherConditions = conditions.filter { AllergenGroup(rawValue: $0) == nil }.joined(separator: ", ")
    }

    private func saveConditions() {
        let others = otherConditions.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces).lowercased() }.filter { !$0.isEmpty }
        app.updateKnownConditions(AllergenGroup.allCases.filter(knownGroups.contains).map(\.rawValue) + others)
    }
}
