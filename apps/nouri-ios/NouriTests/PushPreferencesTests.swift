import XCTest
@testable import Nouri

final class PushPreferencesTests: XCTestCase {
    /// Same cases as `firebase/functions/test/pushLogic.test.ts` — the app writes the value the job queries.
    func testUtcHourMatchesServerConversion() {
        XCTAssertEqual(PushPreferences.utcHour(localHour: 20, offsetMinutes: 0), 20)
        XCTAssertEqual(PushPreferences.utcHour(localHour: 20, offsetMinutes: 240), 16)
        XCTAssertEqual(PushPreferences.utcHour(localHour: 20, offsetMinutes: -300), 1)
        XCTAssertEqual(PushPreferences.utcHour(localHour: 20, offsetMinutes: 330), 14)
        XCTAssertEqual(PushPreferences.utcHour(localHour: 1, offsetMinutes: 240), 21)
    }

    func testDeviceFieldsUseTheCurrentOffset() throws {
        let dubai = try XCTUnwrap(TimeZone(identifier: "Asia/Dubai"))
        var prefs = PushPreferences()
        prefs.reminderHour = 21
        prefs.weeklySummary = false

        let fields = prefs.deviceFields(timeZone: dubai, now: Date(timeIntervalSince1970: 1_750_000_000))

        XCTAssertEqual(fields["utcOffsetMinutes"] as? Int, 240)
        XCTAssertEqual(fields["reminderHour"] as? Int, 21)
        XCTAssertEqual(fields["reminderUtcHour"] as? Int, 17)
        XCTAssertEqual(fields["timeZone"] as? String, "Asia/Dubai")
        XCTAssertEqual(fields["weeklySummary"] as? Bool, false)
        XCTAssertEqual(fields["dailyReminder"] as? Bool, true)
    }

    func testDeviceFieldsFollowDaylightSaving() throws {
        let london = try XCTUnwrap(TimeZone(identifier: "Europe/London"))
        let winter = Date(timeIntervalSince1970: 1_768_000_000)   // January
        let summer = Date(timeIntervalSince1970: 1_750_000_000)   // June
        XCTAssertEqual(PushPreferences().deviceFields(timeZone: london, now: winter)["reminderUtcHour"] as? Int, 20)
        XCTAssertEqual(PushPreferences().deviceFields(timeZone: london, now: summer)["reminderUtcHour"] as? Int, 19)
    }

    func testPreferencesPersist() throws {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: "PushPreferencesTests"))
        defaults.removePersistentDomain(forName: "PushPreferencesTests")
        XCTAssertEqual(PushPreferences.load(from: defaults), PushPreferences())

        let custom = PushPreferences(dailyReminder: false, weeklySummary: true, reminderHour: 18)
        custom.save(to: defaults)
        XCTAssertEqual(PushPreferences.load(from: defaults), custom)
    }
}
