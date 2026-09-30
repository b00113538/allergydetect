import XCTest
@testable import Nouri

final class BloodworkTests: XCTestCase {
    typealias Result = BloodworkRecord.PanelResult

    func testIgEClassBoundaries() {
        XCTAssertEqual(IgEScale.igeClass(forLevel: 0.1), 0)
        XCTAssertEqual(IgEScale.igeClass(forLevel: 0.34), 0)
        XCTAssertEqual(IgEScale.igeClass(forLevel: 0.35), 1)
        XCTAssertEqual(IgEScale.igeClass(forLevel: 0.7), 2)
        XCTAssertEqual(IgEScale.igeClass(forLevel: 3.49), 2)
        XCTAssertEqual(IgEScale.igeClass(forLevel: 3.5), 3)
        XCTAssertEqual(IgEScale.igeClass(forLevel: 17.5), 4)
        XCTAssertEqual(IgEScale.igeClass(forLevel: 50), 5)
        XCTAssertEqual(IgEScale.igeClass(forLevel: 100), 6)
        XCTAssertEqual(IgEScale.igeClass(forLevel: 0.35, comparator: .lessThan), 0)
        XCTAssertEqual(IgEScale.igeClass(forLevel: 100, comparator: .greaterThan), 6)
    }

    func testReportedClassWinsOverDerivedClass() {
        let result = Result(allergen: "Peanut", igeLevel: 0.5, igeClass: 2)
        XCTAssertEqual(result.effectiveClass, 2)
        XCTAssertTrue(result.isSensitised)
        XCTAssertFalse(Result(allergen: "Peanut", igeLevel: 0.1).isSensitised)
    }

    func testLabAllergenNamesMapToFoodGroups() {
        XCTAssertEqual(Result(allergen: "Cow's milk", igeLevel: 1).allergenGroups, [.dairy])
        XCTAssertEqual(Result(allergen: "Egg white", igeLevel: 1).allergenGroups, [.eggs])
        XCTAssertEqual(Result(allergen: "Peanut", igeLevel: 1).allergenGroups, [.peanuts])
        XCTAssertEqual(Result(allergen: "Codfish", igeLevel: 1).allergenGroups, [.fish])
        XCTAssertEqual(Result(allergen: "Shrimp", igeLevel: 1).allergenGroups, [.shellfish])
        XCTAssertTrue(Result(allergen: "Dermatophagoides pteronyssinus", igeLevel: 1).allergenGroups.isEmpty)
    }

    func testPayloadDecodingNormalisesModelOutput() throws {
        let json = """
        {"testDate": "2026-03-14", "labName": "City Lab", "notes": "",
         "results": [
            {"allergen": "cow's milk", "value": 8.2, "comparator": "=", "unit": "kUA/L", "reportedClass": 3},
            {"allergen": "Peanut", "value": 0.1, "comparator": "<", "unit": "kU/L", "reportedClass": -1},
            {"allergen": "Cow's Milk", "value": 8.2, "comparator": "=", "unit": "kU/L", "reportedClass": 3},
            {"allergen": "Shrimp", "value": 1.4, "comparator": "=", "unit": "ng/mL", "reportedClass": 9}
         ]}
        """
        let extraction = try JSONDecoder().decode(ClaudeBloodworkService.Payload.self, from: Data(json.utf8)).extraction

        XCTAssertEqual(extraction.labName, "City Lab")
        XCTAssertEqual(extraction.testDate.map { Calendar.current.dateComponents([.year, .month, .day], from: $0) },
                       DateComponents(year: 2026, month: 3, day: 14))
        XCTAssertEqual(extraction.results.map(\.allergen), ["Cow's milk", "Peanut", "Shrimp"])   // duplicate dropped
        XCTAssertEqual(extraction.results[0].igeClass, 3)
        XCTAssertEqual(extraction.results[1].comparator, .lessThan)
        XCTAssertNil(extraction.results[1].igeClass)
        XCTAssertEqual(extraction.results[1].effectiveClass, 0)
        XCTAssertNil(extraction.results[2].igeClass)                                               // out of range
        XCTAssertTrue(extraction.notes.contains("ng/mL"))                                          // unit warning
    }

