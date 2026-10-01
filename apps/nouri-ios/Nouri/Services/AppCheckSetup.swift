import Foundation
import DeviceCheck
import FirebaseCore
import FirebaseAppCheck

/// Firebase App Check: proves requests come from the genuine Nouri app on a real Apple device, so the
/// Cloud Functions (which spend Claude credits) can't be scripted. The server enforces it on every
/// callable (`ENFORCE_APP_CHECK`, see functions/src/appCheck.ts); Firebase SDKs attach tokens automatically.
///
/// - Release builds on real devices: App Attest, falling back to DeviceCheck where App Attest isn't supported.
/// - Simulator and debug builds: the debug provider. On first launch it prints a token to the Xcode
///   console ("Firebase App Check debug token: …") — add it in Firebase console → App Check → Apps →
///   Manage debug tokens once per simulator/device.
final class NouriAppCheckProviderFactory: NSObject, AppCheckProviderFactory {
    func createProvider(with app: FirebaseApp) -> AppCheckProvider? {
        #if targetEnvironment(simulator) || DEBUG
        return AppCheckDebugProvider(app: app)
        #else
        if DCAppAttestService.shared.isSupported {
            return AppAttestProvider(app: app)
        }
        return DeviceCheckProvider(app: app)
        #endif
    }
}

enum AppCheckSetup {
    /// Must run before `FirebaseApp.configure()`.
    static func install() {
        AppCheck.setAppCheckProviderFactory(NouriAppCheckProviderFactory())
    }
}
