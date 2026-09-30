import SwiftUI

struct NouriCard<Content: View>: View {
    var padding: CGFloat = 16
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) { content }
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.nouriSurface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Color.nouriBorder, lineWidth: 1))
    }
}

struct NouriPrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .foregroundStyle(Color.nouriOnPrimary)
            .background(Color.nouriPrimary.opacity(isEnabled ? 1 : 0.4), in: Capsule())
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

struct NouriSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .foregroundStyle(Color.nouriPrimaryText)
            .background(Capsule().stroke(Color.nouriPrimaryText, lineWidth: 1.5))
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

extension ButtonStyle where Self == NouriPrimaryButtonStyle {
    static var nouriPrimary: NouriPrimaryButtonStyle { .init() }
}

extension ButtonStyle where Self == NouriSecondaryButtonStyle {
    static var nouriSecondary: NouriSecondaryButtonStyle { .init() }
}

/// Selectable pill used for symptoms, allergens, meal types.
struct Chip: View {
    let title: String
    var systemImage: String? = nil
    var isSelected: Bool
    /// Fill when selected (with `nouriOnPrimary` text), so it uses the readable tone.
    var tint: Color = .nouriPrimaryText
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let systemImage { Image(systemName: systemImage) }
                Text(title)
            }
            .font(.subheadline.weight(.medium))
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .foregroundStyle(isSelected ? Color.nouriOnPrimary : Color.nouriTextPrimary)
            .background(isSelected ? tint : Color.nouriSurface, in: Capsule())
            .overlay(Capsule().stroke(isSelected ? tint : Color.nouriBorder, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// Small coloured tag, e.g. allergen flags.
struct Tag: View {
    let text: String
    var color: Color = .nouriAccentText

    var body: some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .foregroundStyle(color)
            .background(color.opacity(0.14), in: Capsule())
    }
}

/// Simple wrapping layout for chips.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrange(width: proposal.width ?? .infinity, subviews: subviews)
        let height = rows.last.map { $0.y + $0.height } ?? 0
        let width = rows.map(\.width).max() ?? 0
        return CGSize(width: proposal.width ?? width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        for row in arrange(width: bounds.width, subviews: subviews) {
            var x = bounds.minX
            for index in row.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(at: CGPoint(x: x, y: bounds.minY + row.y), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
        }
    }

    private struct Row { var indices: [Int] = []; var y: CGFloat = 0; var width: CGFloat = 0; var height: CGFloat = 0 }

    private func arrange(width: CGFloat, subviews: Subviews) -> [Row] {
        var rows: [Row] = [Row()]
        for (index, subview) in subviews.enumerated() {
            let size = subview.sizeThatFits(.unspecified)
            var row = rows[rows.count - 1]
            if !row.indices.isEmpty && row.width + spacing + size.width > width {
                let y = row.y + row.height + spacing
                rows.append(Row(y: y))
                row = rows[rows.count - 1]
            }
            row.width += (row.indices.isEmpty ? 0 : spacing) + size.width
            row.height = max(row.height, size.height)
            row.indices.append(index)
            rows[rows.count - 1] = row
        }
        return rows
    }
}

struct SeverityPicker: View {
    @Binding var severity: Int

    var body: some View {
        HStack(spacing: 10) {
            ForEach(1...5, id: \.self) { level in
                Button { severity = level } label: {
                    Text("\(level)")
                        .font(.headline)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .foregroundStyle(level == severity ? Color.nouriOnPrimary : Color.nouriTextPrimary)
                        .background(level == severity ? level.severityColor : Color.nouriSurface,
                                    in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color.nouriBorder))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Severity \(level)")
            }
        }
    }
}

/// Screen background helper.
extension View {
    func nouriScreenBackground() -> some View {
        background(Color.nouriBackground.ignoresSafeArea())
    }
}
