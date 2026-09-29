import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var app: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var knownGroups: Set<AllergenGroup> = []
    @State private var otherConditions = ""
    @State private var confirmSignOut = false

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
                    app.signOut()
                }
            }
            .onAppear(perform: loadConditions)
        }
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
