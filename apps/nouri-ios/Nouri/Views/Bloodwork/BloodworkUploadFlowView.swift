import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

/// Scan / photo / PDF → Claude reads the panel → user reviews every row → save.
struct BloodworkUploadFlowView: View {
    @EnvironmentObject private var app: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var stage: Stage = .pick
    @State private var document: (data: Data, type: BloodworkRecord.DocumentType)?
    @State private var showScanner = false
    @State private var showCamera = false
    @State private var showFileImporter = false
    @State private var libraryItem: PhotosPickerItem?
    @State private var draft = BloodworkDraft()

    enum Stage: Equatable { case pick, reading, review, failed(String) }

    var body: some View {
        NavigationStack {
            Group {
                switch stage {
                case .pick: pickView
                case .reading: readingView
                case .review: BloodworkReviewView(draft: $draft, hasDocument: document != nil, onSave: save)
                case .failed(let message): failedView(message)
                }
            }
            .nouriScreenBackground()
            .navigationTitle("Add blood work")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
        }
        .fullScreenCover(isPresented: $showScanner) {
            DocumentScanner { pages in
                guard !pages.isEmpty else { return }
                read(ReportDocument.pdf(from: pages), type: .pdf)
            }
            .ignoresSafeArea()
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraPicker { image in
                if let data = image.nouriJPEGData(quality: 0.85) { read(data, type: .jpeg) }
            }
            .ignoresSafeArea()
        }
        .fileImporter(isPresented: $showFileImporter, allowedContentTypes: [.pdf, .image]) { result in
            guard case .success(let url) = result else { return }
            importFile(at: url)
        }
        .onChange(of: libraryItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self), let image = UIImage(data: data),
                   let jpeg = image.nouriJPEGData(quality: 0.85) {
                    read(jpeg, type: .jpeg)
                }
            }
        }
    }

    private var pickView: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "testtube.2")
                .font(.system(size: 60))
                .foregroundStyle(Color.nouriPrimary)
            Text("Add allergy test results").nouriHeading(.title2)
            Text("Scan or upload a specific IgE (allergy) blood test. Nouri reads the results for you to check, then compares them with the patterns in your logs.")
                .multilineTextAlignment(.center)
                .foregroundStyle(Color.nouriTextSecondary)
            Spacer()
            Button {
                if DocumentScanner.isSupported { showScanner = true } else { showCamera = true }
            } label: {
                Label("Scan paper report", systemImage: "doc.viewfinder")
            }
            .buttonStyle(.nouriPrimary)
            Button { showFileImporter = true } label: { Label("Upload PDF", systemImage: "doc.richtext") }
                .buttonStyle(.nouriSecondary)
            PhotosPicker(selection: $libraryItem, matching: .images) {
                Label("Choose photo", systemImage: "photo.on.rectangle")
            }
            .buttonStyle(.nouriSecondary)
            Button("Enter results manually") {
                document = nil
                draft = BloodworkDraft()
                stage = .review
            }
            .font(.footnote)
            .foregroundStyle(Color.nouriTextSecondary)
        }
        .padding(24)
    }

    private var readingView: some View {
        VStack(spacing: 16) {
            Spacer()
            ProgressView()
            Text("Reading your report…").foregroundStyle(Color.nouriTextSecondary)
            Text("Multi-page PDFs can take up to a minute.").font(.footnote).foregroundStyle(Color.nouriTextSecondary)
            Spacer()
        }
        .padding(24)
    }

    private func failedView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle").font(.largeTitle).foregroundStyle(Color.nouriWarning)
            Text("Couldn't read the report").nouriHeading(.title3)
            Text(message).font(.footnote).multilineTextAlignment(.center).foregroundStyle(Color.nouriTextSecondary)
            Button("Try again") {
                if let document { read(document.data, type: document.type) }
            }
            .buttonStyle(.nouriPrimary)
            .disabled(document == nil)
            Button("Enter results manually") {
                draft = BloodworkDraft()
                stage = .review
            }
            .buttonStyle(.nouriSecondary)
        }
        .padding(24)
    }

    private func importFile(at url: URL) {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url) else {
            stage = .failed("Couldn't open that file.")
            return
        }
        if UTType(filenameExtension: url.pathExtension)?.conforms(to: .pdf) == true {
            read(data, type: .pdf)
        } else if let jpeg = UIImage(data: data)?.nouriJPEGData(quality: 0.85) {
            read(jpeg, type: .jpeg)
        } else {
            stage = .failed("That file isn't a PDF or an image.")
        }
    }

    private func read(_ data: Data, type: BloodworkRecord.DocumentType) {
        document = (data, type)
        guard data.count <= ReportDocument.maxBytes else {
            stage = .failed("That file is larger than 10 MB. Try exporting just the results pages.")
            return
        }
        stage = .reading
        Task {
            do {
                let extraction = try await app.extractBloodwork(document: data, type: type)
                draft = BloodworkDraft(extraction)
                stage = .review
            } catch {
                stage = .failed(error.localizedDescription)
            }
        }
    }

    private func save() {
        app.saveBloodwork(document: document?.data, type: document?.type, testDate: draft.testDate,
                          labName: draft.labName.isEmpty ? nil : draft.labName, results: draft.panelResults,
                          notes: draft.notes)
        dismiss()
    }
}

/// Editable form state for a panel.
struct BloodworkDraft {
    struct Row: Identifiable, Equatable {
        var id = UUID()
        var allergen = ""
        /// Free text so the user can type "<0.10" or ">100" exactly as printed.
        var level = ""
        /// `nil` = derive from the level.
        var igeClass: Int?

        init(allergen: String = "", level: String = "", igeClass: Int? = nil) {
            self.allergen = allergen
            self.level = level
            self.igeClass = igeClass
        }

        init(_ result: BloodworkRecord.PanelResult) {
            allergen = result.allergen
            level = (result.comparator?.rawValue ?? "") + result.igeLevel.formatted(.number.precision(.fractionLength(0...2)).grouping(.never))
            igeClass = result.igeClass
        }

        var panelResult: BloodworkRecord.PanelResult? {
            let name = allergen.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty, let parsed = Self.parse(level) else { return nil }
            return BloodworkRecord.PanelResult(allergen: name, igeLevel: parsed.value, igeClass: igeClass, comparator: parsed.comparator)
        }

        static func parse(_ text: String) -> (value: Double, comparator: BloodworkRecord.PanelResult.Comparator?)? {
            var raw = text.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: ".")
            var comparator: BloodworkRecord.PanelResult.Comparator?
            if let first = raw.first, let c = BloodworkRecord.PanelResult.Comparator(rawValue: String(first)) {
                comparator = c
                raw.removeFirst()
            }
            guard let value = Double(raw.trimmingCharacters(in: .whitespaces)), value >= 0 else { return nil }
            return (value, comparator)
        }
    }

    var testDate = Date.now
    var labName = ""
    var rows: [Row] = [Row()]
    var notes = ""
    /// Reader notes shown above the form (unit warnings, illegible rows…), not saved.
    var readerNotes = ""

    init() {}

    init(_ extraction: BloodworkExtraction) {
        testDate = extraction.testDate ?? .now
        labName = extraction.labName ?? ""
        rows = extraction.results.isEmpty ? [Row()] : extraction.results.map { Row($0) }
        readerNotes = extraction.notes
    }

    var panelResults: [BloodworkRecord.PanelResult] { rows.compactMap(\.panelResult) }
    var invalidRowCount: Int {
        rows.filter { !($0.allergen.trimmingCharacters(in: .whitespaces).isEmpty && $0.level.isEmpty) && $0.panelResult == nil }.count
    }
}
