import XCTest
@testable import Nouri

final class ReviewerAccountTests: XCTestCase {
    func testOnlyTheConfiguredEmailMatches() {
        let reviewer = "review@nouri.example"
        XCTAssertTrue(AppEnvironment.isReviewerAccount(email: "review@nouri.example", reviewerEmail: reviewer))
        XCTAssertTrue(AppEnvironment.isReviewerAccount(email: " Review@Nouri.Example ", reviewerEmail: reviewer))
        XCTAssertFalse(AppEnvironment.isReviewerAccount(email: "someone@nouri.example", reviewerEmail: reviewer))
        XCTAssertFalse(AppEnvironment.isReviewerAccount(email: "review@nouri.example.evil", reviewerEmail: reviewer))
        XCTAssertFalse(AppEnvironment.isReviewerAccount(email: nil, reviewerEmail: reviewer))
    }

    func testDisabledWhenNotConfigured() {
        XCTAssertFalse(AppEnvironment.isReviewerAccount(email: "review@nouri.example", reviewerEmail: ""))
        XCTAssertFalse(AppEnvironment.isReviewerAccount(email: "", reviewerEmail: ""))
    }

    /// Test builds don't set NOURI_REVIEWER_EMAIL, so no real account can load sample data.
    func testDefaultBuildHasNoReviewerAccount() {
        XCTAssertEqual(AppEnvironment.reviewerEmail, "")
    }

    @MainActor
    func testSampleHistoryIsOfferedOnlyToAnEmptyDemoOrReviewerAccount() async throws {
        // A saved local account, loaded the way a relaunch would (skips onboarding's permission prompt).
        let database = try LocalDatabase()
        let app = AppState(database: database, firebase: nil, vision: DemoVisionService())
        app.startDemoAccount(name: "Sam")
        let uid = try XCTUnwrap(app.pendingAccount?.uid)
        try database.save(User(id: uid, name: "Sam", email: "", dateOfBirth: nil, knownConditions: [],
                               symptomHistory: nil, createdAt: .now))
        await app.bootstrap()
        XCTAssertEqual(app.phase, .ready)

        XCTAssertTrue(app.canLoadSampleData)          // demo mode, empty account
        app.loadSampleData()
        XCTAssertFalse(app.meals.isEmpty)
        XCTAssertFalse(app.skinLogs.isEmpty)
        XCTAssertEqual(app.bloodwork.count, 1)
        XCTAssertFalse(app.canLoadSampleData)         // not offered twice
        let mealCount = app.meals.count
        app.loadSampleData()
        XCTAssertEqual(app.meals.count, mealCount)    // and a second call is a no-op

        await app.signOut()                           // leave no local account behind for other tests
    }
}
