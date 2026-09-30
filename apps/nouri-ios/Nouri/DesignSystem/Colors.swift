import SwiftUI

/// Nouri palette. The single source of truth is `Assets.xcassets`, where each colour set has a light
/// and a dark variant.
///
/// Light: cream background, sage primary, gold accent.
/// Dark:  deep emerald #10231E background, emerald #3E9B82 primary, antique gold #CDAD5E accent,
///        off-white #E8EFE8 text (from the brand spec).
///
/// Fill vs text: `nouriPrimary` / `nouriAccent` are the brand fills — buttons, bars, icons, large
/// headings. Anything small and coloured (links, captions, tags, selected chips) uses the `…Text`
/// variants, which meet WCAG AA 4.5:1 on the background, the surface and their own 14% tag tint in
/// both appearances. Status colours (danger/warning/success) are used as text too, so they meet it directly.
extension Color {
    static let nouriBackground = Color("NouriBackground")
    static let nouriSurface = Color("NouriSurface")
    static let nouriSurfaceMuted = Color("NouriSurfaceMuted")
    static let nouriPrimary = Color("NouriPrimary")
    static let nouriOnPrimary = Color("NouriOnPrimary")
    static let nouriAccent = Color("NouriAccent")
    /// Readable versions of the brand colours for small text, links and tags.
    static let nouriPrimaryText = Color("NouriPrimaryText")
    static let nouriAccentText = Color("NouriAccentText")
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
