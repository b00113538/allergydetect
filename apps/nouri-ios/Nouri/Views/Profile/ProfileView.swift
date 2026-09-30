import SwiftUI
import Charts

/// Trigger dashboard: detected patterns, confidence per ingredient, trend over time — for food,
/// and (phase 6) skin/fabric logs and uploaded blood work.
struct ProfileView: View {
    enum Tab: String, CaseIterable, Identifiable {
        case food = "Food", skin = "Skin", bloodwork = "Blood work"
        var id: String { rawValue }
    }

    @EnvironmentObject private var app: AppState
    @State private var tab: Tab = .food
    @State private var showAll = false
    @State private var selected: TriggerIngredient?
    @State private var showSettings = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Picker("Insights", selection: $tab) {
                    ForEach(Tab.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                switch tab {
                case .food:
                    summary
                    if let profile = app.profile {
                        groupsSection(profile)
                        triggersSection(profile)
                        trendSection
                    }
                    methodology
                case .skin:
                    SkinInsightsView(selected: $selected)
                case .bloodwork:
                    BloodworkInsightsView()
                }
            }
            .padding(20)
        }
        .nouriScreenBackground()
        .navigationTitle("Insights")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { showSettings = true } label: { Image(systemName: "person.crop.circle") }
            }
        }
        .sheet(item: $selected) { TriggerDetailView(trigger: $0) }
        .sheet(isPresented: $showSettings) { SettingsView() }
    }

    private var summary: some View {
        HStack(spacing: 12) {
            StatTile(value: "\(app.profile?.mealsAnalyzed ?? 0)", label: "Meals analysed")
            StatTile(value: "\(app.symptoms.filter(\.isReaction).count)", label: "Reactions logged")
            StatTile(value: "\(app.profile?.likelyTriggers.count ?? 0)", label: "Likely triggers", tint: .nouriDanger)
        }
    }

    @ViewBuilder
    private func groupsSection(_ profile: AllergyProfile) -> some View {
        let flagged = profile.triggerGroups.filter { $0.status != .unlikely }
        if !flagged.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("Allergen groups").nouriHeading(.title3)
                ForEach(flagged) { group in
                    Button { selected = group } label: { TriggerRow(trigger: group) }.buttonStyle(.plain)
                }
            }
        }
    }

    private func triggersSection(_ profile: AllergyProfile) -> some View {
        let ranked = profile.triggerIngredients.filter { $0.exposures >= 2 }
        let visible = showAll ? ranked : ranked.filter { $0.status != .unlikely }
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Ingredients").nouriHeading(.title3)
                Spacer()
                if ranked.count > visible.count || showAll {
                    Button(showAll ? "Show flagged" : "Show all") { withAnimation { showAll.toggle() } }
                        .font(.subheadline)
                }
            }
            if visible.isEmpty {
                NouriCard {
                    Text("No patterns yet").font(.headline).foregroundStyle(Color.nouriTextPrimary)
                    Text("Keep logging meals and symptoms. A likely trigger needs at least 3 meals with the ingredient, followed by symptoms 70%+ of the time.")
                        .font(.footnote)
                        .foregroundStyle(Color.nouriTextSecondary)
                }
            }
            ForEach(visible) { trigger in
                Button { selected = trigger } label: { TriggerRow(trigger: trigger) }.buttonStyle(.plain)
            }
        }
    }

    private var trendSection: some View {
        let points = PatternDetectionService.weeklyTrend(symptoms: app.symptoms)
        return VStack(alignment: .leading, spacing: 10) {
            Text("Reactions per week").nouriHeading(.title3)
            NouriCard {
                Chart(points) { point in
                    BarMark(x: .value("Week", point.weekStart, unit: .weekOfYear), y: .value("Reactions", point.reactionCount))
                        .foregroundStyle(Color.nouriPrimary.gradient)
                        .cornerRadius(4)
                    if point.reactionCount > 0 {
                        PointMark(x: .value("Week", point.weekStart, unit: .weekOfYear), y: .value("Avg severity", point.averageSeverity))
                            .foregroundStyle(Color.nouriAccent)
                            .symbolSize(40)
                    }
                }
                .chartXAxis { AxisMarks(values: .stride(by: .weekOfYear, count: 2)) { _ in AxisValueLabel(format: .dateTime.day().month(.abbreviated)) } }
                .frame(height: 180)
                HStack(spacing: 14) {
                    Label("Reactions", systemImage: "square.fill").foregroundStyle(Color.nouriPrimaryText)
                    Label("Avg severity", systemImage: "circle.fill").foregroundStyle(Color.nouriAccentText)
                }
                .font(.caption)
            }
        }
    }

    private var methodology: some View {
        NouriCard {
            Label("How Nouri decides", systemImage: "info.circle").font(NouriFont.label).foregroundStyle(Color.nouriTextPrimary)
            Text("For each ingredient we count the meals that contained it and how many were followed by symptoms within 8 hours (or that you linked directly). Confidence rises with how consistent that is, how much more often it happens than after your other meals, how much data there is, and severity. These are patterns, not a diagnosis — talk to a clinician before cutting out foods.")
                .font(.footnote)
                .foregroundStyle(Color.nouriTextSecondary)
        }
    }
}

struct StatTile: View {
    let value: String
    let label: String
    var tint: Color = .nouriPrimary

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value).font(NouriFont.heading(.title)).foregroundStyle(tint)
            Text(label).font(.caption).foregroundStyle(Color.nouriTextSecondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.nouriSurface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.nouriBorder))
    }
}

struct TriggerRow: View {
    let trigger: TriggerIngredient

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(trigger.ingredient.capitalizedFirst).font(.headline).foregroundStyle(Color.nouriTextPrimary)
                Spacer()
                Tag(text: trigger.status.label, color: trigger.status.color)
            }
            ConfidenceBar(value: trigger.confidence, tint: trigger.status.color)
            Text("Confidence \(trigger.confidence.percentString) · symptoms after \(trigger.reactions) of \(trigger.exposures) meals")
                .font(.caption)
                .foregroundStyle(Color.nouriTextSecondary)
        }
        .padding(14)
        .background(Color.nouriSurface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color.nouriBorder))
    }
}

struct ConfidenceBar: View {
    let value: Double
    var tint: Color

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.nouriSurfaceMuted)
                Capsule().fill(tint).frame(width: max(6, proxy.size.width * value))
            }
        }
        .frame(height: 8)
        .accessibilityElement()
        .accessibilityLabel("Confidence")
        .accessibilityValue(value.percentString)
    }
}
