import SwiftUI
import PhotosUI

/// Photograph a product's ingredient list (or a clothing care label) → Claude transcribes it →
/// the user checks it, sees flagged contact allergens, and adds the product to today's skin log.
struct LabelScanView: View {
    @EnvironmentObject private var app: AppState
    @Environment(\.dismiss) private var dismiss

    var initialKind: SkinExposureKind = .product
    var onAdd: (SkinExposure) -> Void

    @State private var stage: Stage = .capture
    @State private var photo: UIImage?
    @State private var showCamera = false
    @State private var libraryItem: PhotosPickerItem?
    @State private var name = ""
    @State private var kind: SkinExposureKind = .product
    @State private var ingredients: [String] = []
    @State private var percentages: [String: Double] = [:]
    @State private var readerNotes = ""
    @State private var newIngredient = ""

    enum Stage: Equatable { case capture, reading, review, failed(String) }

    var body: some View {
        NavigationStack {
            Group {
                switch stage {
                case .capture: captureView
                case .reading: readingView
                case .review: reviewView
                case .failed(let message): failedView(message)
                }
            }
            .nouriScreenBackground()
            .navigationTitle("Scan a label")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraPicker { read($0) }.ignoresSafeArea()
        }
        .onChange(of: libraryItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self), let image = UIImage(data: data) { read(image) }
            }
        }
        .onAppear { kind = initialKind }
    }

    // MARK: Stages

    private var captureView: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "text.viewfinder")
                .font(.system(size: 60))
                .foregroundStyle(Color.nouriPrimary)
            Text("Photograph the ingredients").nouriHeading(.title2)
            Text("The back of the bottle or tube, or the care label inside clothing. Nouri reads it and flags common skin irritants like fragrance, preservatives, lanolin and wool.")
                .multilineTextAlignment(.center)
                .foregroundStyle(Color.nouriTextSecondary)
            Spacer()
            Button { showCamera = true } label: { Label("Take photo", systemImage: "camera.fill") }
                .buttonStyle(.nouriPrimary)
            PhotosPicker(selection: $libraryItem, matching: .images) {
                Label("Choose from library", systemImage: "photo.on.rectangle")
            }
            .buttonStyle(.nouriSecondary)
            Button("Type ingredients instead") { stage = .review }
                .font(.footnote)
                .foregroundStyle(Color.nouriTextSecondary)
        }
        .padding(24)
    }

    private var readingView: some View {
        VStack(spacing: 20) {
            if let photo {
                Image(uiImage: photo).resizable().scaledToFill()
                    .frame(height: 240)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            }
            ProgressView()
            Text("Reading the label…").foregroundStyle(Color.nouriTextSecondary)
        }
        .padding(24)
    }

    private func failedView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle").font(.largeTitle).foregroundStyle(Color.nouriWarning)
            Text("Couldn't read the label").nouriHeading(.title3)
            Text(message).font(.footnote).multilineTextAlignment(.center).foregroundStyle(Color.nouriTextSecondary)
            Button("Try another photo") { stage = .capture }.buttonStyle(.nouriPrimary)
            Button("Type ingredients instead") { stage = .review }.buttonStyle(.nouriSecondary)
        }
        .padding(24)
    }

    private var reviewView: some View {
        Form {
            Section {
                TextField("Product name (e.g. Brand X body lotion)", text: $name)
                Picker("Type", selection: $kind) {
                    ForEach(SkinExposureKind.allCases) { Text($0.label).tag($0) }
                }
            } footer: {
                if !readerNotes.isEmpty { Text(readerNotes) }
            }

            let flagged = currentLabel.flagged
            if !flagged.isEmpty {
                Section("Flagged") {
                    ForEach(flagged) { item in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(item.group.label).font(.headline)
                                Spacer()
                                if likelyGroups.contains(item.group) {
                                    Tag(text: "Your likely trigger", color: .nouriDanger)
                                }
                            }
                            Text(item.ingredients.joined(separator: ", "))
                                .font(.caption)
                                .foregroundStyle(Color.nouriTextSecondary)
                        }
                    }
                }
            }

            Section {
                ForEach(ingredients, id: \.self) { ingredient in
                    HStack {
                        Text(ingredient)
                        if let percent = percentages[ingredient] {
                            Text("\(percent.formatted(.number.precision(.fractionLength(0...1))))%")
                                .foregroundStyle(Color.nouriTextSecondary)
                        }
                        Spacer()
                        if !ContactAllergenDatabase.groups(for: ingredient).isEmpty {
                            Image(systemName: "exclamationmark.circle.fill").foregroundStyle(Color.nouriWarning)
                                .accessibilityLabel("Flagged")
                        }
                    }
                }
                .onDelete { ingredients.remove(atOffsets: $0) }
                HStack {
                    TextField("Add ingredient", text: $newIngredient)
                        .submitLabel(.done)
                        .onSubmit(addIngredient)
                    Button("Add", action: addIngredient)
                        .disabled(newIngredient.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            } header: {
                Text(kind == .fabric ? "Fibres" : "Ingredients (\(ingredients.count))")
            } footer: {
                Text("Check the list against the label and fix anything misread. Swipe to delete.")
            }

            Section {
                Button("Add to today's log", action: add)
                    .buttonStyle(.nouriPrimary)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
            }
        }
        .scrollContentBackground(.hidden)
    }

    // MARK: Logic

    private var currentLabel: ProductLabel {
        ProductLabel(productName: name, kind: kind, ingredients: ingredients, percentages: percentages, notes: readerNotes)
    }

    private var likelyGroups: Set<ContactAllergenGroup> {
        Set((app.profile?.likelySkinGroups ?? []).compactMap(\.contactGroup))
    }

    private func read(_ image: UIImage) {
        photo = image
        stage = .reading
        Task {
            do {
                let label = try await app.readLabel(photo: image)
                name = label.productName
                kind = label.kind
                ingredients = label.ingredients
                percentages = label.percentages
                readerNotes = label.notes
                stage = .review
            } catch {
                stage = .failed(error.localizedDescription)
            }
        }
    }

    private func addIngredient() {
        let value = newIngredient.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty, !ingredients.contains(where: { $0.caseInsensitiveCompare(value) == .orderedSame }) else { return }
        ingredients.append(value)
        newIngredient = ""
    }

    private func add() {
        let productName = name.trimmingCharacters(in: .whitespacesAndNewlines).capitalizedFirst
        onAdd(SkinExposure(name: productName, kind: kind, ingredients: ingredients.isEmpty ? nil : ingredients))
        dismiss()
    }
}
