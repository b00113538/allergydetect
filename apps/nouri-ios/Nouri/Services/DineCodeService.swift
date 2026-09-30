import Foundation
import Security

/// Builds Dine Codes and the public snapshot they point at.
enum DineCodeService {
    /// 22 base62 characters ≈ 131 bits of randomness: unguessable, so the token itself is the
    /// capability to read the snapshot. Firestore rules allow `get` (never `list`) on `dineCodes/*`.
    static func makeToken(length: Int = 22) -> String {
        let alphabet = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz")
        var bytes = [UInt8](repeating: 0, count: length * 2)
        let status = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        precondition(status == errSecSuccess, "Secure random generator unavailable")
        // Rejection sampling avoids modulo bias (248 = 4 * 62).
        var token = ""
        var index = 0
        while token.count < length {
            if index == bytes.count {
                _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
                index = 0
            }
            let byte = bytes[index]
            index += 1
            if byte < 248 { token.append(alphabet[Int(byte) % 62]) }
        }
        return token
    }

    static func snapshot(user: User, profile: AllergyProfile?, bloodwork: [BloodworkRecord] = [],
                         isActive: Bool = true, now: Date = .now) -> DineCodeSnapshot {
        var items: [DineCodeSnapshot.Item] = []
        var seen = Set<String>()
        func add(_ name: String, _ level: String) {
            let key = IngredientNormalizer.canonicalKey(name)
            guard !key.isEmpty, seen.insert(key).inserted else { return }
            items.append(.init(name: name, level: level))
        }
        for condition in user.knownConditions {
            add(AllergenGroup(rawValue: condition)?.label ?? condition.capitalizedFirst, "Confirmed allergy")
        }
        // Food allergens with a moderate-or-higher IgE result (class 2+). Pollen, dust mite etc. are left off.
        for dated in BloodworkInsights.latestResults(bloodwork)
        where dated.result.effectiveClass >= 2 && !dated.result.allergenGroups.isEmpty {
            add(dated.result.allergen.capitalizedFirst, "Positive blood test")
        }
        if let profile {
            for group in profile.triggerGroups where group.status == .likely { add(group.ingredient, "Likely trigger") }
            for trigger in profile.triggerIngredients where trigger.status == .likely { add(trigger.ingredient.capitalizedFirst, "Likely trigger") }
            for trigger in profile.triggerIngredients where trigger.status == .watching { add(trigger.ingredient.capitalizedFirst, "Watching") }
        }
        return DineCodeSnapshot(
            ownerUid: user.id,
            displayName: user.firstName,
            isActive: isActive,
            avoid: items,
            note: "Please avoid these ingredients, including traces and shared cooking surfaces where possible.",
            updatedAt: now
        )
    }

    /// URL encoded in the QR: `<base>/<token>`.
    static func payloadURL(token: String, base: URL = AppEnvironment.dineCodeBaseURL) -> String {
        base.appendingPathComponent(token).absoluteString
    }

    /// Demo mode (no backend): embed the snapshot in the URL fragment. Fragments are never sent to
    /// the server; the scan page decodes them client-side.
    static func offlinePayloadURL(snapshot: DineCodeSnapshot, base: URL = AppEnvironment.dineCodeBaseURL) -> String {
        struct Compact: Encodable { let n: String; let a: [[String]] }
        let compact = Compact(n: snapshot.displayName, a: snapshot.avoid.map { [$0.name, $0.level] })
        let json = (try? JSONEncoder().encode(compact)) ?? Data()
        let b64 = json.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
        return base.absoluteString + "#p=" + b64
    }
}
