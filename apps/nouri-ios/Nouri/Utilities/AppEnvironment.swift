import Foundation

enum AppEnvironment {
    /// Firebase is only configured when `GoogleService-Info.plist` is bundled. Without it the app
    /// runs in **demo mode**: local-only storage, a local account, and a canned vision result —
    /// handy for investor demos on a device with no backend set up.
    static let isFirebaseConfigured: Bool =
        Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") != nil

    /// Where Dine Code QR codes point. Set `NouriDineCodeBaseURL` in Info.plist (see project.yml).
    /// Launched by the screenshot UI test (`-NouriScreenshots`): in-memory demo data, no prompts.
    static let isScreenshotMode = ProcessInfo.processInfo.arguments.contains("-NouriScreenshots")

    /// Email of the App Review demo account (`NouriReviewerEmail` in Info.plist; empty = none).
    static var reviewerEmail: String {
        (Bundle.main.object(forInfoDictionaryKey: "NouriReviewerEmail") as? String ?? "").trimmingCharacters(in: .whitespaces)
    }

    /// True when `email` is the configured reviewer account. Exact match (case-insensitive) only.
    static func isReviewerAccount(email: String?, reviewerEmail: String = reviewerEmail) -> Bool {
        guard let email = email?.trimmingCharacters(in: .whitespaces), !email.isEmpty, !reviewerEmail.isEmpty else { return false }
        return email.caseInsensitiveCompare(reviewerEmail) == .orderedSame
    }

    /// Pages on the same Firebase Hosting site (`firebase/hosting/`), e.g. "privacy", "support".
    static func webPage(_ path: String) -> URL {
        URL(string: "/\(path)", relativeTo: dineCodeBaseURL)?.absoluteURL ?? dineCodeBaseURL
    }

    static var dineCodeBaseURL: URL {
        let raw = Bundle.main.object(forInfoDictionaryKey: "NouriDineCodeBaseURL") as? String
        return URL(string: raw ?? "") ?? URL(string: "https://nouri-app.web.app/d/")!
    }
}
