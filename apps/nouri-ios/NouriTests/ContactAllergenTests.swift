import XCTest
@testable import Nouri

final class ContactAllergenTests: XCTestCase {
    private func groups(_ text: String) -> Set<ContactAllergenGroup> { Set(ContactAllergenDatabase.groups(for: text)) }

    func testINCINamesMapToGroups() {
        XCTAssertEqual(groups("Parfum"), [.fragrance])
        XCTAssertEqual(groups("Linalool"), [.fragrance])
        XCTAssertEqual(groups("Hexyl Cinnamal"), [.fragrance])
        XCTAssertEqual(groups("Methylchloroisothiazolinone"), [.isothiazolinones])
        XCTAssertEqual(groups("DMDM Hydantoin"), [.formaldehydeReleasers])
        XCTAssertEqual(groups("2-Bromo-2-Nitropropane-1,3-Diol"), [.formaldehydeReleasers])
        XCTAssertEqual(groups("Quaternium-15"), [.formaldehydeReleasers])
        XCTAssertEqual(groups("Methylparaben"), [.parabens])
        XCTAssertEqual(groups("Sodium Lauryl Sulfate"), [.surfactants])
        XCTAssertEqual(groups("p-Phenylenediamine"), [.hairDye])
        XCTAssertEqual(groups("Toluene-2,5-Diamine"), [.hairDye])
        XCTAssertEqual(groups("Melaleuca Alternifolia Leaf Oil"), [.essentialOils])
        XCTAssertEqual(groups("Lanolin Alcohol"), [.lanolin])
    }

    func testFabricAndMaterialNames() {
        XCTAssertEqual(groups("Wool jumper"), [.wool])
        XCTAssertEqual(groups("80% Merino"), [.wool])
        XCTAssertEqual(groups("Polyamide"), [.syntheticFibres])
        XCTAssertEqual(groups("Nickel earrings"), [.nickel])
        XCTAssertEqual(groups("Latex gloves"), [.latex])
    }

    func testExclusionsAndLookalikes() {
        XCTAssertTrue(groups("Fragrance free").isEmpty)
        XCTAssertEqual(groups("Wool Alcohol"), [.lanolin])          // lanolin, not the fibre
        XCTAssertTrue(groups("Cotton wool pads").isEmpty)
        XCTAssertTrue(groups("Acrylates Copolymer").isEmpty)        // not acrylic fibre
        XCTAssertTrue(groups("Glycerin").isEmpty)
        XCTAssertTrue(groups("Aqua").isEmpty)
    }

    func testExposureCombinesNameAndLabel() {
        let lotion = SkinExposure(name: "Body lotion", kind: .product, ingredients: ["Aqua", "Parfum", "Methylparaben"])
        XCTAssertEqual(lotion.contactGroups, [.fragrance, .parabens])
        XCTAssertEqual(SkinExposure(name: "Wool socks", kind: .fabric).contactGroups, [.wool])
    }

    func testFragranceIsFlaggedAcrossDifferentProducts() {
        let t0 = Date(timeIntervalSince1970: 1_750_000_000)
        func log(_ day: Int, _ exposures: [SkinExposure], reaction: Bool) -> SkinLog {
            SkinLog(userId: "u1", timestamp: t0.addingTimeInterval(Double(day) * 86_400), exposures: exposures,
                    reactions: reaction ? [.rash] : [.none], severity: 3)
        }
        let lotion = SkinExposure(name: "Lotion", kind: .product, ingredients: ["Aqua", "Parfum"])
        let shampoo = SkinExposure(name: "Shampoo", kind: .product, ingredients: ["Aqua", "Linalool"])
        let detergent = SkinExposure(name: "Detergent", kind: .product, ingredients: ["Limonene"])
        let plain = SkinExposure(name: "Plain soap", kind: .product, ingredients: ["Sodium Palmate"])
        let logs = [
            log(0, [lotion], reaction: true), log(1, [shampoo], reaction: true), log(2, [detergent], reaction: true),
            log(3, [plain], reaction: false), log(4, [plain], reaction: false), log(5, [plain], reaction: false),
        ]

        let service = PatternDetectionService()
        // No single product has enough exposures to be judged...
        XCTAssertFalse(service.analyzeSkin(logs: logs).contains { $0.status == .likely })
        // ...but together they make fragrance a likely trigger.
        let fragrance = service.analyzeSkinGroups(logs: logs).first { $0.contactGroup == .fragrance }
        XCTAssertEqual(fragrance?.exposures, 3)
        XCTAssertEqual(fragrance?.reactions, 3)
        XCTAssertEqual(fragrance?.status, .likely)
        XCTAssertEqual(fragrance?.domain, .skin)

        let profile = service.analyze(meals: [], symptoms: [], skinLogs: logs, userId: "u1")
        XCTAssertEqual(profile.likelySkinGroups.compactMap(\.contactGroup), [.fragrance])
        XCTAssertEqual(profile.triggerCategories, [.skin])
    }

    func testLabelPayloadDecoding() throws {
        let json = """
        {"productName": " Brand X Lotion ", "kind": "product", "notes": "",
         "ingredients": [{"name": "Aqua", "percent": -1}, {"name": "Parfum", "percent": -1},
                         {"name": "parfum", "percent": -1}, {"name": "Linalool", "percent": -1}]}
        """
        let label = try JSONDecoder().decode(ClaudeProductLabelService.Payload.self, from: Data(json.utf8)).label
        XCTAssertEqual(label.productName, "Brand X Lotion")
        XCTAssertEqual(label.ingredients, ["Aqua", "Parfum", "Linalool"])
        XCTAssertTrue(label.percentages.isEmpty)
        XCTAssertEqual(label.flagged.map(\.group), [.fragrance])
        XCTAssertEqual(label.flagged.first?.ingredients, ["Parfum", "Linalool"])

        let fabric = """
        {"productName": "", "kind": "fabric", "notes": "",
         "ingredients": [{"name": "Wool", "percent": 80}, {"name": "Polyamide", "percent": 20}]}
        """
        let care = try JSONDecoder().decode(ClaudeProductLabelService.Payload.self, from: Data(fabric.utf8)).label
        XCTAssertEqual(care.kind, .fabric)
        XCTAssertEqual(care.percentages["Wool"], 80)
        XCTAssertEqual(care.flagged.map(\.group), [.wool, .syntheticFibres])
    }
}
