import Foundation

enum AppEnvironment {
    /// Firebase is only configured when `GoogleService-Info.plist` is bundled. Without it the app
    /// runs in **demo mode**: local-only storage, a local account, and a canned vision result —
    /// handy for investor demos on a device with no backend set up.
    static let isFirebaseConfigured: Bool =
        Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") != nil

    /// Where Dine Code QR codes point. Set `NouriDineCodeBaseURL` in Info.plist (see project.yml).
    /// Pages on the same Firebase Hosting site (`firebase/hosting/`), e.g. "privacy", "support".
    static func webPage(_ path: String) -> URL {
        URL(string: "/\(path)", relativeTo: dineCodeBaseURL)?.absoluteURL ?? dineCodeBaseURL
    }

    static var dineCodeBaseURL: URL {
        let raw = Bundle.main.object(forInfoDictionaryKey: "NouriDineCodeBaseURL") as? String
        return URL(string: raw ?? "") ?? URL(string: "https://nouri-app.web.app/d/")!
    }
}
