import XCTest
@testable import Nouri

final class SkinPatternDetectionTests: XCTestCase {
    private let uid = "u1"
    private let t0 = Date(timeIntervalSince1970: 1_750_000_000)

    private func log(day: Int, _ exposures: [SkinExposure], reaction: Bool, severity: Int = 3) -> SkinLog {
        SkinLog(userId: uid, timestamp: t0.addingTimeInterval(Double(day) * 86_400), exposures: exposures,
                reactions: reaction ? [.itching] : [.none], severity: severity)
    }

    private let wool = SkinExposure(name: "Wool jumper", kind: .fabric)
    private let cotton = SkinExposure(name: "Cotton t-shirt", kind: .fabric)
    private let cream = SkinExposure(name: "Moisturiser", kind: .product)

    func testFlagsFabricThatReliablyPrecedesReactions() {
        // Wool on 4 days, all itchy; cotton on 4 days, all fine; moisturiser every day.
        var logs: [SkinLog] = []
        for day in 0..<4 { logs.append(log(day: day * 2, [wool, cream], reaction: true)) }
        for day in 0..<4 { logs.append(log(day: day * 2 + 1, [cotton, cream], reaction: false)) }

        let triggers = PatternDetectionService().analyzeSkin(logs: logs)

        let woolScore = triggers.first { $0.ingredient == "Wool jumper" }
        XCTAssertEqual(woolScore?.domain, .fabric)
        XCTAssertEqual(woolScore?.exposures, 4)
        XCTAssertEqual(woolScore?.reactions, 4)
        XCTAssertEqual(woolScore?.baselineRate, 0)
        XCTAssertEqual(woolScore?.status, .likely)
        XCTAssertEqual(triggers.first?.ingredient, "Wool jumper")

        XCTAssertEqual(triggers.first { $0.ingredient == "Cotton t-shirt" }?.status, .unlikely)

        // Used every day: 50% reaction rate and no baseline to compare with — never "likely".
        let creamScore = triggers.first { $0.ingredient == "Moisturiser" }
        XCTAssertEqual(creamScore?.domain, .skin)
        XCTAssertNil(creamScore?.baselineRate)
        XCTAssertNotEqual(creamScore?.status, .likely)
    }

    func testSkinTriggersFeedProfileCategoriesButNotFoodLists() {
        let logs = (0..<4).map { log(day: $0, [wool], reaction: true) } + (4..<7).map { log(day: $0, [cotton], reaction: false) }

        let profile = PatternDetectionService().analyze(meals: [], symptoms: [], skinLogs: logs, userId: uid)

        XCTAssertEqual(profile.triggerCategories, [.fabric])
        XCTAssertTrue(profile.triggerIngredients.isEmpty)
        XCTAssertEqual(profile.likelySkinTriggers.map(\.ingredient), ["Wool jumper"])
    }

    func testSameNameDifferentKindAreScoredSeparatelyAndCaseIsIgnored() {
        let logs = [
            log(day: 0, [SkinExposure(name: "Wool", kind: .fabric)], reaction: true),
            log(day: 1, [SkinExposure(name: "wool", kind: .fabric)], reaction: true),
            log(day: 2, [SkinExposure(name: "Wool", kind: .product)], reaction: false),
        ]

        let triggers = PatternDetectionService().analyzeSkin(logs: logs)

        XCTAssertEqual(triggers.count, 2)
        XCTAssertEqual(triggers.first { $0.domain == .fabric }?.exposures, 2)
        XCTAssertEqual(triggers.first { $0.domain == .skin }?.exposures, 1)
    }

    func testReactionSeverityIsAveragedOverReactionsOnly() {
        let logs = [
            log(day: 0, [wool], reaction: true, severity: 2),
            log(day: 1, [wool], reaction: true, severity: 4),
            log(day: 2, [wool], reaction: false, severity: 5),
        ]
        let woolScore = PatternDetectionService().analyzeSkin(logs: logs).first
        XCTAssertEqual(woolScore?.averageSeverity, 3)
    }
}
