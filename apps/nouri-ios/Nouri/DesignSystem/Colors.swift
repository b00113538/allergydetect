import SwiftUI

/// Nouri palette — single source of truth is `Assets.xcassets` (each colour set has a light and a
/// dark variant), ported from the investor mockup (`nouri_investor_mockup.html`).
///
/// Light: cream background, sage green primary, gold accent.
/// Dark:  deep emerald #10231E background, emerald #3E9B82 primary, antique gold #CDAD5E accent,
///        off-white #E8EFE8 text.
extension Color {
    static let nouriBackground = Color("NouriBackground")
    static let nouriSurface = Color("NouriSurface")
    static let nouriSurfaceMuted = Color("NouriSurfaceMuted")
    static let nouriPrimary = Color("NouriPrimary")
    static let nouriOnPrimary = Color("NouriOnPrimary")
    static let nouriAccent = Color("NouriAccent")
    static let nouriTextPrimary = Color("NouriTextPrimary")
    static let nouriTextSecondary = Color("NouriTextSecondary")
    static let nouriBorder = Color("NouriBorder")
    static let nouriDanger = Color("NouriDanger")
    static let nouriWarning = Color("NouriWarning")
    static let nouriSuccess = Color("NouriSuccess")
}

extension TriggerStatus {
    var color: Color {
        switch self {
        case .likely: .nouriDanger
        case .watching: .nouriWarning
        case .unlikely: .nouriSuccess
        }
    }
}

extension Int {
    /// Severity 1–5 → colour.
    var severityColor: Color {
        switch self {
        case ...2: .nouriSuccess
        case 3: .nouriWarning
        default: .nouriDanger
        }
    }
}
