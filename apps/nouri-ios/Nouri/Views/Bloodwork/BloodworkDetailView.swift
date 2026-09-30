import SwiftUI
import PDFKit

struct BloodworkDetailView: View {
    @EnvironmentObject private var app: AppState
    @Environment(\.dismiss) private var dismiss
    let record: BloodworkRecord
    @State private var confirmDelete = false

    var body: some View {
        List {
            Section {
                LabeledContent("Test date", value: record.testDate.formatted(date: .long, time: .omitted))
                if let lab = record.labName { LabeledContent("Lab", value: lab) }
                if record.localDocName != nil || record.sourceDocURL != nil {
                    NavigationLink("View original report") { ReportDocumentView(record: record) }
                }
            }
            Section("Results") {
                ForEach(record.panelResults.sorted { $0.igeLevel > $1.igeLevel }, id: \.self) { result in
                    PanelResultRow(result: result)
                }
            }
            if !record.notes.isEmpty {
                Section("Notes") { Text(record.notes) }
            }
            Section {
                Text("Sensitisation (class 1+) shows your immune system recognises an allergen; it doesn't on its own confirm an allergy. Go through results with a clinician.")
                    .font(.footnote)
                    .foregroundStyle(Color.nouriTextSecondary)
            }
            Section {
                Button("Delete results", role: .destructive) { confirmDelete = true }
            }
        }
        .scrollContentBackground(.hidden)
        .nouriScreenBackground()
        .navigationTitle("Allergy panel")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("Delete these results and the uploaded report?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                app.deleteBloodwork(record)
                dismiss()
            }
        }
    }
}

struct PanelResultRow: View {
    let result: BloodworkRecord.PanelResult

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(result.allergen).font(.headline).foregroundStyle(Color.nouriTextPrimary)
                Text(result.levelString).font(.caption).foregroundStyle(Color.nouriTextSecondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 3) {
                Tag(text: "Class \(result.effectiveClass)", color: result.effectiveClass.igeClassColor)
                Text(IgEScale.label(forClass: result.effectiveClass)).font(.caption2).foregroundStyle(Color.nouriTextSecondary)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

/// The on-device copy when there is one, otherwise the uploaded file.
private struct ReportDocumentView: View {
    let record: BloodworkRecord

    var body: some View {
        Group {
            if record.sourceDocType == .pdf, let url = localURL ?? remoteURL {
                PDFKitView(url: url)
            } else if let name = record.localDocName, let image = UIImage(contentsOfFile: DocumentStore.url(named: name).path) {
                ScrollView([.horizontal, .vertical]) { Image(uiImage: image) }
            } else if let url = remoteURL {
                AsyncImage(url: url) { $0.resizable().scaledToFit() } placeholder: { ProgressView() }
            } else {
                ContentUnavailableView("Report unavailable", systemImage: "doc.questionmark")
            }
        }
        .navigationTitle("Report")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var localURL: URL? {
        guard let name = record.localDocName else { return nil }
        let url = DocumentStore.url(named: name)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    private var remoteURL: URL? { record.sourceDocURL.flatMap(URL.init(string:)) }
}

private struct PDFKitView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        if url.isFileURL {
            view.document = PDFDocument(url: url)
        } else {
            // Remote copy (another device uploaded it): download off the main thread.
            Task {
                if let data = try? await URLSession.shared.data(from: url).0 { view.document = PDFDocument(data: data) }
            }
        }
        return view
    }

    func updateUIView(_ uiView: PDFView, context: Context) {}
}
