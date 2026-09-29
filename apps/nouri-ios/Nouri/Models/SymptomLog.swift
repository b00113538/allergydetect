import Foundation

enum SymptomType: String, Codable, CaseIterable, Identifiable {
    case cough, rash, mucus, drowsiness, irritation, none
    var id: String { rawValue }
    var label: String { self == .none ? "No symptoms" : rawValue.capitalized }
    var symbol: String {
        switch self {
        case .cough: "lungs"
        case .rash: "hand.raised"
        case .mucus: "drop"
        case .drowsiness: "moon.zzz"
        case .irritation: "eye"
        case .none: "checkmark.circle"
        }
    }
}

struct SymptomLog: Codable, Identifiable, Equatable {
    var id: String
    var userId: String
    /// Optional explicit link to a meal; standalone logs are matched by time window.
    var mealEntryId: String?
    var timestamp: Date
    var symptomTypes: [SymptomType]
    /// 1 (mild) ... 5 (severe). Ignored when `symptomTypes == [.none]`.
    var severity: Int
    var notes: String
    var needsSync: Bool

    init(id: String = UUID().uuidString, userId: String, mealEntryId: String? = nil, timestamp: Date = .now,
         symptomTypes: [SymptomType], severity: Int, notes: String = "", needsSync: Bool = true) {
        self.id = id
        self.userId = userId
        self.mealEntryId = mealEntryId
        self.timestamp = timestamp
        self.symptomTypes = symptomTypes
        self.severity = min(max(severity, 1), 5)
        self.notes = notes
        self.needsSync = needsSync
    }

    /// True when this log records an actual reaction (not just "I feel fine").
    var isReaction: Bool { symptomTypes.contains { $0 != .none } }
}
