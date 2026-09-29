import SwiftUI

/// Serif headings (matching the pitch-deck branding), clean sans body text.
/// Headings use the system serif (New York) so they scale with Dynamic Type. To use the exact
/// mockup typeface instead, add the font file to the target and set `headingFontName`.
enum NouriFont {
    static var headingFontName: String? = nil

    static func heading(_ style: Font.TextStyle) -> Font {
        if let name = headingFontName {
            return .custom(name, size: UIFont.preferredFont(forTextStyle: style.uiKit).pointSize, relativeTo: style)
        }
        return .system(style, design: .serif).weight(.semibold)
    }

    static var display: Font { heading(.largeTitle) }
    static var title: Font { heading(.title2) }
    static var section: Font { heading(.title3) }
    static let body = Font.body
    static let caption = Font.caption
    static let label = Font.subheadline.weight(.medium)
}

private extension Font.TextStyle {
    var uiKit: UIFont.TextStyle {
        switch self {
        case .largeTitle: .largeTitle
        case .title: .title1
        case .title2: .title2
        case .title3: .title3
        case .headline: .headline
        case .subheadline: .subheadline
        case .callout: .callout
        case .footnote: .footnote
        case .caption: .caption1
        case .caption2: .caption2
        default: .body
        }
    }
}

extension View {
    func nouriHeading(_ style: Font.TextStyle = .title2) -> some View {
        font(NouriFont.heading(style)).foregroundStyle(Color.nouriTextPrimary)
    }
}
