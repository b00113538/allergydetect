import SwiftUI

struct SkinLogDetailView: View {
    @EnvironmentObject private var app: AppState
    @Environment(\.dismiss) private var dismiss
    let log: SkinLog
    @State private var confirmDelete = false

    var body: some View {
        List {
            if let image = log.localPhotoName.flatMap(PhotoStore.image(named:)) {
                Section {
                    Image(uiImage: image).resizable().scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            } else if let url = log.photoURL.flatMap(URL.init(string:)) {
                Section {
                    AsyncImage(url: url) { $0.resizable().scaledToFit() } placeholder: { ProgressView() }
                }
            }
            Section("Reaction") {
                LabeledContent("Skin", value: log.reactions.map(\.label).joined(separator: ", "))
                if log.isReaction {
                    LabeledContent("Severity", value: "\(log.severity) / 5")
                    if !log.bodyAreas.isEmpty {
                        LabeledContent("Where", value: log.bodyAreas.map(\.label).joined(separator: ", "))
                    }
                }
                LabeledContent("When", value: log.timestamp.formatted(date: .abbreviated, time: .shortened))
            }
            Section("Exposed to") {
                if log.exposures.isEmpty { Text("Nothing listed").foregroundStyle(Color.nouriTextSecondary) }
                ForEach(log.exposures) { exposure in
                    Label(exposure.name, systemImage: exposure.kind.symbol)
                        .badge(exposure.kind.label)
                }
            }
            if !log.notes.isEmpty {
                Section("Notes") { Text(log.notes) }
            }
            Section {
                Button("Delete log", role: .destructive) { confirmDelete = true }
            }
        }
        .scrollContentBackground(.hidden)
        .nouriScreenBackground()
        .navigationTitle(log.isReaction ? "Skin reaction" : "Skin check-in")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("Delete this log?", isPresented: $confirmDelete) {
            Button("Delete", role: .destructive) {
                app.deleteSkinLog(log)
                dismiss()
            }
        }
    }
}

struct SkinLogRow: View {
    let log: SkinLog

    private var tint: Color { log.isReaction ? log.severity.severityColor : .nouriSuccess }

    var body: some View {
        HStack(spacing: 12) {
            Group {
                if let image = log.localPhotoName.flatMap(PhotoStore.image(named:)) {
                    Image(uiImage: image).resizable().scaledToFill()
                } else {
                    Image(systemName: log.isReaction ? "allergens" : "checkmark.circle")
                        .font(.title3)
                        .foregroundStyle(tint)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(tint.opacity(0.14))
                }
            }
            .frame(width: 52, height: 52)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                Text(log.isReaction ? log.reactions.map(\.label).joined(separator: ", ") : "Skin fine")
                    .font(.headline)
                    .foregroundStyle(Color.nouriTextPrimary)
                Text(([log.isReaction ? "Severity \(log.severity)/5" : nil, log.timestamp.timeString, log.title] as [String?])
                    .compactMap { $0 }.joined(separator: " · "))
                    .font(.caption)
                    .foregroundStyle(Color.nouriTextSecondary)
                    .lineLimit(2)
            }
            Spacer()
        }
        .padding(12)
        .background(Color.nouriSurface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
