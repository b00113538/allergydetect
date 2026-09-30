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
    @State private var symptomSheetMealId: SheetMealID?

    var body: some View {
        TabView {
            NavigationStack { HomeView() }
                .tabItem { Label("Today", systemImage: "house") }
            NavigationStack { ProfileView() }
                .tabItem { Label("Insights", systemImage: "chart.bar.xaxis") }
            NavigationStack { DineCodeView() }
                .tabItem { Label("Dine Code", systemImage: "qrcode") }
        }
        .onReceive(NotificationCenter.default.publisher(for: .nouriOpenSymptomLog)) { note in
            symptomSheetMealId = SheetMealID(mealId: note.object as? String)
        }
        .sheet(item: $symptomSheetMealId) { item in
            SymptomLogView(preselectedMealId: item.mealId)
        }
    }

    struct SheetMealID: Identifiable {
        var mealId: String?
        var id: String { mealId ?? "none" }
    }
}
