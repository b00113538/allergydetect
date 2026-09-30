import Foundation

/// Phase 6: clinical allergy panel results, extracted from an uploaded PDF/photo and confirmed by the user.
struct BloodworkRecord: Codable, Identifiable, Equatable {
    struct PanelResult: Codable, Hashable {
        enum Comparator: String, Codable { case lessThan = "<", greaterThan = ">" }

        var allergen: String
        /// Specific IgE in kU/L (kUA/L and IU/mL are treated as equivalent).
        var igeLevel: Double
        /// ImmunoCAP class 0–6 where the lab reports it.
        var igeClass: Int?
        /// Set when the lab reports a bound rather than a value, e.g. "<0.10" or ">100".
        var comparator: Comparator?

        init(allergen: String, igeLevel: Double, igeClass: Int? = nil, comparator: Comparator? = nil) {
            self.allergen = allergen
            self.igeLevel = max(0, igeLevel)
            self.igeClass = igeClass.map { min(max($0, 0), 6) }
            self.comparator = comparator
        }

        /// The lab's class when given, otherwise derived from the level.
        var effectiveClass: Int { igeClass ?? IgEScale.igeClass(forLevel: igeLevel, comparator: comparator) }
        var isSensitised: Bool { effectiveClass >= 1 }
        var levelString: String {
            let number = igeLevel.formatted(.number.precision(.fractionLength(0...2)))
            return "\(comparator?.rawValue ?? "")\(number) kU/L"
        }
        /// Food allergen groups this result maps to ("Cow's milk" → dairy). Empty for pollen, dust mite, etc.
        var allergenGroups: [AllergenGroup] { AllergenDatabase.groups(for: allergen) }
    }

    enum DocumentType: String, Codable {
        case pdf, jpeg
        var mimeType: String { self == .pdf ? "application/pdf" : "image/jpeg" }
        var fileExtension: String { self == .pdf ? "pdf" : "jpg" }
    }

    var id: String
    var userId: String
    var testDate: Date
    var labName: String?
    var panelResults: [PanelResult]
    /// Cloud Storage download URL of the original report once uploaded.
    var sourceDocURL: String?
    /// File name of the on-device copy (see `DocumentStore`).
    var localDocName: String?
    var sourceDocType: DocumentType?
    var notes: String
    var needsSync: Bool

    init(id: String = UUID().uuidString, userId: String, testDate: Date, labName: String? = nil,
         panelResults: [PanelResult], sourceDocURL: String? = nil, localDocName: String? = nil,
         sourceDocType: DocumentType? = nil, notes: String = "", needsSync: Bool = true) {
        self.id = id
        self.userId = userId
        self.testDate = testDate
        self.labName = labName
        self.panelResults = panelResults
        self.sourceDocURL = sourceDocURL
        self.localDocName = localDocName
        self.sourceDocType = sourceDocType
        self.notes = notes
        self.needsSync = needsSync
    }

    var sensitisedResults: [PanelResult] {
        panelResults.filter(\.isSensitised).sorted { $0.igeLevel > $1.igeLevel }
    }
}

/// Standard ImmunoCAP specific-IgE classes. Class 1+ (≥ 0.35 kU/L) means *sensitised* — the
/// immune system recognises the allergen — which is not the same as a clinical allergy.
enum IgEScale {
    /// Lower bound (kU/L) of classes 1...6.
    static let classThresholds: [Double] = [0.35, 0.7, 3.5, 17.5, 50, 100]

    static func igeClass(forLevel level: Double, comparator: BloodworkRecord.PanelResult.Comparator? = nil) -> Int {
        // "<0.35" is class 0 even though 0.35 itself would be class 1.
        if comparator == .lessThan, let first = classThresholds.first, level <= first { return 0 }
        return classThresholds.lastIndex { level >= $0 }.map { $0 + 1 } ?? 0
    }

    static func label(forClass igeClass: Int) -> String {
        switch igeClass {
        case ...0: "Negative"
        case 1: "Low"
        case 2: "Moderate"
        case 3: "High"
        case 4: "Very high"
        default: "Extremely high"
        }
    }
}
