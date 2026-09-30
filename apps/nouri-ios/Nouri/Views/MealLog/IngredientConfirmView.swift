import SwiftUI

struct IngredientConfirmView: View {
    @EnvironmentObject private var app: AppState
    let photo: UIImage?
    @Binding var draft: MealDraft
    var onSave: () -> Void

    @State private var newIngredient = ""
    @FocusState private var addFieldFocused: Bool

    var body: some View {
        Form {
            if let photo {
                Section {
                    Image(uiImage: photo)
                        .resizable()
                        .scaledToFill()
                        .frame(height: 200)
                        .clipped()
                        .listRowInsets(EdgeInsets())
                }
            }

            if !conflicts.isEmpty {
                Section {
                    Label {
                        Text("Contains \(conflicts.map(\.label).joined(separator: ", ")) — on your known allergy list.")
                    } icon: {
                        Image(systemName: "exclamationmark.octagon.fill").foregroundStyle(Color.nouriDanger)
                    }
                    .font(.subheadline.weight(.semibold))
                }
            }

            Section("Meal") {
                TextField("Dish name", text: $draft.dishName)
                Picker("Type", selection: $draft.mealType) {
                    ForEach(MealType.allCases) { Label($0.label, systemImage: $0.symbol).tag($0) }
                }
                DatePicker("Eaten at", selection: $draft.timestamp, in: ...Date.now)
            }

            Section {
                ForEach(draft.ingredients) { ingredient in
                    IngredientRow(ingredient: ingredient)
                }
                .onDelete { draft.ingredients.remove(atOffsets: $0) }

                HStack {
                    TextField("Add ingredient", text: $newIngredient)
                        .focused($addFieldFocused)
                        .submitLabel(.done)
                        .onSubmit(addIngredient)
                    Button(action: addIngredient) { Image(systemName: "plus.circle.fill") }
                        .disabled(newIngredient.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            } header: {
                Text("Ingredients")
            } footer: {
                Text("Swipe to remove anything that's wrong, and add anything the photo can't show (sauces, oils, marinades).")
            }

            Section("Notes") {
                TextField("Restaurant, portion, anything unusual…", text: $draft.notes, axis: .vertical)
            }

            Section {
                Button("Save meal", action: onSave)
                    .buttonStyle(.nouriPrimary)
                    .disabled(draft.ingredients.isEmpty)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
            }
        }
        .scrollContentBackground(.hidden)
    }

    private var conflicts: [AllergenGroup] {
        AllergenDatabase.conflicts(in: draft.ingredients, knownConditions: app.user?.knownConditions ?? [])
    }

    private func addIngredient() {
        let name = newIngredient.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        let ingredient = AllergenDatabase.annotate(Ingredient(name: name.capitalizedFirst, confidence: 1, source: .user))
        if !draft.ingredients.contains(where: { $0.id == ingredient.id }) {
            draft.ingredients.append(ingredient)
        }
        newIngredient = ""
        addFieldFocused = true
    }
}

struct IngredientRow: View {
    let ingredient: Ingredient

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(ingredient.name)
                if ingredient.isHighRisk {
                    HStack(spacing: 4) {
                        ForEach(ingredient.allergenGroups) { Tag(text: $0.label, color: .nouriDanger) }
                    }
                }
            }
            Spacer()
            if ingredient.source == .ai {
                Text(ingredient.confidence.percentString)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(ingredient.confidence >= 0.7 ? Color.nouriTextSecondary : Color.nouriWarning)
                    .accessibilityLabel("AI confidence \(ingredient.confidence.percentString)")
            } else {
                Image(systemName: "person.fill.checkmark").font(.caption).foregroundStyle(Color.nouriTextSecondary)
            }
        }
    }
}
