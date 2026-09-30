import Foundation

/// One line of the "blood work vs. your logs" comparison.
struct BloodworkFinding: Identifiable, Hashable {
    enum Kind: Int, Comparable {
        /// Sensitised on the panel *and* a likely/watching pattern in the logs.
        case agrees
        /// Sensitised on the panel, no pattern in the logs (yet).
        case sensitisedOnly
        /// Pattern in the logs, but the panel tested that allergen and came back negative —
        /// often a non-IgE intolerance rather than an allergy.
        case patternOnly

        static func < (a: Self, b: Self) -> Bool { a.rawValue < b.rawValue }

        var label: String {
            switch self {
            case .agrees: "Blood test and logs agree"
            case .sensitisedOnly: "Sensitised on blood test"
            case .patternOnly: "Pattern, but blood test negative"
            }
        }
    }

    var kind: Kind
    var allergen: String
    var result: BloodworkRecord.PanelResult?
    var testDate: Date?
    var trigger: TriggerIngredient?

    var id: String { "\(kind.rawValue):\(IngredientNormalizer.canonicalKey(allergen))" }

    var explanation: String {
        switch kind {
        case .agrees:
            "IgE class \(result?.effectiveClass ?? 0) and symptoms after \(trigger?.reactions ?? 0) of \(trigger?.exposures ?? 0) meals."
        case .sensitisedOnly:
            "IgE class \(result?.effectiveClass ?? 0), but no reactions to it in your logs so far. Sensitisation alone doesn't always mean a reaction."
        case .patternOnly:
            "Your logs flag it, but the IgE test was negative. That can point to an intolerance rather than an allergy — worth raising with a clinician."
        }
    }
}

/// Cross-references uploaded panels with the food pattern engine.
enum BloodworkInsights {
    struct DatedResult: Hashable {
        var result: BloodworkRecord.PanelResult
        var testDate: Date
    }

    /// The most recent result for each allergen across all records.
    static func latestResults(_ records: [BloodworkRecord]) -> [DatedResult] {
        var latest: [String: DatedResult] = [:]
        for record in records {
            for result in record.panelResults {
                let key = IngredientNormalizer.canonicalKey(result.allergen)
                guard !key.isEmpty else { continue }
                if let existing = latest[key], existing.testDate >= record.testDate { continue }
                latest[key] = DatedResult(result: result, testDate: record.testDate)
            }
        }
        return latest.values.sorted { $0.result.igeLevel > $1.result.igeLevel }
    }

    static func findings(records: [BloodworkRecord], profile: AllergyProfile?) -> [BloodworkFinding] {
        let results = latestResults(records)
        guard !results.isEmpty else { return [] }
        let flagged = (profile?.triggerGroups ?? []) + (profile?.triggerIngredients ?? [])
        let patterns = flagged.filter { $0.status != .unlikely }

        func matchingPattern(_ result: BloodworkRecord.PanelResult) -> TriggerIngredient? {
            let groups = Set(result.allergenGroups)
            let key = IngredientNormalizer.canonicalKey(result.allergen)
            return patterns.first { trigger in
                IngredientNormalizer.canonicalKey(trigger.ingredient) == key
                    || !groups.isDisjoint(with: trigger.allergenGroups)
            }
        }

        var findings: [BloodworkFinding] = []
        var explained = Set<String>()
        for dated in results where dated.result.isSensitised {
            let trigger = matchingPattern(dated.result)
            if let trigger { explained.insert(trigger.id) }
            findings.append(BloodworkFinding(kind: trigger == nil ? .sensitisedOnly : .agrees, allergen: dated.result.allergen,
                                             result: dated.result, testDate: dated.testDate, trigger: trigger))
        }

        // Patterns whose allergen group was tested and came back negative everywhere.
        let negatives = results.filter { !$0.result.isSensitised }
        let positiveGroups = Set(results.filter(\.result.isSensitised).flatMap(\.result.allergenGroups))
        for trigger in patterns where !explained.contains(trigger.id) {
            let groups = Set(trigger.allergenGroups).subtracting(positiveGroups)
            guard let negative = negatives.first(where: { !groups.isDisjoint(with: $0.result.allergenGroups) }) else { continue }
            // Report each allergen once: prefer the group rollup ("Dairy") over individual ingredients.
            guard !findings.contains(where: { $0.kind == .patternOnly && !Set($0.trigger?.allergenGroups ?? []).isDisjoint(with: groups) }) else { continue }
            findings.append(BloodworkFinding(kind: .patternOnly, allergen: trigger.ingredient.capitalizedFirst,
                                             result: negative.result, testDate: negative.testDate, trigger: trigger))
        }

        return findings.sorted {
            if $0.kind != $1.kind { return $0.kind < $1.kind }
            return ($0.result?.igeLevel ?? 0) > ($1.result?.igeLevel ?? 0)
        }
    }
}
