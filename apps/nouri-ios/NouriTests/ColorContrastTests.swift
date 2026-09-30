import XCTest
import UIKit
@testable import Nouri

/// Guards the palette's accessibility: every colour used for small text must reach WCAG AA (4.5:1)
/// on the background, the card surface and its own 14% tag tint, in light and dark mode.
final class ColorContrastTests: XCTestCase {
    private let bundle = Bundle(for: AppState.self)

    private func rgb(_ name: String, _ style: UIUserInterfaceStyle) throws -> (Double, Double, Double) {
        let color = try XCTUnwrap(UIColor(named: name, in: bundle, compatibleWith: UITraitCollection(userInterfaceStyle: style)),
                                  "Missing colour set \(name)")
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        return (Double(r), Double(g), Double(b))
    }

    private func luminance(_ c: (Double, Double, Double)) -> Double {
        func channel(_ v: Double) -> Double { v <= 0.03928 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4) }
        return 0.2126 * channel(c.0) + 0.7152 * channel(c.1) + 0.0722 * channel(c.2)
    }

    private func contrast(_ a: (Double, Double, Double), _ b: (Double, Double, Double)) -> Double {
        let (hi, lo) = (max(luminance(a), luminance(b)), min(luminance(a), luminance(b)))
        return (hi + 0.05) / (lo + 0.05)
    }

    private func tint(_ fg: (Double, Double, Double), on bg: (Double, Double, Double), alpha: Double = 0.14) -> (Double, Double, Double) {
        (alpha * fg.0 + (1 - alpha) * bg.0, alpha * fg.1 + (1 - alpha) * bg.1, alpha * fg.2 + (1 - alpha) * bg.2)
    }

    func testTextColoursMeetAAInBothAppearances() throws {
        let textColours = ["NouriTextPrimary", "NouriTextSecondary", "NouriPrimaryText", "NouriAccentText",
                           "NouriDanger", "NouriWarning", "NouriSuccess"]
        for style in [UIUserInterfaceStyle.light, .dark] {
            let background = try rgb("NouriBackground", style)
            let surface = try rgb("NouriSurface", style)
            for name in textColours {
                let fg = try rgb(name, style)
                XCTAssertGreaterThanOrEqual(contrast(fg, background), 4.5, "\(name) on background (\(style.rawValue))")
                XCTAssertGreaterThanOrEqual(contrast(fg, surface), 4.5, "\(name) on surface (\(style.rawValue))")
                if !name.hasPrefix("NouriText") {
                    XCTAssertGreaterThanOrEqual(contrast(fg, tint(fg, on: surface)), 4.5, "\(name) as a tag (\(style.rawValue))")
                }
            }
        }
    }

    func testLabelsOnFilledControls() throws {
        for style in [UIUserInterfaceStyle.light, .dark] {
            let onPrimary = try rgb("NouriOnPrimary", style)
            // Selected chips and small filled controls.
            for fill in ["NouriPrimaryText", "NouriSuccess", "NouriDanger"] {
                XCTAssertGreaterThanOrEqual(contrast(onPrimary, try rgb(fill, style)), 4.5, "label on \(fill) (\(style.rawValue))")
            }
            // Primary button: 17pt semibold counts as large text (3:1).
            XCTAssertGreaterThanOrEqual(contrast(onPrimary, try rgb("NouriPrimary", style)), 3.0, "button label (\(style.rawValue))")
        }
    }
}
