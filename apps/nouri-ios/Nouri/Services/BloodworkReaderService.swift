import Foundation
import FirebaseFunctions

/// What the report reader found, before the user reviews it.
struct BloodworkExtraction: Equatable {
    var testDate: Date?
    var labName: String?
    var results: [BloodworkRecord.PanelResult]
    var notes: String
}

protocol BloodworkReading {
    func extractPanel(document: Data, type: BloodworkRecord.DocumentType) async throws -> BloodworkExtraction
}

/// Lab report (PDF or photo) → specific-IgE results via the `extractBloodworkPanel` callable
/// (see `firebase/functions/src/index.ts`), which sends the document to Claude with a JSON schema.
/// Like meal photos, the API key stays server-side.
struct ClaudeBloodworkService: BloodworkReading {
    var functions = Functions.functions()

    func extractPanel(document: Data, type: BloodworkRecord.DocumentType) async throws -> BloodworkExtraction {
        let callable = functions.httpsCallable("extractBloodworkPanel")
        callable.timeoutInterval = 300

        let result: HTTPSCallableResult
        do {
            result = try await callable.call(["documentBase64": document.base64EncodedString(), "mediaType": type.mimeType])
        } catch {
            throw VisionError.server(error.localizedDescription)
        }

        guard JSONSerialization.isValidJSONObject(result.data) else { throw VisionError.badResponse }
        let data = try JSONSerialization.data(withJSONObject: result.data)
        return try JSONDecoder().decode(Payload.self, from: data).extraction
    }

    struct Payload: Decodable {
        struct Result: Decodable {
            var allergen: String
            var value: Double
            var comparator: String
            var unit: String
            var reportedClass: Int
        }
        var testDate: String
        var labName: String
        var results: [Result]
        var notes: String

        var extraction: BloodworkExtraction {
            var seen = Set<String>()
            let panel = results.compactMap { item -> BloodworkRecord.PanelResult? in
                let name = item.allergen.trimmingCharacters(in: .whitespacesAndNewlines)
                let key = IngredientNormalizer.canonicalKey(name)
                // Reports sometimes repeat a result in a summary table; keep the first.
                guard !key.isEmpty, seen.insert(key).inserted else { return nil }
                return BloodworkRecord.PanelResult(
                    allergen: name.capitalizedFirst,
                    igeLevel: item.value,
                    igeClass: (0...6).contains(item.reportedClass) ? item.reportedClass : nil,
                    comparator: BloodworkRecord.PanelResult.Comparator(rawValue: item.comparator)
                )
            }
            let unitNote = results.map(\.unit).filter { !Self.isStandardUnit($0) }.first.map {
                "Some results are in \($0), not kU/L — check the values against the report."
            }
            return BloodworkExtraction(
                testDate: Self.dateFormatter.date(from: testDate),
                labName: labName.isEmpty ? nil : labName,
                results: panel,
                notes: [notes, unitNote].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " ")
            )
        }

        /// kU/L, kUA/L and IU/mL are the same scale for specific IgE.
        static func isStandardUnit(_ unit: String) -> Bool {
            let u = unit.lowercased().replacingOccurrences(of: " ", with: "")
            return u.isEmpty || ["ku/l", "kua/l", "iu/ml", "kiu/l", "kui/l"].contains(u)
        }

        static let dateFormatter: DateFormatter = {
            let formatter = DateFormatter()
            formatter.calendar = Calendar(identifier: .gregorian)
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = .current
            formatter.dateFormat = "yyyy-MM-dd"
            return formatter
        }()
    }
}

/// Canned panel for demo mode (no Firebase configured).
struct DemoBloodworkService: BloodworkReading {
    func extractPanel(document: Data, type: BloodworkRecord.DocumentType) async throws -> BloodworkExtraction {
        try await Task.sleep(for: .seconds(1.5))
        return BloodworkExtraction(
            testDate: Calendar.current.date(byAdding: .day, value: -10, to: .now),
            labName: "Demo Diagnostics",
            results: SampleData.bloodworkPanel,
            notes: "Demo mode — connect Firebase to read real reports."
        )
    }
}
