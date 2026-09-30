import SwiftUI
import UserNotifications

struct SettingsView: View {
    @EnvironmentObject private var app: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var knownGroups: Set<AllergenGroup> = []
    @State private var otherConditions = ""
    @State private var confirmSignOut = false
    @State private var confirmDelete = false
    @State private var isDeleting = false
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
                Section("About") {
                    Link("Privacy policy", destination: AppEnvironment.webPage("privacy"))
                    Link("Help & support", destination: AppEnvironment.webPage("support"))
                    LabeledContent("Version", value: Self.versionString)
                    Text("Nouri shows patterns in what you log. It isn't a medical device and doesn't diagnose allergies — talk to a clinician before changing your diet or treatment.")
                        .font(.footnote)
                        .foregroundStyle(Color.nouriTextSecondary)
                }
                Section {
                    Button("Sign out", role: .destructive) { confirmSignOut = true }
                } footer: {
                    Text(app.isDemoMode ? "Signing out deletes all data on this device." : "Your data stays in your account and syncs back when you sign in.")
                }
                Section {
                    Button(role: .destructive) { confirmDelete = true } label: {
                        if isDeleting {
                            HStack { ProgressView(); Text("Deleting…") }
                        } else {
                            Text("Delete account")
                        }
                    }
                    .disabled(isDeleting)
                } footer: {
                    Text("Permanently deletes your account and everything in it — meals, symptoms, skin logs, blood work, photos and Dine Codes. This can't be undone.")
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
            .confirmationDialog("Delete your account?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Delete account and all data", role: .destructive) {
                    Task {
                        isDeleting = true
                        let deleted = await app.deleteAccount()
                        isDeleting = false
                        if deleted { dismiss() }
                    }
                }
            } message: {
                Text("Everything you've logged will be erased from this device and from Nouri's servers. Any Dine Code you've shared will stop working.")
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

    private static var versionString: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "–"
        let build = info?["CFBundleVersion"] as? String ?? "–"
        return "\(version) (\(build))"
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
