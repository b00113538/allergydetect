import XCTest
@testable import Nouri

final class AllergenDatabaseTests: XCTestCase {
    func testCommonMatches() {
        XCTAssertEqual(AllergenDatabase.groups(for: "Parmesan cheese"), [.dairy])
        XCTAssertEqual(AllergenDatabase.groups(for: "Egg noodles"), [.gluten, .eggs])
        XCTAssertEqual(AllergenDatabase.groups(for: "Tiger prawns"), [.shellfish])
        XCTAssertEqual(AllergenDatabase.groups(for: "Hummus"), [.sesame])
        XCTAssertEqual(AllergenDatabase.groups(for: "Soy sauce"), [.gluten, .soy])
        XCTAssertEqual(AllergenDatabase.groups(for: "Mixed nuts"), [.treeNuts])
    }

    func testFalseFriendsAreExcluded() {
        XCTAssertEqual(AllergenDatabase.groups(for: "Peanut butter"), [.peanuts])
        XCTAssertEqual(AllergenDatabase.groups(for: "Coconut milk"), [])
        XCTAssertEqual(AllergenDatabase.groups(for: "Nutmeg"), [])
        XCTAssertEqual(AllergenDatabase.groups(for: "Eggplant"), [])
        XCTAssertEqual(AllergenDatabase.groups(for: "Buckwheat"), [])
        XCTAssertEqual(AllergenDatabase.groups(for: "Rice noodles"), [])
        XCTAssertEqual(AllergenDatabase.groups(for: "Oat milk"), [])
    }

    func testConflictsWithKnownConditions() {
        let ingredients = ["Cheddar cheese", "Bread"].map { AllergenDatabase.annotate(Ingredient(name: $0, confidence: 1, source: .user)) }
        XCTAssertEqual(AllergenDatabase.conflicts(in: ingredients, knownConditions: ["dairy"]), [.dairy])
        XCTAssertEqual(AllergenDatabase.conflicts(in: ingredients, knownConditions: ["milk"]), [.dairy])
        XCTAssertEqual(AllergenDatabase.conflicts(in: ingredients, knownConditions: ["peanuts"]), [])
    }

    func testDineCodeTokenIsLongAndBase62() {
        let a = DineCodeService.makeToken()
        let b = DineCodeService.makeToken()
        XCTAssertEqual(a.count, 22)
        XCTAssertNotEqual(a, b)
        XCTAssertTrue(a.allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber) })
    }
}
