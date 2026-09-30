import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var app: AppState
    @State private var showMealLog = false
    @State private var showSymptomLog = false
    @State private var showSkinLog = false
    @State private var symptomMealId: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                quickLog
                if let meal = pendingCheckIn { checkInCard(meal) }
                insightTeaser
                timeline
            }
            .padding(20)
        }
        .nouriScreenBackground()
        .navigationTitle("Today")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showMealLog) { MealLogFlowView() }
        .sheet(isPresented: $showSymptomLog) { SymptomLogView(preselectedMealId: symptomMealId) }
        .sheet(isPresented: $showSkinLog) { SkinLogView() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(Date.now.formatted(.dateTime.weekday(.wide).day().month(.wide)).uppercased())
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.nouriAccentText)
            Text("\(greeting), \(app.user?.firstName ?? "there")").nouriHeading(.largeTitle)
        }
    }

    private var quickLog: some View {
        HStack(spacing: 10) {
            QuickLogButton(title: "Meal", subtitle: "Snap a photo", systemImage: "camera.fill", tint: .nouriPrimary) {
                showMealLog = true
            }
            QuickLogButton(title: "Symptom", subtitle: "How you feel", systemImage: "waveform.path.ecg", tint: .nouriAccent) {
                symptomMealId = nil
                showSymptomLog = true
            }
            QuickLogButton(title: "Skin", subtitle: "Clothes & products", systemImage: "hand.raised.fill", tint: .nouriPrimary) {
                showSkinLog = true
            }
        }
    }

    /// Most recent meal in the 1–8h window with no symptom log linked to it yet.
    private var pendingCheckIn: MealEntry? {
        let linked = Set(app.symptoms.compactMap(\.mealEntryId))
        return app.meals.first { meal in
            let age = Date.now.timeIntervalSince(meal.timestamp)
            return age > 3600 && age < 8 * 3600 && !linked.contains(meal.id)
        }
    }

    private func checkInCard(_ meal: MealEntry) -> some View {
        NouriCard {
            HStack {
                Image(systemName: "bell.badge").foregroundStyle(Color.nouriAccent)
                Text("Check in on your \(meal.title.lowercased())").font(NouriFont.label)
            }
            Text("You ate this \(meal.timestamp.relativeString). Logging how you feel — even \"fine\" — makes your insights sharper.")
                .font(.footnote)
                .foregroundStyle(Color.nouriTextSecondary)
            HStack {
                Button("I feel fine") {
                    app.logSymptom(types: [.none], severity: 1, mealEntryId: meal.id, notes: "")
                }
                .buttonStyle(.nouriSecondary)
                Button("Log symptom") {
                    symptomMealId = meal.id
                    showSymptomLog = true
                }
                .buttonStyle(.nouriPrimary)
            }
        }
    }

    @ViewBuilder
    private var insightTeaser: some View {
        if let profile = app.profile, !profile.likelyTriggers.isEmpty {
            NavigationLink { ProfileView() } label: {
                NouriCard {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(Color.nouriDanger)
                        Text("\(profile.likelyTriggers.count) likely trigger\(profile.likelyTriggers.count == 1 ? "" : "s") found")
                            .font(NouriFont.section)
                            .foregroundStyle(Color.nouriTextPrimary)
                        Spacer()
                        Image(systemName: "chevron.right").foregroundStyle(Color.nouriTextSecondary)
                    }
                    Text(profile.likelyTriggers.prefix(3).map { $0.ingredient.capitalizedFirst }.joined(separator: " · "))
                        .foregroundStyle(Color.nouriTextSecondary)
                }
            }
            .buttonStyle(.plain)
        } else if app.meals.count < 5 {
            NouriCard {
                Text("Building your profile").font(NouriFont.section).foregroundStyle(Color.nouriTextPrimary)
                Text("Log meals and how you feel for a week or two. Nouri flags an ingredient once it shows up in 3+ meals that were followed by symptoms most of the time.")
                    .font(.footnote)
                    .foregroundStyle(Color.nouriTextSecondary)
                if app.isDemoMode && app.meals.isEmpty {
                    Button("Load sample history") { app.loadSampleData() }
                        .buttonStyle(.nouriSecondary)
                }
            }
        }
    }

    private var timeline: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent").nouriHeading(.title3)
            if timelineItems.isEmpty {
                Text("Nothing logged yet.").foregroundStyle(Color.nouriTextSecondary)
            }
            ForEach(timelineItems) { item in
                switch item {
                case .meal(let meal):
                    NavigationLink { MealDetailView(meal: meal) } label: { MealRow(meal: meal) }
                        .buttonStyle(.plain)
                case .symptom(let log):
                    SymptomRow(log: log, meal: log.mealEntryId.flatMap { id in app.meals.first { $0.id == id } })
                        .contextMenu {
                            Button("Delete", role: .destructive) { app.deleteSymptom(log) }
                        }
                case .skin(let log):
                    NavigationLink { SkinLogDetailView(log: log) } label: { SkinLogRow(log: log) }
                        .buttonStyle(.plain)
                }
            }
        }
    }

    private var timelineItems: [TimelineItem] {
        let items = app.meals.prefix(15).map(TimelineItem.meal) + app.symptoms.prefix(15).map(TimelineItem.symptom)
            + app.skinLogs.prefix(10).map(TimelineItem.skin)
        return Array(items.sorted { $0.date > $1.date }.prefix(20))
    }

    private var greeting: String {
        switch Calendar.current.component(.hour, from: .now) {
        case 5..<12: "Good morning"
        case 12..<17: "Good afternoon"
        default: "Good evening"
        }
    }
}

