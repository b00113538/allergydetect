import SwiftUI

/// Insights → Skin: products, fabrics and materials scored from skin logs.
struct SkinInsightsView: View {
    @EnvironmentObject private var app: AppState
    @Binding var selected: TriggerIngredient?
    @State private var showLog = false
    @State private var showAll = false

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 12) {
                StatTile(value: "\(app.skinLogs.count)", label: "Skin logs")
                StatTile(value: "\(app.skinLogs.filter(\.isReaction).count)", label: "Reactions")
                StatTile(value: "\(app.profile?.likelySkinTriggers.count ?? 0)", label: "Likely triggers", tint: .nouriDanger)
            }
            Button { showLog = true } label: { Label("Log skin", systemImage: "hand.raised") }
                .buttonStyle(.nouriSecondary)
            triggers
            if !app.skinLogs.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Recent logs").nouriHeading(.title3)
                    ForEach(app.skinLogs.prefix(5)) { log in
                        NavigationLink { SkinLogDetailView(log: log) } label: { SkinLogRow(log: log) }
                            .buttonStyle(.plain)
                    }
                }
            }
            NouriCard {
                Label("How skin tracking works", systemImage: "info.circle").font(NouriFont.label).foregroundStyle(Color.nouriTextPrimary)
                Text("Each log lists what touched your skin and whether it reacted. Nouri scores every product, fabric and material the same way as foods: seen in 3+ logs, followed by a reaction 70%+ of the time, and more often than on your other days. Contact reactions can take a day or two to appear, so log the day's exposures when you notice a flare-up.")
                    .font(.footnote)
                    .foregroundStyle(Color.nouriTextSecondary)
            }
        }
        .sheet(isPresented: $showLog) { SkinLogView() }
    }

    private var triggers: some View {
        let ranked = (app.profile?.skinTriggers ?? []).filter { $0.exposures >= 2 }
        let visible = showAll ? ranked : ranked.filter { $0.status != .unlikely }
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Products & fabrics").nouriHeading(.title3)
                Spacer()
                if ranked.count > visible.count || showAll {
                    Button(showAll ? "Show flagged" : "Show all") { withAnimation { showAll.toggle() } }
                        .font(.subheadline)
                }
            }
            if visible.isEmpty {
                NouriCard {
                    Text(app.skinLogs.isEmpty ? "No skin logs yet" : "No patterns yet").font(.headline).foregroundStyle(Color.nouriTextPrimary)
                    Text("Log what you wore and used — on good days too. Patterns appear once something shows up in at least 3 logs.")
                        .font(.footnote)
                        .foregroundStyle(Color.nouriTextSecondary)
                }
            }
            ForEach(visible) { trigger in
                Button { selected = trigger } label: { TriggerRow(trigger: trigger) }.buttonStyle(.plain)
            }
        }
    }
}
