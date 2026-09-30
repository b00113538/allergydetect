import Foundation

enum TriggerDomain: String, Codable, CaseIterable {
    case food, skin, fabric
}

enum TriggerStatus: String, Codable, Comparable {
    /// Crossed the frequency + reaction-rate threshold.
    case likely
    /// Some signal, not enough data yet.
    case watching
    /// Exposed several times without reactions.
    case unlikely

    private var rank: Int { switch self { case .likely: 0; case .watching: 1; case .unlikely: 2 } }
    static func < (a: Self, b: Self) -> Bool { a.rank < b.rank }

    var label: String {
        switch self {
        case .likely: "Likely trigger"
        case .watching: "Watching"
        case .unlikely: "Unlikely"
        }
    }
}

/// One row of the correlation engine output. Everything needed to explain the score is kept.
struct TriggerIngredient: Codable, Hashable, Identifiable {
    var ingredient: String
    var domain: TriggerDomain
    /// 0...1
    var confidence: Double
    /// Meals containing the ingredient.
    var exposures: Int
    /// Of those, meals followed by a symptom inside the window.
    var reactions: Int
    /// Reaction rate for meals *without* this ingredient (the baseline it is compared against).
    /// `nil` when there are too few such meals to compare.
    var baselineRate: Double?
    var averageSeverity: Double
    var status: TriggerStatus
    var allergenGroups: [AllergenGroup]

    var id: String { "\(domain.rawValue):\(ingredient)" }
    var reactionRate: Double { exposures == 0 ? 0 : Double(reactions) / Double(exposures) }
}

struct AllergyProfile: Codable, Identifiable, Equatable {
    var id: String
    var userId: String
    /// Individual ingredients, sorted by status then confidence.
    var triggerIngredients: [TriggerIngredient]
    /// The same analysis rolled up to allergen groups (dairy, gluten, …).
    var triggerGroups: [TriggerIngredient]
    var triggerCategories: [TriggerDomain]
    var mealsAnalyzed: Int
    var symptomLogsAnalyzed: Int
    var lastUpdated: Date

    static func empty(userId: String) -> AllergyProfile {
        AllergyProfile(id: "current", userId: userId, triggerIngredients: [], triggerGroups: [],
                       triggerCategories: [], mealsAnalyzed: 0, symptomLogsAnalyzed: 0, lastUpdated: .now)
    }

    var likelyTriggers: [TriggerIngredient] { triggerIngredients.filter { $0.status == .likely } }
}
