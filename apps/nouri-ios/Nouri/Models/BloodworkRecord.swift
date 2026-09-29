import Foundation

/// Phase 6 (expansion): clinical allergy panel results, extracted from an uploaded PDF/photo.
struct BloodworkRecord: Codable, Identifiable, Equatable {
    struct PanelResult: Codable, Hashable {
        var allergen: String
        /// Specific IgE in kU/L.
        var igeLevel: Double
        /// ImmunoCAP class 0–6 where the lab reports it.
        var igeClass: Int?
    }

    var id: String
    var userId: String
    var testDate: Date
    var panelResults: [PanelResult]
    var sourceDocURL: String?
    var needsSync: Bool
}
