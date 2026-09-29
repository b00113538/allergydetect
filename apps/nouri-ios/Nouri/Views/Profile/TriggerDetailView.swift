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
                    LabeledContent("Meals containing it", value: "\(trigger.exposures)")
                    LabeledContent("Followed by symptoms", value: "\(trigger.reactions)")
                    LabeledContent("Reaction rate", value: trigger.reactionRate.percentString)
                    LabeledContent("Your rate after other meals", value: trigger.baselineRate?.percentString ?? "Not enough data")
                    if trigger.reactions > 0 {
                        LabeledContent("Average severity", value: String(format: "%.1f / 5", trigger.averageSeverity))
                    }
                }
                if !trigger.allergenGroups.isEmpty {
                    Section("Allergen group") {
                        Text(trigger.allergenGroups.map(\.label).joined(separator: ", "))
                    }
                }
                Section("Recent meals with it") {
                    ForEach(matchingMeals.prefix(8)) { MealRow(meal: $0).listRowInsets(EdgeInsets()) }
                }
                Section {
                    Text("Correlation isn't proof. If a likely trigger is affecting you, a clinician can confirm it with an allergy panel or supervised elimination.")
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
