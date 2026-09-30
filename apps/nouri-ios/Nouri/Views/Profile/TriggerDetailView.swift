import SwiftUI

/// Explains a single score in plain numbers — the "why" behind the confidence.
struct TriggerDetailView: View {
    @EnvironmentObject private var app: AppState
    @Environment(\.dismiss) private var dismiss
    let trigger: TriggerIngredient

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 10) {
                        Tag(text: trigger.status.label, color: trigger.status.color)
                        Text("\(trigger.confidence.percentString) confidence").nouriHeading(.title)
                        ConfidenceBar(value: trigger.confidence, tint: trigger.status.color)
                    }
                    .padding(.vertical, 6)
                }
                Section("The numbers") {
                    LabeledContent(isSkin ? "Logs with it" : "Meals containing it", value: "\(trigger.exposures)")
                    LabeledContent(isSkin ? "With a skin reaction" : "Followed by symptoms", value: "\(trigger.reactions)")
                    LabeledContent("Reaction rate", value: trigger.reactionRate.percentString)
                    LabeledContent(isSkin ? "Your rate on other days" : "Your rate after other meals",
                                   value: trigger.baselineRate?.percentString ?? "Not enough data")
                    if trigger.reactions > 0 {
                        LabeledContent("Average severity", value: String(format: "%.1f / 5", trigger.averageSeverity))
                    }
                }
                if !trigger.allergenGroups.isEmpty {
                    Section("Allergen group") {
                        Text(trigger.allergenGroups.map(\.label).joined(separator: ", "))
                    }
                }
                if isSkin {
                    Section("Recent logs with it") {
                        ForEach(matchingSkinLogs.prefix(8)) { SkinLogRow(log: $0).listRowInsets(EdgeInsets()) }
                    }
                } else {
                    Section("Recent meals with it") {
                        ForEach(matchingMeals.prefix(8)) { MealRow(meal: $0).listRowInsets(EdgeInsets()) }
                    }
                }
                Section {
                    Text(isSkin
                         ? "Correlation isn't proof. For suspected contact allergies, a dermatologist can confirm triggers with patch testing."
                         : "Correlation isn't proof. If a likely trigger is affecting you, a clinician can confirm it with an allergy panel or supervised elimination.")
                        .font(.footnote)
                        .foregroundStyle(Color.nouriTextSecondary)
                }
            }
            .scrollContentBackground(.hidden)
            .nouriScreenBackground()
            .navigationTitle(trigger.ingredient.capitalizedFirst)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }

    private var isSkin: Bool { trigger.domain != .food }

    private var matchingSkinLogs: [SkinLog] {
        let key = IngredientNormalizer.canonicalKey(trigger.ingredient)
        return app.skinLogs.filter { log in
            log.exposures.contains { $0.kind.domain == trigger.domain && IngredientNormalizer.canonicalKey($0.name) == key }
        }
    }

    private var matchingMeals: [MealEntry] {
        let key = IngredientNormalizer.canonicalKey(trigger.ingredient)
        let group = AllergenGroup.allCases.first { $0.label == trigger.ingredient }
        return app.meals.filter { meal in
            meal.ingredients.contains { ingredient in
                if let group { return ingredient.allergenGroups.contains(group) }
                return IngredientNormalizer.canonicalKey(ingredient.name) == key
            }
        }
    }
}
