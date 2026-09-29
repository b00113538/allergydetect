import SwiftUI

struct MealDetailView: View {
    @EnvironmentObject private var app: AppState
    @Environment(\.dismiss) private var dismiss
    let meal: MealEntry
    @State private var confirmDelete = false

    var body: some View {
        List {
            Section {
                MealThumbnail(meal: meal, size: 220)
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
            }
            Section {
                LabeledContent("Type", value: meal.mealType.label)
                LabeledContent("Eaten", value: meal.timestamp.formatted(date: .abbreviated, time: .shortened))
                if !meal.userNotes.isEmpty { Text(meal.userNotes) }
            }
            Section("Ingredients") {
                ForEach(meal.ingredients) { IngredientRow(ingredient: $0) }
            }
            Section("Symptoms after this meal") {
                let related = relatedSymptoms
                if related.isEmpty {
                    Text("None logged").foregroundStyle(Color.nouriTextSecondary)
                } else {
                    ForEach(related) { SymptomRow(log: $0, meal: nil).listRowInsets(EdgeInsets()) }
                }
            }
            Section {
                Button("Delete meal", role: .destructive) { confirmDelete = true }
            }
        }
        .scrollContentBackground(.hidden)
        .nouriScreenBackground()
        .navigationTitle(meal.title)
        .confirmationDialog("Delete this meal?", isPresented: $confirmDelete) {
            Button("Delete", role: .destructive) {
                app.deleteMeal(meal)
                dismiss()
            }
        }
    }

    private var relatedSymptoms: [SymptomLog] {
        app.symptoms.filter { log in
            if let id = log.mealEntryId { return id == meal.id }
            let delta = log.timestamp.timeIntervalSince(meal.timestamp)
            return delta >= 0 && delta <= 8 * 3600
        }
        .sorted { $0.timestamp < $1.timestamp }
    }
}
