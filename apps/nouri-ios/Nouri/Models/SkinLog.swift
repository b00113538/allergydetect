import Foundation

/// Phase 6 (expansion): skin / fabric reactions. Same photo + symptom pattern as food.
struct SkinLog: Codable, Identifiable, Equatable {
    enum SuspectedTriggerKind: String, Codable, CaseIterable { case product, fabric, material }

    var id: String
    var userId: String
    var photoURL: String?
    var localPhotoName: String?
    var timestamp: Date
    var suspectedTriggerKind: SuspectedTriggerKind
    /// e.g. "wool jumper", "Brand X moisturiser"
    var suspectedTrigger: String
    var reactionType: String
    var severity: Int
    var needsSync: Bool
}
