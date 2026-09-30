import SwiftUI

struct SymptomLogView: View {
    @EnvironmentObject private var app: AppState
    @Environment(\.dismiss) private var dismiss

    var preselectedMealId: String?

    @State private var selected: Set<SymptomType> = []
    @State private var severity = 2
    @State private var mealId: String?
    @State private var timestamp = Date.now
    @State private var notes = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    NouriCard {
                        Text("What are you feeling?").font(NouriFont.section).foregroundStyle(Color.nouriTextPrimary)
                        FlowLayout {
                            ForEach(SymptomType.allCases) { symptom in
                                Chip(title: symptom.label, systemImage: symptom.symbol, isSelected: selected.contains(symptom),
                                     tint: symptom == .none ? .nouriSuccess : .nouriPrimaryText) {
                                    toggle(symptom)
                                }
                            }
                        }
                    }

                    if isReaction {
                        NouriCard {
                            HStack {
                                Text("Severity").font(NouriFont.section).foregroundStyle(Color.nouriTextPrimary)
                                Spacer()
                                Text(severityLabel).font(.subheadline).foregroundStyle(severity.severityColor)
                            }
                            SeverityPicker(severity: $severity)
                        }
                    }

                    NouriCard {
                        Text("Link to a meal").font(NouriFont.section).foregroundStyle(Color.nouriTextPrimary)
                        Text("Optional — if you skip this, Nouri matches meals eaten in the 8 hours before.")
                            .font(.footnote)
                            .foregroundStyle(Color.nouriTextSecondary)
                        Picker("Meal", selection: $mealId) {
                            Text("Not sure / none").tag(String?.none)
                            ForEach(candidateMeals) { meal in
                                Text("\(meal.title) · \(meal.timestamp.timeString)").tag(Optional(meal.id))
                            }
                        }
                        .pickerStyle(.menu)
                        DatePicker("When", selection: $timestamp, in: ...Date.now)
                    }

                    NouriCard {
                        TextField("Notes (optional)", text: $notes, axis: .vertical).lineLimit(2...5)
                    }

                    Button("Save", action: save)
                        .buttonStyle(.nouriPrimary)
                        .disabled(selected.isEmpty)
                }
                .padding(20)
            }
            .nouriScreenBackground()
            .navigationTitle("Log symptom")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
            .onAppear { mealId = preselectedMealId }
        }
    }

    private var isReaction: Bool { selected.contains { $0 != .none } }

    private var candidateMeals: [MealEntry] {
        var meals = app.recentMeals(within: 24)
        if let preselectedMealId, !meals.contains(where: { $0.id == preselectedMealId }),
           let meal = app.meals.first(where: { $0.id == preselectedMealId }) {
            meals.insert(meal, at: 0)
        }
        return meals
    }

    private var severityLabel: String {
        ["Very mild", "Mild", "Moderate", "Strong", "Severe"][severity - 1]
    }

    /// "No symptoms" is mutually exclusive with actual symptoms.
    private func toggle(_ symptom: SymptomType) {
        if symptom == .none {
            selected = selected.contains(.none) ? [] : [.none]
        } else {
            selected.remove(.none)
            selected.formSymmetricDifference([symptom])
        }
    }

    private func save() {
        let types = SymptomType.allCases.filter(selected.contains)
        app.logSymptom(types: types, severity: isReaction ? severity : 1, mealEntryId: mealId, notes: notes, timestamp: timestamp)
        dismiss()
    }
}
