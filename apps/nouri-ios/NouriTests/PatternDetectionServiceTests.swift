import XCTest
@testable import Nouri

final class PatternDetectionServiceTests: XCTestCase {
    private let uid = "u1"
    private let t0 = Date(timeIntervalSince1970: 1_750_000_000)

    private func meal(_ id: String, hoursFromStart: Double, _ ingredients: [String]) -> MealEntry {
        MealEntry(id: id, userId: uid, timestamp: t0.addingTimeInterval(hoursFromStart * 3600),
                  ingredients: ingredients.map { AllergenDatabase.annotate(Ingredient(name: $0, confidence: 0.9, source: .ai)) },
                  mealType: .lunch)
    }

    private func symptom(hoursFromStart: Double, severity: Int = 3, mealId: String? = nil, types: [SymptomType] = [.mucus]) -> SymptomLog {
        SymptomLog(userId: uid, mealEntryId: mealId, timestamp: t0.addingTimeInterval(hoursFromStart * 3600),
                   symptomTypes: types, severity: severity)
    }

    func testFlagsIngredientThatReliablyPrecedesSymptoms() {
        // Four cheese meals (days 0–3), each followed by a reaction 3h later; four clean meals without cheese.
        var meals: [MealEntry] = []
        var logs: [SymptomLog] = []
        for day in 0..<4 {
            meals.append(meal("c\(day)", hoursFromStart: Double(day * 24), ["Cheddar cheese", "Bread"]))
            logs.append(symptom(hoursFromStart: Double(day * 24) + 3))
            meals.append(meal("r\(day)", hoursFromStart: Double(day * 24) + 12, ["Rice", "Chicken", "Bread"]))
        }

        let profile = PatternDetectionService().analyze(meals: meals, symptoms: logs, userId: uid)

        let cheese = profile.triggerIngredients.first { $0.ingredient == "Cheddar cheese" }
        XCTAssertEqual(cheese?.exposures, 4)
        XCTAssertEqual(cheese?.reactions, 4)
        XCTAssertEqual(cheese?.status, .likely)
        XCTAssertEqual(cheese?.baselineRate, 0)
        XCTAssertEqual(profile.triggerIngredients.first?.ingredient, "Cheddar cheese")

        let rice = profile.triggerIngredients.first { $0.ingredient == "Rice" }
        XCTAssertEqual(rice?.reactions, 0)
        XCTAssertEqual(rice?.status, .unlikely)

        // Bread is in every meal: no baseline to compare against, so it can only be "watching".
        let bread = profile.triggerIngredients.first { $0.ingredient == "Bread" }
        XCTAssertNil(bread?.baselineRate)
        XCTAssertEqual(bread?.status, .watching)

        let dairy = profile.triggerGroups.first { $0.allergenGroups == [.dairy] }
        XCTAssertEqual(dairy?.status, .likely)
        XCTAssertEqual(profile.triggerCategories, [.food])
    }

    func testRequiresMinimumExposures() {
        let meals = [meal("a", hoursFromStart: 0, ["Shrimp"]), meal("b", hoursFromStart: 24, ["Shrimp"])]
        let logs = [symptom(hoursFromStart: 2), symptom(hoursFromStart: 26)]
        let shrimp = PatternDetectionService().analyze(meals: meals, symptoms: logs, userId: uid).triggerIngredients.first
        XCTAssertEqual(shrimp?.reactions, 2)
        XCTAssertEqual(shrimp?.status, .watching, "2 exposures is below the 3-meal threshold")
    }

    func testSymptomsOutsideWindowAreIgnored() {
        let meals = [meal("a", hoursFromStart: 0, ["Egg"])]
        let logs = [symptom(hoursFromStart: 9), symptom(hoursFromStart: -1)]
        let outcomes = PatternDetectionService().mealOutcomes(meals: meals, symptoms: logs)
        XCTAssertFalse(outcomes[0].reacted)
    }

    func testExplicitLinkOverridesWindowAndNoneLogIsNegative() {
        let meals = [meal("a", hoursFromStart: 0, ["Peanuts"]), meal("b", hoursFromStart: 1, ["Apple"])]
        let logs = [
            symptom(hoursFromStart: 10, severity: 4, mealId: "a"),              // outside window but linked
            symptom(hoursFromStart: 2, mealId: nil, types: [.none]),            // "feel fine" – not a reaction
        ]
        let outcomes = PatternDetectionService().mealOutcomes(meals: meals, symptoms: logs)
        XCTAssertTrue(outcomes[0].reacted)
        XCTAssertEqual(outcomes[0].severity, 4)
        XCTAssertFalse(outcomes[1].reacted, "a log linked to another meal must not be attributed to this one")
    }

    func testUbiquitousIngredientIsNotBlamed() {
        // Salt is in 8 of 10 meals and reacts at exactly the baseline rate (50%) → no lift.
        // Milk (every even meal) is followed by a reaction every time.
        var meals: [MealEntry] = []
        var logs: [SymptomLog] = []
        for i in 0..<10 {
            let base = Double(i * 24)
            var ingredients = i.isMultiple(of: 2) ? ["Milk"] : ["Rice"]
            if i < 8 { ingredients.append("Salt") }
            meals.append(meal("m\(i)", hoursFromStart: base, ingredients))
            if i.isMultiple(of: 2) { logs.append(symptom(hoursFromStart: base + 2)) }
        }
        let profile = PatternDetectionService().analyze(meals: meals, symptoms: logs, userId: uid)
        XCTAssertEqual(profile.triggerIngredients.first { $0.ingredient == "Salt" }?.status, .unlikely)
        XCTAssertEqual(profile.triggerIngredients.first { $0.ingredient == "Milk" }?.status, .likely)
    }

    func testCanonicalKeyMergesPluralsAndCase() {
        let meals = [meal("a", hoursFromStart: 0, ["Tomatoes"]), meal("b", hoursFromStart: 24, ["tomato"]),
                     meal("c", hoursFromStart: 48, ["TOMATO"])]
        let profile = PatternDetectionService().analyze(meals: meals, symptoms: [], userId: uid)
        XCTAssertEqual(profile.triggerIngredients.count, 1)
        XCTAssertEqual(profile.triggerIngredients.first?.exposures, 3)
    }

    func testWeeklyTrendIncludesEmptyWeeks() {
        let now = t0.addingTimeInterval(60 * 24 * 3600)
        let points = PatternDetectionService.weeklyTrend(symptoms: [symptom(hoursFromStart: 60 * 24 - 1, severity: 5)], weeks: 4, now: now)
        XCTAssertEqual(points.count, 4)
        XCTAssertEqual(points.map(\.reactionCount).reduce(0, +), 1)
        XCTAssertEqual(points.last?.averageSeverity, 5)
    }
}
