import Foundation

/// The signed-in person. `id` matches the Firebase Auth uid (or a local id in demo mode).
struct User: Codable, Identifiable, Equatable {
    var id: String
    var name: String
    var email: String
    var dateOfBirth: Date?
    /// Free-text or canonical allergen names the user already knows about (e.g. "peanuts", "eczema").
    var knownConditions: [String]
    /// Answers from the onboarding symptom-history questionnaire.
    var symptomHistory: SymptomHistory?
    var createdAt: Date

    var firstName: String {
        name.split(separator: " ").first.map(String.init) ?? name
    }
}

struct SymptomHistory: Codable, Equatable {
    var usualSymptoms: [SymptomType]
    var frequency: Frequency
    var suspectsFood: Bool
    var suspectsSkinOrFabric: Bool

    enum Frequency: String, Codable, CaseIterable, Identifiable {
        case rarely, monthly, weekly, daily
        var id: String { rawValue }
        var label: String {
            switch self {
            case .rarely: "Rarely"
            case .monthly: "A few times a month"
            case .weekly: "Most weeks"
            case .daily: "Almost every day"
            }
        }
    }
}
