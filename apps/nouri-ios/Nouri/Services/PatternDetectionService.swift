import Foundation

/// Correlation-counting trigger detection (MVP).
///
/// For every ingredient we count how many meals contained it ("exposures") and how many of those
/// meals were followed by a reaction ("reactions"): a symptom log explicitly linked to the meal, or
/// any reaction logged within `window` after eating. An ingredient is a *likely trigger* when it has
/// at least `minExposures` exposures, a reaction rate ≥ `minReactionRate`, and reacts more often
/// than the user's baseline (meals *without* it) — the baseline check keeps ubiquitous items like
/// salt or olive oil from being blamed for everything.
///
/// Skin logs (phase 6) are scored the same way: each log is one exposure event, and the products,
/// fabrics and materials in it play the part of ingredients.
///
/// Deliberately explainable: every number shown in the UI comes straight from these counts. It can be
/// swapped for a learned model later behind the same `analyze` signature.
struct PatternDetectionService {
    struct Configuration {
        var window: ClosedRange<TimeInterval> = 0...(8 * 3600)
        var minExposures = 3
        var minReactionRate = 0.7
        var watchMinExposures = 2
        var watchMinReactionRate = 0.5
        /// Exposures needed before the sample-size weight reaches 1.
        var fullConfidenceExposures = 5
        /// Meals *without* an ingredient needed before its baseline comparison is trusted.
        var minBaselineMeals = 2
    }

    var configuration = Configuration()

    func analyze(meals: [MealEntry], symptoms: [SymptomLog], skinLogs: [SkinLog] = [], userId: String, now: Date = .now) -> AllergyProfile {
        let outcomes = mealOutcomes(meals: meals, symptoms: symptoms)
        let totalMeals = outcomes.count
        let totalReactions = outcomes.filter(\.reacted).count

        // Ingredient-level tallies.
        var byIngredient: [String: Tally] = [:]
        var byGroup: [AllergenGroup: Tally] = [:]
        for outcome in outcomes {
            var seenKeys = Set<String>()
            var seenGroups = Set<AllergenGroup>()
            for ingredient in outcome.meal.ingredients {
                let key = IngredientNormalizer.canonicalKey(ingredient.name)
                guard !key.isEmpty, seenKeys.insert(key).inserted else { continue }
                byIngredient[key, default: Tally(displayName: ingredient.name)].record(outcome.reacted, severity: outcome.severity)
                let groups = ingredient.allergenGroups.isEmpty ? AllergenDatabase.groups(for: ingredient.name) : ingredient.allergenGroups
                byIngredient[key]?.groups.formUnion(groups)
                seenGroups.formUnion(groups)
            }
            for group in seenGroups {
                byGroup[group, default: Tally(displayName: group.label)].record(outcome.reacted, severity: outcome.severity)
                byGroup[group]?.groups.insert(group)
            }
        }

        func score(_ tally: Tally) -> TriggerIngredient {
            makeTrigger(name: tally.displayName, domain: .food, tally: tally,
                        baseline: baseline(for: tally, totalEvents: totalMeals, totalReactions: totalReactions))
        }

        let ingredients = byIngredient.values.map(score).sorted(by: Self.ranking)
        let groups = byGroup.values.map(score).sorted(by: Self.ranking)
        let skin = analyzeSkin(logs: skinLogs)
        let skinGroups = analyzeSkinGroups(logs: skinLogs)

        var categories: [TriggerDomain] = []
        if ingredients.contains(where: { $0.status == .likely }) { categories.append(.food) }
        for domain in [TriggerDomain.skin, .fabric]
        where (skin + skinGroups).contains(where: { $0.domain == domain && $0.status == .likely }) {
            categories.append(domain)
        }

        return AllergyProfile(
            id: "current",
            userId: userId,
            triggerIngredients: ingredients,
            triggerGroups: groups,
            skinTriggers: skin,
            skinGroupTriggers: skinGroups,
            triggerCategories: categories,
            mealsAnalyzed: totalMeals,
            symptomLogsAnalyzed: symptoms.count,
            lastUpdated: now
        )
    }

