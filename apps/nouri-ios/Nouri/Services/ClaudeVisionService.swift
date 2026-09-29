import UIKit
import FirebaseFunctions

/// Result of analysing a meal photo.
struct MealAnalysis: Equatable {
    var dishName: String
    var ingredients: [Ingredient]
    var notes: String
}

protocol IngredientRecognizing {
    func analyzeMeal(photo: UIImage) async throws -> MealAnalysis
}

enum VisionError: LocalizedError {
    case encodingFailed
    case badResponse
    case server(String)

    var errorDescription: String? {
        switch self {
        case .encodingFailed: "Couldn't prepare the photo."
        case .badResponse: "The ingredient service returned something unexpected."
        case .server(let message): message
        }
    }
}

/// Meal photo → ingredient list via Claude vision.
///
/// The Anthropic API key never ships in the app: the photo goes to the `analyzeMealPhoto` Firebase
/// callable function (see `firebase/functions/src/index.ts`), which requires a signed-in user,
/// calls Claude with a structured-output JSON schema, and returns
/// `{ dishName, ingredients: [{ name, confidence, visible }], notes }`.
/// Allergen flagging then happens on-device with `AllergenDatabase`.
struct ClaudeVisionService: IngredientRecognizing {
    var functions = Functions.functions()

    func analyzeMeal(photo: UIImage) async throws -> MealAnalysis {
        guard let jpeg = photo.nouriJPEGData() else { throw VisionError.encodingFailed }
        let callable = functions.httpsCallable("analyzeMealPhoto")
        callable.timeoutInterval = 90

        let result: HTTPSCallableResult
        do {
            result = try await callable.call(["imageBase64": jpeg.base64EncodedString(), "mediaType": "image/jpeg"])
        } catch {
            // Callable errors carry the HttpsError message thrown by the function.
            throw VisionError.server(error.localizedDescription)
        }

        guard JSONSerialization.isValidJSONObject(result.data) else { throw VisionError.badResponse }
        let data = try JSONSerialization.data(withJSONObject: result.data)
        let payload = try JSONDecoder().decode(Payload.self, from: data)
        return payload.analysis
    }

    struct Payload: Decodable {
        struct Item: Decodable {
            var name: String
            var confidence: Double
        }
        var dishName: String
        var ingredients: [Item]
        var notes: String?

        var analysis: MealAnalysis {
            // Merge duplicates the model may return with different casing, keeping the higher confidence.
            var seen: [String: Ingredient] = [:]
            var order: [String] = []
            for item in ingredients {
                let name = item.name.trimmingCharacters(in: .whitespacesAndNewlines)
                let key = IngredientNormalizer.canonicalKey(name)
                guard !key.isEmpty else { continue }
                let ingredient = AllergenDatabase.annotate(Ingredient(name: name.capitalizedFirst, confidence: item.confidence, source: .ai))
                if let existing = seen[key] {
                    if ingredient.confidence > existing.confidence { seen[key] = ingredient }
                } else {
                    seen[key] = ingredient
                    order.append(key)
                }
            }
            let sorted = order.compactMap { seen[$0] }.sorted { $0.confidence > $1.confidence }
            return MealAnalysis(dishName: dishName, ingredients: sorted, notes: notes ?? "")
        }
    }
}

/// Canned analysis used in demo mode (no Firebase configured) and in SwiftUI previews.
struct DemoVisionService: IngredientRecognizing {
    func analyzeMeal(photo: UIImage) async throws -> MealAnalysis {
        try await Task.sleep(for: .seconds(1.2))
        let items: [(String, Double)] = [
            ("Grilled chicken", 0.92), ("Romaine lettuce", 0.88), ("Parmesan cheese", 0.81),
            ("Croutons", 0.77), ("Caesar dressing", 0.74), ("Lemon", 0.52), ("Black pepper", 0.45),
        ]
        return MealAnalysis(
            dishName: "Chicken Caesar salad",
            ingredients: items.map { AllergenDatabase.annotate(Ingredient(name: $0.0, confidence: $0.1, source: .ai)) },
            notes: "Demo mode — connect Firebase to analyse real photos."
        )
    }
}

extension String {
    var capitalizedFirst: String { prefix(1).uppercased() + dropFirst() }
}
