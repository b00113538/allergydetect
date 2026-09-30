import XCTest
@testable import Nouri

/// Round-trips phase 6 records through SQLite, which exercises the v2 migration and the JSON columns.
final class LocalDatabaseTests: XCTestCase {
    func testSkinLogRoundTrip() throws {
        let db = try LocalDatabase()
        let log = SkinLog(userId: "u1", timestamp: Date(timeIntervalSince1970: 1_750_000_000),
                          exposures: [SkinExposure(name: "Wool jumper", kind: .fabric),
                                      SkinExposure(name: "Sunscreen", kind: .product, ingredients: ["Aqua", "Parfum"])],
                          reactions: [.itching, .redness], bodyAreas: [.arms], severity: 3, notes: "after the gym")
        try db.save(log)

        XCTAssertEqual(try db.skinLogs(userId: "u1"), [log])
        XCTAssertEqual(try db.unsyncedSkinLogs().map(\.id), [log.id])

        try db.markSynced(skinLogId: log.id, photoURL: "https://example.com/p.jpg")
        let synced = try XCTUnwrap(db.skinLogs(userId: "u1").first)
        XCTAssertFalse(synced.needsSync)
        XCTAssertEqual(synced.photoURL, "https://example.com/p.jpg")

        try db.deleteSkinLog(id: log.id)
        XCTAssertTrue(try db.skinLogs(userId: "u1").isEmpty)
    }

    func testBloodworkRoundTrip() throws {
        let db = try LocalDatabase()
        let record = BloodworkRecord(userId: "u1", testDate: Date(timeIntervalSince1970: 1_750_000_000), labName: "City Lab",
                                     panelResults: [.init(allergen: "Peanut", igeLevel: 0.1, comparator: .lessThan),
                                                    .init(allergen: "Cow's milk", igeLevel: 8.2, igeClass: 3)],
                                     localDocName: "x.pdf", sourceDocType: .pdf, notes: "fasting")
        try db.save(record)

        XCTAssertEqual(try db.bloodwork(userId: "u1"), [record])
        try db.markSynced(bloodworkId: record.id, sourceDocURL: "https://example.com/x.pdf")
        XCTAssertEqual(try db.bloodwork(userId: "u1").first?.sourceDocURL, "https://example.com/x.pdf")
        XCTAssertTrue(try db.unsyncedBloodwork().isEmpty)
    }

    func testProfileWithSkinTriggersRoundTrip() throws {
        let db = try LocalDatabase()
        let logs = (0..<3).map { day in
            SkinLog(userId: "u1", timestamp: Date(timeIntervalSince1970: Double(day) * 86_400),
                    exposures: [SkinExposure(name: "Wool", kind: .fabric)], reactions: [.rash], severity: 2)
        }
        let profile = PatternDetectionService().analyze(meals: [], symptoms: [], skinLogs: logs, userId: "u1")
        try db.save(profile)
        XCTAssertEqual(try db.allergyProfile(userId: "u1")?.skinTriggers, profile.skinTriggers)
        XCTAssertEqual(try db.allergyProfile(userId: "u1")?.skinGroupTriggers, profile.skinGroupTriggers)
        XCTAssertEqual(profile.skinGroupTriggers.first?.contactGroup, .wool)
    }
}