enum TimelineItem: Identifiable {
    case meal(MealEntry)
    case symptom(SymptomLog)
    case skin(SkinLog)

    var id: String {
        switch self {
        case .meal(let m): "m-\(m.id)"
        case .symptom(let s): "s-\(s.id)"
        case .skin(let k): "k-\(k.id)"
        }
    }

    var date: Date {
        switch self {
        case .meal(let m): m.timestamp
        case .symptom(let s): s.timestamp
        case .skin(let k): k.timestamp
        }
    }
}

struct QuickLogButton: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                Image(systemName: systemImage)
                    .font(.title2)
                    .foregroundStyle(tint)
                    .frame(width: 44, height: 44)
                    .background(tint.opacity(0.14), in: Circle())
                Text(title).font(.headline).foregroundStyle(Color.nouriTextPrimary)
                Text(subtitle).font(.caption).foregroundStyle(Color.nouriTextSecondary).lineLimit(2, reservesSpace: true)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.nouriSurface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Color.nouriBorder))
        }
        .buttonStyle(.plain)
    }
}

struct MealRow: View {
    let meal: MealEntry

    var body: some View {
        HStack(spacing: 12) {
            MealThumbnail(meal: meal, size: 52)
            VStack(alignment: .leading, spacing: 3) {
                Text(meal.title).font(.headline).foregroundStyle(Color.nouriTextPrimary)
                Text("\(meal.mealType.label) · \(meal.timestamp.timeString)")
                    .font(.caption).foregroundStyle(Color.nouriTextSecondary)
                let groups = Array(Set(meal.ingredients.flatMap(\.allergenGroups))).sorted { $0.rawValue < $1.rawValue }
                if !groups.isEmpty {
                    HStack(spacing: 4) { ForEach(groups.prefix(3)) { Tag(text: $0.label) } }
                }
            }
            Spacer()
        }
        .padding(12)
        .background(Color.nouriSurface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

struct SymptomRow: View {
    let log: SymptomLog
    let meal: MealEntry?

    private var detail: String {
        var parts: [String] = []
        if log.isReaction { parts.append("Severity \(log.severity)/5") }
        parts.append(log.timestamp.timeString)
        if let meal { parts.append("after \(meal.title)") }
        return parts.joined(separator: " · ")
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: log.isReaction ? "waveform.path.ecg" : "checkmark.circle")
                .font(.title3)
                .foregroundStyle(log.isReaction ? log.severity.severityColor : Color.nouriSuccess)
                .frame(width: 52, height: 52)
                .background((log.isReaction ? log.severity.severityColor : Color.nouriSuccess).opacity(0.14),
                            in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                Text(log.symptomTypes.map(\.label).joined(separator: ", ")).font(.headline).foregroundStyle(Color.nouriTextPrimary)
                Text(detail).font(.caption).foregroundStyle(Color.nouriTextSecondary)
            }
            Spacer()
        }
        .padding(12)
        .background(Color.nouriSurface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

struct MealThumbnail: View {
    let meal: MealEntry
    var size: CGFloat = 52

    var body: some View {
        Group {
            if let name = meal.localPhotoName, let image = PhotoStore.image(named: name) {
                Image(uiImage: image).resizable().scaledToFill()
            } else if let url = meal.photoURL.flatMap(URL.init(string:)) {
                AsyncImage(url: url) { $0.resizable().scaledToFill() } placeholder: { Color.nouriSurfaceMuted }
            } else {
                Image(systemName: meal.mealType.symbol)
                    .foregroundStyle(Color.nouriPrimary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.nouriSurfaceMuted)
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