    // MARK: - Skin

    /// Scores every product / fabric / material across skin logs. A log with an actual reaction
    /// counts as a reaction for everything in it; a "no reaction" log is a clean exposure.
    func analyzeSkin(logs: [SkinLog]) -> [TriggerIngredient] {
        let totalReactions = logs.filter(\.isReaction).count
        var byExposure: [String: (kind: SkinExposureKind, tally: Tally)] = [:]
        for log in logs {
            var seen = Set<String>()
            for exposure in log.exposures {
                guard !IngredientNormalizer.canonicalKey(exposure.name).isEmpty, seen.insert(exposure.id).inserted else { continue }
                var entry = byExposure[exposure.id] ?? (kind: exposure.kind, tally: Tally(displayName: exposure.name))
                entry.tally.record(log.isReaction, severity: log.isReaction ? log.severity : 0)
                byExposure[exposure.id] = entry
            }
        }
        return byExposure.values.map { entry in
            makeTrigger(name: entry.tally.displayName, domain: entry.kind.domain, tally: entry.tally,
                        baseline: baseline(for: entry.tally, totalEvents: logs.count, totalReactions: totalReactions))
        }
        .sorted(by: Self.ranking)
    }

    /// Rolls every log up to contact-allergen groups (from product/fabric names and scanned label
    /// ingredients) and scores those. This is what catches "fragrance" when it's spread across a
    /// moisturiser, a shampoo and a detergent that each look harmless on their own.
    func analyzeSkinGroups(logs: [SkinLog]) -> [TriggerIngredient] {
        let totalReactions = logs.filter(\.isReaction).count
        var byGroup: [ContactAllergenGroup: Tally] = [:]
        for log in logs {
            let groups = log.exposures.reduce(into: Set<ContactAllergenGroup>()) { $0.formUnion($1.contactGroups) }
            for group in groups {
                byGroup[group, default: Tally(displayName: group.label)]
                    .record(log.isReaction, severity: log.isReaction ? log.severity : 0)
            }
        }
        return byGroup.map { group, tally in
            var trigger = makeTrigger(name: tally.displayName, domain: group.domain, tally: tally,
                                      baseline: baseline(for: tally, totalEvents: logs.count, totalReactions: totalReactions))
            trigger.contactGroup = group
            return trigger
        }
        .sorted(by: Self.ranking)
    }

    /// Reaction rate of the events *without* this item; `nil` when too few exist to compare
    /// (e.g. an ingredient that's in everything).
    private func baseline(for tally: Tally, totalEvents: Int, totalReactions: Int) -> Double? {
        let without = totalEvents - tally.exposures
        guard without >= configuration.minBaselineMeals else { return nil }
        return Double(totalReactions - tally.reactions) / Double(without)
    }

    // MARK: - Meal outcomes

    struct MealOutcome {
        let meal: MealEntry
        let reacted: Bool
        /// Max severity among the reactions attributed to this meal (0 when none).
        let severity: Int
    }

    /// Decides, for each meal, whether it was followed by a reaction.
    func mealOutcomes(meals: [MealEntry], symptoms: [SymptomLog]) -> [MealOutcome] {
        let reactions = symptoms.filter(\.isReaction)
        let linked = Dictionary(grouping: reactions.filter { $0.mealEntryId != nil }, by: { $0.mealEntryId! })
        // An explicit "no symptoms" log linked to a meal is a confirmed negative for that meal only.
        let confirmedClear = Set(symptoms.filter { !$0.isReaction }.compactMap(\.mealEntryId))

        return meals.map { meal in
            var attributed = linked[meal.id] ?? []
            if attributed.isEmpty && !confirmedClear.contains(meal.id) {
                attributed = reactions.filter { log in
                    // Logs linked to a *different* meal are attributed to that meal, not this one.
                    guard log.mealEntryId == nil else { return false }
                    return configuration.window.contains(log.timestamp.timeIntervalSince(meal.timestamp))
                }
            }
            return MealOutcome(meal: meal, reacted: !attributed.isEmpty, severity: attributed.map(\.severity).max() ?? 0)
        }
    }

