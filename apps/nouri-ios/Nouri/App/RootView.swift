import SwiftUI

struct RootView: View {
    @EnvironmentObject private var app: AppState

    var body: some View {
        Group {
            switch app.phase {
            case .loading:
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity).nouriScreenBackground()
            case .signedOut:
                WelcomeView()
            case .onboarding:
                OnboardingFlowView()
            case .ready:
                MainTabView()
            }
        }
        .animation(.default, value: app.phase)
        .task { if app.phase == .loading { await app.bootstrap() } }
        .alert("Something went wrong", isPresented: Binding(get: { app.lastError != nil }, set: { if !$0 { app.lastError = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(app.lastError ?? "")
        }
    }
}

struct MainTabView: View {
    enum Tab: Hashable { case today, insights, dineCode }

    @State private var tab: Tab = .today
    @State private var symptomSheetMealId: SheetMealID?
    @State private var showMealLog = false

    var body: some View {
        TabView(selection: $tab) {
            NavigationStack { HomeView() }
                .tabItem { Label("Today", systemImage: "house") }
                .tag(Tab.today)
            NavigationStack { ProfileView() }
                .tabItem { Label("Insights", systemImage: "chart.bar.xaxis") }
                .tag(Tab.insights)
            NavigationStack { DineCodeView() }
                .tabItem { Label("Dine Code", systemImage: "qrcode") }
                .tag(Tab.dineCode)
        }
        .onReceive(NotificationCenter.default.publisher(for: .nouriOpenSymptomLog)) { note in
            symptomSheetMealId = SheetMealID(mealId: note.object as? String)
        }
        .onReceive(NotificationCenter.default.publisher(for: .nouriOpenRoute)) { note in
            switch note.object as? NotificationRoute {
            case .logMeal:
                tab = .today
                showMealLog = true
            case .insights:
                tab = .insights
            case nil:
                break
            }
        }
        .sheet(item: $symptomSheetMealId) { item in
            SymptomLogView(preselectedMealId: item.mealId)
        }
        .sheet(isPresented: $showMealLog) { MealLogFlowView() }
    }

    struct SheetMealID: Identifiable {
        var mealId: String?
        var id: String { mealId ?? "none" }
    }
}
