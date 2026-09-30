import UIKit
import FirebaseFunctions

/// What was read off a label, before the user reviews it.
struct ProductLabel: Equatable {
    var productName: String
    var kind: SkinExposureKind
    /// Ingredients or fibres in label order. Fibres carry their percentage in `percentages`.
    var ingredients: [String]
    var percentages: [String: Double]
    var notes: String

    struct Flag: Identifiable, Equatable {
        var group: ContactAllergenGroup
        /// The label ingredients that put it in this group.
        var ingredients: [String]
        var id: ContactAllergenGroup { group }
    }

    /// Contact-allergen groups flagged anywhere on the label, in a stable order.
    var flagged: [Flag] {
        var hits: [ContactAllergenGroup: [String]] = [:]
        for ingredient in ingredients {
            for group in ContactAllergenDatabase.groups(for: ingredient) { hits[group, default: []].append(ingredient) }
        }
        return ContactAllergenGroup.allCases.compactMap { group in
            hits[group].map { Flag(group: group, ingredients: $0) }
        }
    }
}

protocol ProductLabelReading {
    func readLabel(photo: UIImage) async throws -> ProductLabel
}

/// Label photo → ingredients via the `readProductLabel` callable (`firebase/functions/src/label.ts`).
/// Matching against contact allergens happens on-device with `ContactAllergenDatabase`.
struct ClaudeProductLabelService: ProductLabelReading {
    var functions = Functions.functions()

    func readLabel(photo: UIImage) async throws -> ProductLabel {
        // Labels are small print: send a sharper image than meal photos.
        guard let jpeg = photo.nouriJPEGData(quality: 0.85) else { throw VisionError.encodingFailed }
        let callable = functions.httpsCallable("readProductLabel")
        callable.timeoutInterval = 120

        let result: HTTPSCallableResult
        do {
            result = try await callable.call(["imageBase64": jpeg.base64EncodedString(), "mediaType": "image/jpeg"])
        } catch {
            throw VisionError.server(error.localizedDescription)
        }
        guard JSONSerialization.isValidJSONObject(result.data) else { throw VisionError.badResponse }
        let data = try JSONSerialization.data(withJSONObject: result.data)
        return try JSONDecoder().decode(Payload.self, from: data).label
    }

    struct Payload: Decodable {
        struct Item: Decodable {
            var name: String
            var percent: Double
        }
        var productName: String
        var kind: String
        var ingredients: [Item]
        var notes: String

        var label: ProductLabel {
            var seen = Set<String>()
            var names: [String] = []
            var percentages: [String: Double] = [:]
            for item in ingredients {
                let name = item.name.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !name.isEmpty, seen.insert(name.lowercased()).inserted else { continue }
                names.append(name)
                if (0...100).contains(item.percent) { percentages[name] = item.percent }
            }
            return ProductLabel(productName: productName.trimmingCharacters(in: .whitespacesAndNewlines),
                                kind: SkinExposureKind(rawValue: kind) ?? .product,
                                ingredients: names, percentages: percentages, notes: notes)
        }
    }
}

/// Canned label for demo mode (no Firebase configured).
struct DemoProductLabelService: ProductLabelReading {
    func readLabel(photo: UIImage) async throws -> ProductLabel {
        try await Task.sleep(for: .seconds(1.2))
        return SampleData.moisturiserLabel
    }
}
