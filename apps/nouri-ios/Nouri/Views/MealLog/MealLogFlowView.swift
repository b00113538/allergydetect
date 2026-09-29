import SwiftUI
import PhotosUI

/// Camera → Claude vision → confirm/edit ingredients → save.
struct MealLogFlowView: View {
    @EnvironmentObject private var app: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var stage: Stage = .capture
    @State private var photo: UIImage?
    @State private var showCamera = false
    @State private var libraryItem: PhotosPickerItem?
    @State private var draft = MealDraft()

    enum Stage: Equatable { case capture, analyzing, confirm, failed(String) }

    var body: some View {
        NavigationStack {
            Group {
                switch stage {
                case .capture: captureView
                case .analyzing: analyzingView
                case .confirm: IngredientConfirmView(photo: photo, draft: $draft, onSave: save)
                case .failed(let message): failedView(message)
                }
            }
            .nouriScreenBackground()
            .navigationTitle("Log a meal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraPicker { analyze($0) }.ignoresSafeArea()
        }
        .onChange(of: libraryItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self), let image = UIImage(data: data) {
                    analyze(image)
                }
            }
        }
    }

    private var captureView: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "camera.macro")
                .font(.system(size: 64))
                .foregroundStyle(Color.nouriPrimary)
            Text("Photograph your meal").nouriHeading(.title2)
            Text("Nouri identifies likely ingredients and flags common allergens. You can edit everything before saving.")
                .multilineTextAlignment(.center)
                .foregroundStyle(Color.nouriTextSecondary)
            Spacer()
            Button { showCamera = true } label: { Label("Take photo", systemImage: "camera.fill") }
                .buttonStyle(.nouriPrimary)
            PhotosPicker(selection: $libraryItem, matching: .images) {
                Label("Choose from library", systemImage: "photo.on.rectangle")
            }
            .buttonStyle(.nouriSecondary)
            Button("Log without a photo") {
                draft = MealDraft()
                stage = .confirm
            }
            .font(.footnote)
            .foregroundStyle(Color.nouriTextSecondary)
        }
        .padding(24)
    }

    private var analyzingView: some View {
        VStack(spacing: 20) {
            if let photo {
                Image(uiImage: photo)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 260)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            }
            ProgressView()
            Text("Identifying ingredients…").foregroundStyle(Color.nouriTextSecondary)
        }
        .padding(24)
    }

    private func failedView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle").font(.largeTitle).foregroundStyle(Color.nouriWarning)
            Text("Couldn't analyse the photo").nouriHeading(.title3)
            Text(message).font(.footnote).multilineTextAlignment(.center).foregroundStyle(Color.nouriTextSecondary)
            Button("Try again") { if let photo { analyze(photo) } }.buttonStyle(.nouriPrimary)
            Button("Enter ingredients manually") {
                draft = MealDraft()
                stage = .confirm
            }
            .buttonStyle(.nouriSecondary)
        }
        .padding(24)
    }

    private func analyze(_ image: UIImage) {
        photo = image
        stage = .analyzing
        Task {
            do {
                let analysis = try await app.analyze(photo: image)
                draft = MealDraft(dishName: analysis.dishName, ingredients: analysis.ingredients)
                stage = .confirm
            } catch {
                stage = .failed(error.localizedDescription)
            }
        }
    }

    private func save() {
        app.logMeal(photo: photo, dishName: draft.dishName.isEmpty ? nil : draft.dishName,
                    ingredients: draft.ingredients, mealType: draft.mealType, notes: draft.notes, timestamp: draft.timestamp)
        dismiss()
    }
}

struct MealDraft {
    var dishName = ""
    var ingredients: [Ingredient] = []
    var mealType = MealType.suggested()
    var notes = ""
    var timestamp = Date.now
}
