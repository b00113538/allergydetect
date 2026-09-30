import SwiftUI
import PhotosUI

/// Log what touched your skin (products, fabrics, materials) and how it reacted — or didn't.
struct SkinLogView: View {
    @EnvironmentObject private var app: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var photo: UIImage?
    @State private var showCamera = false
    @State private var libraryItem: PhotosPickerItem?
    @State private var exposures: [SkinExposure] = []
    @State private var kind: SkinExposureKind = .fabric
    @State private var newName = ""
    @State private var reactions: Set<SkinReaction> = []
    @State private var bodyAreas: Set<BodyArea> = []
    @State private var severity = 2
    @State private var timestamp = Date.now
    @State private var notes = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    exposureCard
                    reactionCard
                    if isReaction { detailCard }
                    photoCard
                    NouriCard {
                        DatePicker("When", selection: $timestamp, in: ...Date.now)
                        TextField("Notes (optional)", text: $notes, axis: .vertical).lineLimit(2...5)
                    }
                    Button("Save", action: save)
                        .buttonStyle(.nouriPrimary)
                        .disabled(!canSave)
                }
                .padding(20)
            }
            .nouriScreenBackground()
            .navigationTitle("Log skin")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
            .fullScreenCover(isPresented: $showCamera) {
                CameraPicker { photo = $0 }.ignoresSafeArea()
            }
            .onChange(of: libraryItem) { _, item in
                guard let item else { return }
                Task {
                    if let data = try? await item.loadTransferable(type: Data.self), let image = UIImage(data: data) {
                        photo = image
                    }
                }
            }
        }
    }

    // MARK: Sections

    private var exposureCard: some View {
        NouriCard {
            Text("What touched your skin?").font(NouriFont.section).foregroundStyle(Color.nouriTextPrimary)
            Text("Today's products, clothes and materials — including the ones you use every day. Logging days without a reaction is what lets Nouri tell a real trigger apart.")
                .font(.footnote)
                .foregroundStyle(Color.nouriTextSecondary)
            if !exposures.isEmpty {
                FlowLayout {
                    ForEach(exposures) { exposure in
                        Chip(title: exposure.name, systemImage: "xmark", isSelected: true) {
                            exposures.removeAll { $0.id == exposure.id }
                        }
                        .accessibilityHint("Removes it")
                    }
                }
            }
            Picker("Type", selection: $kind) {
                ForEach(SkinExposureKind.allCases) { Label($0.label, systemImage: $0.symbol).tag($0) }
            }
            .pickerStyle(.segmented)
            HStack {
                TextField(placeholder, text: $newName)
                    .textInputAutocapitalization(.sentences)
                    .submitLabel(.done)
                    .onSubmit(addTyped)
                Button("Add", action: addTyped)
                    .disabled(newName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(12)
            .background(Color.nouriSurfaceMuted, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            FlowLayout {
                ForEach(suggestions, id: \.self) { name in
                    Chip(title: name, systemImage: "plus", isSelected: false) {
                        add(SkinExposure(name: name, kind: kind))
                    }
                }
            }
        }
    }

    private var reactionCard: some View {
        NouriCard {
            Text("How is your skin?").font(NouriFont.section).foregroundStyle(Color.nouriTextPrimary)
            FlowLayout {
                ForEach(SkinReaction.allCases) { reaction in
                    Chip(title: reaction.label, systemImage: reaction.symbol, isSelected: reactions.contains(reaction),
                         tint: reaction == .none ? .nouriSuccess : .nouriPrimary) {
                        toggle(reaction)
                    }
                }
            }
        }
    }

    private var detailCard: some View {
        NouriCard {
            Text("Where?").font(NouriFont.section).foregroundStyle(Color.nouriTextPrimary)
            FlowLayout {
                ForEach(BodyArea.allCases) { area in
                    Chip(title: area.label, isSelected: bodyAreas.contains(area)) {
                        bodyAreas.formSymmetricDifference([area])
                    }
                }
            }
            HStack {
                Text("Severity").font(NouriFont.label).foregroundStyle(Color.nouriTextPrimary)
                Spacer()
                Text(["Very mild", "Mild", "Moderate", "Strong", "Severe"][severity - 1])
                    .font(.subheadline)
                    .foregroundStyle(severity.severityColor)
            }
            SeverityPicker(severity: $severity)
        }
    }

    private var photoCard: some View {
        NouriCard {
            Text("Photo").font(NouriFont.section).foregroundStyle(Color.nouriTextPrimary)
            Text("Optional — a photo makes it easier to compare flare-ups over time.")
                .font(.footnote)
                .foregroundStyle(Color.nouriTextSecondary)
            if let photo {
                ZStack(alignment: .topTrailing) {
                    Image(uiImage: photo)
                        .resizable()
                        .scaledToFill()
                        .frame(height: 200)
                        .frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    Button { self.photo = nil } label: {
                        Image(systemName: "xmark.circle.fill").font(.title2).symbolRenderingMode(.hierarchical)
                    }
                    .padding(8)
                    .accessibilityLabel("Remove photo")
                }
            } else {
                HStack(spacing: 12) {
                    Button { showCamera = true } label: { Label("Camera", systemImage: "camera") }
                        .buttonStyle(.nouriSecondary)
                    PhotosPicker(selection: $libraryItem, matching: .images) {
                        Label("Library", systemImage: "photo")
                    }
                    .buttonStyle(.nouriSecondary)
                }
            }
        }
    }

    // MARK: Logic

    private var isReaction: Bool { reactions.contains { $0 != .none } }

    /// A clean day with nothing listed carries no information, so it needs at least one exposure.
    private var canSave: Bool { !reactions.isEmpty && (isReaction || !exposures.isEmpty) }

    private var placeholder: String {
        switch kind {
        case .product: "e.g. Brand X moisturiser"
        case .fabric: "e.g. Wool jumper"
        case .material: "e.g. Nickel earrings"
        }
    }

    /// The user's own history for this type first, then generic quick picks.
    private var suggestions: [String] {
        let added = Set(exposures.map(\.id))
        let history = app.recentSkinExposures().filter { $0.kind == kind }.map(\.name)
        var seen = Set<String>()
        return (history + kind.suggestions).filter { name in
            let id = SkinExposure(name: name, kind: kind).id
            return !added.contains(id) && seen.insert(id).inserted
        }
        .prefix(10)
        .map { $0 }
    }

    private func addTyped() {
        let name = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        add(SkinExposure(name: name.capitalizedFirst, kind: kind))
        newName = ""
    }

    private func add(_ exposure: SkinExposure) {
        guard !exposures.contains(where: { $0.id == exposure.id }) else { return }
        exposures.append(exposure)
    }

    /// "No reaction" is mutually exclusive with actual reactions.
    private func toggle(_ reaction: SkinReaction) {
        if reaction == .none {
            reactions = reactions.contains(.none) ? [] : [.none]
            bodyAreas = []
        } else {
            reactions.remove(.none)
            reactions.formSymmetricDifference([reaction])
        }
    }

    private func save() {
        app.logSkin(photo: photo, exposures: exposures, reactions: SkinReaction.allCases.filter(reactions.contains),
                    bodyAreas: BodyArea.allCases.filter(bodyAreas.contains), severity: isReaction ? severity : 1,
                    notes: notes, timestamp: timestamp)
        dismiss()
    }
}
