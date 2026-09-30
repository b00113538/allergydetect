import Foundation

/// What touched the skin: a product (moisturiser, detergent), a fabric (wool, polyester) or a
/// material (nickel, latex).
enum SkinExposureKind: String, Codable, CaseIterable, Identifiable {
    case product, fabric, material
    var id: String { rawValue }
    var label: String { rawValue.capitalized }
    var symbol: String {
        switch self {
        case .product: "drop"
        case .fabric: "tshirt"
        case .material: "circle.hexagongrid"
        }
    }

    /// Products roll up to the skin domain; fabrics and materials to the fabric domain.
    var domain: TriggerDomain { self == .product ? .skin : .fabric }

    /// Quick picks shown before the user has any history of their own.
    var suggestions: [String] {
        switch self {
        case .product: ["Laundry detergent", "Moisturiser", "Sunscreen", "Perfume", "Shampoo", "Hand soap"]
        case .fabric: ["Wool", "Polyester", "Nylon", "Synthetic blend", "New clothes (unwashed)"]
        case .material: ["Nickel jewellery", "Latex gloves", "Watch strap", "Hair dye"]
        }
    }
}

struct SkinExposure: Codable, Hashable, Identifiable {
    var name: String
    var kind: SkinExposureKind

    var id: String { "\(kind.rawValue):\(IngredientNormalizer.canonicalKey(name))" }
}

enum SkinReaction: String, Codable, CaseIterable, Identifiable {
    case rash, hives, itching, redness, dryness, swelling, none
    var id: String { rawValue }
    var label: String { self == .none ? "No reaction" : rawValue.capitalized }
    var symbol: String {
        switch self {
        case .rash: "hand.raised"
        case .hives: "circle.grid.3x3"
        case .itching: "hand.point.up.left"
        case .redness: "flame"
        case .dryness: "sun.max"
        case .swelling: "circle.dashed"
        case .none: "checkmark.circle"
        }
    }
}

enum BodyArea: String, Codable, CaseIterable, Identifiable {
    case face, scalp, neck, hands, arms, torso, legs, feet
    var id: String { rawValue }
    var label: String { rawValue.capitalized }
}

/// Phase 6: skin / fabric reactions. Mirrors a meal + symptom pair in a single record — what the
/// skin was exposed to, and how it reacted (including "no reaction", which is what lets the
/// pattern engine tell a real trigger from something the user wears every day).
struct SkinLog: Codable, Identifiable, Equatable {
    var id: String
    var userId: String
    var photoURL: String?
    var localPhotoName: String?
    var timestamp: Date
    var exposures: [SkinExposure]
    var reactions: [SkinReaction]
    var bodyAreas: [BodyArea]
    /// 1 (mild) ... 5 (severe). Ignored when `reactions == [.none]`.
    var severity: Int
    var notes: String
    var needsSync: Bool

    init(id: String = UUID().uuidString, userId: String, photoURL: String? = nil, localPhotoName: String? = nil,
         timestamp: Date = .now, exposures: [SkinExposure], reactions: [SkinReaction], bodyAreas: [BodyArea] = [],
         severity: Int, notes: String = "", needsSync: Bool = true) {
        self.id = id
        self.userId = userId
        self.photoURL = photoURL
        self.localPhotoName = localPhotoName
        self.timestamp = timestamp
        self.exposures = exposures
        self.reactions = reactions
        self.bodyAreas = bodyAreas
        self.severity = min(max(severity, 1), 5)
        self.notes = notes
        self.needsSync = needsSync
    }

    var isReaction: Bool { reactions.contains { $0 != .none } }

    var title: String {
        exposures.isEmpty ? "Skin check-in" : exposures.map(\.name).joined(separator: ", ")
    }
}