    // MARK: - Scoring

    private func makeTrigger(name: String, domain: TriggerDomain, tally: Tally, baseline: Double?) -> TriggerIngredient {
        let rate = tally.exposures == 0 ? 0 : Double(tally.reactions) / Double(tally.exposures)
        let avgSeverity = tally.reactions == 0 ? 0 : Double(tally.severitySum) / Double(tally.reactions)
        // Without a baseline we can't tell it apart from the rest of the diet: allow it on rate alone,
        // but only give it half credit for specificity.
        let lift = baseline.map { rate - $0 } ?? rate

        let status: TriggerStatus
        if tally.exposures >= configuration.minExposures && rate >= configuration.minReactionRate && lift > 0 {
            status = .likely
        } else if tally.exposures >= configuration.watchMinExposures && rate >= configuration.watchMinReactionRate && lift > 0 {
            status = .watching
        } else {
            status = .unlikely
        }

        // confidence = how often it reacts, discounted by how much of that is just the baseline,
        // how little data we have, and nudged up by severity.
        let sampleWeight = min(1, Double(tally.exposures) / Double(configuration.fullConfidenceExposures))
        let specificity = baseline == nil ? 0.5 : max(0, lift) / max(rate, .ulpOfOne)   // share of the rate not explained by baseline
        let severityWeight = 0.8 + 0.2 * (avgSeverity / 5)
        let confidence = min(1, max(0, rate * (0.5 + 0.5 * specificity) * sampleWeight * severityWeight))

        return TriggerIngredient(
            ingredient: name,
            domain: domain,
            confidence: confidence,
            exposures: tally.exposures,
            reactions: tally.reactions,
            baselineRate: baseline,
            averageSeverity: avgSeverity,
            status: status,
            allergenGroups: AllergenGroup.allCases.filter(tally.groups.contains)
        )
    }

    private static func ranking(_ a: TriggerIngredient, _ b: TriggerIngredient) -> Bool {
        if a.status != b.status { return a.status < b.status }
        if a.confidence != b.confidence { return a.confidence > b.confidence }
        return a.ingredient < b.ingredient
    }

    private struct Tally {
        var displayName: String
        var exposures = 0
        var reactions = 0
        var severitySum = 0
        var groups = Set<AllergenGroup>()

        mutating func record(_ reacted: Bool, severity: Int) {
            exposures += 1
            if reacted {
                reactions += 1
                severitySum += severity
            }
        }
    }
}

// MARK: - Trends

struct SymptomTrendPoint: Identifiable, Hashable {
    var weekStart: Date
    var reactionCount: Int
    var averageSeverity: Double
    var id: Date { weekStart }
}

extension PatternDetectionService {
    /// Weekly reaction counts for the last `weeks` weeks (oldest first, empty weeks included).
    static func weeklyTrend(symptoms: [SymptomLog], weeks: Int = 8, now: Date = .now, calendar: Calendar = .current) -> [SymptomTrendPoint] {
        guard let thisWeek = calendar.dateInterval(of: .weekOfYear, for: now)?.start else { return [] }
        let starts = (0..<weeks).reversed().compactMap { calendar.date(byAdding: .weekOfYear, value: -$0, to: thisWeek) }
        let reactions = symptoms.filter(\.isReaction)
        return starts.map { start in
            let end = calendar.date(byAdding: .weekOfYear, value: 1, to: start) ?? start
            let inWeek = reactions.filter { $0.timestamp >= start && $0.timestamp < end }
            let avg = inWeek.isEmpty ? 0 : Double(inWeek.map(\.severity).reduce(0, +)) / Double(inWeek.count)
            return SymptomTrendPoint(weekStart: start, reactionCount: inWeek.count, averageSeverity: avg)
        }
    }
}
