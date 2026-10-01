import XCTest

/// Captures the App Store screenshots in the order they should appear on the listing.
/// Run by `.github/workflows/nouri-screenshots.yml` on a 6.9" iPhone simulator with a 9:41 status bar.
/// Each image is attached to the test result and, when `NOURI_SCREENSHOT_DIR` is set, written there.
final class AppStoreScreenshots: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments += ["-NouriScreenshots", "-AppleLanguages", "(en)", "-AppleLocale", "en_GB"]
        app.launch()
    }

    func testCaptureAppStoreScreenshots() throws {
        // 1. Today: greeting, quick log, check-in card, recent activity.
        XCTAssertTrue(app.staticTexts["Recent"].waitForExistence(timeout: 20))
        snap("01-today")

        // 2. Insights → Food: allergen groups and ingredient triggers.
        app.tabBars.buttons["Insights"].tap()
        XCTAssertTrue(app.staticTexts["Allergen groups"].waitForExistence(timeout: 10))
        snap("02-insights-food")

        // 3. Trigger detail: the numbers behind the score.
        button(startingWith: "Dairy").tap()
        XCTAssertTrue(app.staticTexts["Reaction rate"].waitForExistence(timeout: 10))
        snap("03-trigger-detail")
        app.buttons["Done"].tap()

        // 4. Insights → Blood work: test results compared with the logs.
        app.segmentedControls.buttons["Blood work"].tap()
        XCTAssertTrue(app.staticTexts["Blood test vs. your logs"].waitForExistence(timeout: 10))
        snap("04-blood-work")

        // 5. Insights → Skin: ingredient groups and fabrics.
        app.segmentedControls.buttons["Skin"].tap()
        XCTAssertTrue(app.staticTexts["Products & fabrics"].waitForExistence(timeout: 10))
        snap("05-skin")

        // 6. Log a meal: AI ingredient review with allergen flags (demo analysis, no camera).
        app.tabBars.buttons["Today"].tap()
        app.buttons["quicklog-meal"].tap()
        XCTAssertTrue(app.staticTexts["Parmesan cheese"].waitForExistence(timeout: 10))
        snap("06-log-meal")
        app.buttons["Cancel"].tap()

        // 7. Dine Code: the QR restaurants scan.
        app.tabBars.buttons["Dine Code"].tap()
        let generate = app.buttons["Generate my Dine Code"]
        if generate.waitForExistence(timeout: 5) { generate.tap() }
        XCTAssertTrue(app.staticTexts["Show this to restaurant staff"].waitForExistence(timeout: 10))
        snap("07-dine-code")
    }

    // MARK: Helpers

    private func button(startingWith prefix: String) -> XCUIElement {
        let match = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", prefix)).firstMatch
        XCTAssertTrue(match.waitForExistence(timeout: 10), "No button starting with \(prefix)")
        return match
    }

    private func snap(_ name: String) {
        // Let animations and async images settle.
        Thread.sleep(forTimeInterval: 1.0)
        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        if let dir = ProcessInfo.processInfo.environment["NOURI_SCREENSHOT_DIR"], !dir.isEmpty {
            let url = URL(fileURLWithPath: dir).appendingPathComponent("\(name).png")
            try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try? screenshot.pngRepresentation.write(to: url)
        }
    }
}