    func testDraftParsesBoundsAsTyped() {
        XCTAssertEqual(BloodworkDraft.Row.parse("<0.10")?.value, 0.1)
        XCTAssertEqual(BloodworkDraft.Row.parse("<0.10")?.comparator, .lessThan)
        XCTAssertEqual(BloodworkDraft.Row.parse(" 3,5 ")?.value, 3.5)
        XCTAssertNil(BloodworkDraft.Row.parse("abc"))
        XCTAssertNil(BloodworkDraft(BloodworkExtraction(testDate: nil, labName: nil, results: [], notes: "")).rows.first?.panelResult)
    }

    // MARK: - Cross-reference

    private func trigger(_ name: String, groups: [AllergenGroup], status: TriggerStatus) -> TriggerIngredient {
        TriggerIngredient(ingredient: name, domain: .food, confidence: 0.8, exposures: 5, reactions: 4, baselineRate: 0.1,
                          averageSeverity: 3, status: status, allergenGroups: groups)
    }

    func testFindingsCompareBloodTestWithLoggedPatterns() {
        var profile = AllergyProfile.empty(userId: "u1")
        profile.triggerGroups = [trigger("Dairy", groups: [.dairy], status: .likely),
                                 trigger("Gluten", groups: [.gluten], status: .watching)]
        profile.triggerIngredients = [trigger("Parmesan cheese", groups: [.dairy], status: .likely)]
        let record = BloodworkRecord(userId: "u1", testDate: .now, panelResults: [
            Result(allergen: "Cow's milk", igeLevel: 8.2),
            Result(allergen: "Dust mite", igeLevel: 2.1),
            Result(allergen: "Wheat", igeLevel: 0.2),
            Result(allergen: "Peanut", igeLevel: 0.1, comparator: .lessThan),
        ])

        let findings = BloodworkInsights.findings(records: [record], profile: profile)

        XCTAssertEqual(findings.map(\.kind), [.agrees, .sensitisedOnly, .patternOnly])
        XCTAssertEqual(findings[0].allergen, "Cow's milk")
        XCTAssertEqual(findings[0].trigger?.ingredient, "Dairy")
        XCTAssertEqual(findings[1].allergen, "Dust mite")
        XCTAssertEqual(findings[2].allergen, "Gluten")          // logs flag it, wheat IgE negative
    }

    func testLatestResultPerAllergenWins() {
        let old = BloodworkRecord(userId: "u1", testDate: Date(timeIntervalSince1970: 0),
                                  panelResults: [Result(allergen: "Peanut", igeLevel: 5)])
        let new = BloodworkRecord(userId: "u1", testDate: Date(timeIntervalSince1970: 1_000_000),
                                  panelResults: [Result(allergen: "peanuts", igeLevel: 0.2)])
        let latest = BloodworkInsights.latestResults([new, old])
        XCTAssertEqual(latest.count, 1)
        XCTAssertEqual(latest.first?.result.igeLevel, 0.2)
    }

    func testDineCodeIncludesModerateFoodResultsOnly() {
        let user = User(id: "u1", name: "Sam Lee", email: "", dateOfBirth: nil, knownConditions: [],
                        symptomHistory: nil, createdAt: .now)
        let record = BloodworkRecord(userId: "u1", testDate: .now, panelResults: [
            Result(allergen: "Cow's milk", igeLevel: 8.2),   // class 3, food → included
            Result(allergen: "Shrimp", igeLevel: 0.5),       // class 1 → left off
            Result(allergen: "Dust mite", igeLevel: 20),     // not a food → left off
        ])
        let snapshot = DineCodeService.snapshot(user: user, profile: nil, bloodwork: [record])
        XCTAssertEqual(snapshot.avoid.map(\.name), ["Cow's milk"])
        XCTAssertEqual(snapshot.avoid.first?.level, "Positive blood test")
    }
}
