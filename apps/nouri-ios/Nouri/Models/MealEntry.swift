import Foundation

enum MealType: String, Codable, CaseIterable, Identifiable {
    case breakfast, lunch, dinner, snack
    var id: String { rawValue }
    var label: String { rawValue.capitalized }
    var symbol: String {
        switch self {
        case .breakfast: "sunrise"
        case .lunch: "sun.max"
        case .dinner: "moon.stars"
        case .snack: "leaf"
        }
    }

    /// Best guess from the time of day, used to pre-select the picker.
    static func suggested(for date: Date = .now, calendar: Calendar = .current) -> MealType {
        switch calendar.component(.hour, from: date) {
        case 5..<11: .breakfast
        case 11..<16: .lunch
        case 17..<22: .dinner
        default: .snack
        }
    }
}

struct Ingredient: Codable, Hashable, Identifiable {
    enum Source: String, Codable { case ai, user }

    var name: String
    /// 0...1. AI-provided for `.ai`, 1.0 for user-entered ingredients.
    var confidence: Double
    var source: Source
    /// Filled in by `AllergenDatabase` so high-risk items are flagged immediately.
    var allergenGroups: [AllergenGroup]

    var id: String { name.lowercased() }
    var isHighRisk: Bool { !allergenGroups.isEmpty }

    init(name: String, confidence: Double, source: Source, allergenGroups: [AllergenGroup] = []) {
        self.name = name
        self.confidence = min(max(confidence, 0), 1)
        self.source = source
        self.allergenGroups = allergenGroups
    }
}

struct MealEntry: Codable, Identifiable, Equatable {
    var id: String
    var userId: String
    /// Remote (Cloud Storage) download URL once uploaded.
    var photoURL: String?
    /// File name inside the app's local photo directory (offline-first copy).
    var localPhotoName: String?
    var timestamp: Date
    var ingredients: [Ingredient]
    var mealType: MealType
    var dishName: String?
    var userNotes: String
    /// Local-only flag: true until the record has been written to Firestore.
    var needsSync: Bool

    init(id: String = UUID().uuidString, userId: String, photoURL: String? = nil, localPhotoName: String? = nil,
         timestamp: Date = .now, ingredients: [Ingredient], mealType: MealType, dishName: String? = nil,
         userNotes: String = "", needsSync: Bool = true) {
        self.id = id
        self.userId = userId
        self.photoURL = photoURL
        self.localPhotoName = localPhotoName
        self.timestamp = timestamp
        self.ingredients = ingredients
        self.mealType = mealType
        self.dishName = dishName
        self.userNotes = userNotes
        self.needsSync = needsSync
    }

    var title: String { dishName ?? mealType.label }
}
