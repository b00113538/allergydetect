import SwiftUI
import UIKit

/// Single app-wide store. Writes go to the local database first (offline-first), the UI updates
/// immediately, and Firestore sync runs in the background when Firebase is configured.
@MainActor
final class AppState: ObservableObject {
    enum Phase: Equatable { case loading, signedOut, onboarding, ready }

    @Published private(set) var phase: Phase = .loading
    @Published private(set) var user: User?
    @Published private(set) var meals: [MealEntry] = []
    @Published private(set) var symptoms: [SymptomLog] = []
    @Published private(set) var profile: AllergyProfile?
    @Published private(set) var dineCode: DineCode?
    @Published var lastError: String?

    /// Uid + email captured at sign-up, before onboarding creates the `User` record.
    private(set) var pendingAccount: (uid: String, email: String, name: String)?

    let database: LocalDatabase
    let firebase: FirebaseService?
    let vision: IngredientRecognizing
    private let detector = PatternDetectionService()

    private static let localUserKey = "nouri.localUserId"

    var isDemoMode: Bool { firebase == nil }

    init(database: LocalDatabase, firebase: FirebaseService?, vision: IngredientRecognizing) {
        self.database = database
        self.firebase = firebase
        self.vision = vision
    }

    static func live() -> AppState {
        let database: LocalDatabase
        do { database = try LocalDatabase.makeDefault() } catch { fatalError("Could not open local database: \(error)") }
        if AppEnvironment.isFirebaseConfigured {
            return AppState(database: database, firebase: FirebaseService(), vision: ClaudeVisionService())
        }
        return AppState(database: database, firebase: nil, vision: DemoVisionService())
    }

    // MARK: - Session

    func bootstrap() async {
        let uid = firebase?.currentUserId ?? UserDefaults.standard.string(forKey: Self.localUserKey)
        guard let uid else { phase = .signedOut; return }
        await loadSession(uid: uid, email: firebase?.currentEmail ?? "")
    }

    private func loadSession(uid: String, email: String, name: String = "") async {
        var user = try? database.user(id: uid)
        if user == nil, let firebase {
            user = try? await firebase.fetchUser(uid: uid)
            if let user { try? database.save(user) }
            if let history = try? await firebase.fetchHistory(uid: uid) {
                try? database.importFromRemote(meals: history.meals, symptoms: history.symptoms)
            }
        }
        if let user {
            self.user = user
            reload()
            phase = .ready
            syncInBackground()
        } else {
            pendingAccount = (uid, email, name)
            phase = .onboarding
        }
    }

    func signUp(name: String, email: String, password: String) async {
        guard let firebase else { return }
        do {
            let uid = try await firebase.signUp(email: email, password: password)
            pendingAccount = (uid, email, name)
            phase = .onboarding
        } catch {
            lastError = error.localizedDescription
        }
    }

    func signIn(email: String, password: String) async {
        guard let firebase else { return }
        do {
            let uid = try await firebase.signIn(email: email, password: password)
            await loadSession(uid: uid, email: email)
        } catch {
            lastError = error.localizedDescription
        }
    }

    /// Demo mode: a local-only account, no backend required.
    func startDemoAccount(name: String) {
        let uid = "local-\(UUID().uuidString)"
        UserDefaults.standard.set(uid, forKey: Self.localUserKey)
        pendingAccount = (uid, "", name)
        phase = .onboarding
    }

    func completeOnboarding(name: String, dateOfBirth: Date?, history: SymptomHistory, knownConditions: [String]) async {
        guard let account = pendingAccount else { return }
        let user = User(id: account.uid, name: name, email: account.email, dateOfBirth: dateOfBirth,
                        knownConditions: knownConditions, symptomHistory: history, createdAt: .now)
        do {
            try database.save(user)
        } catch {
            lastError = error.localizedDescription
            return
        }
        self.user = user
        pendingAccount = nil
        reload()
        phase = .ready
        if let firebase { Task { try? await firebase.saveUser(user) } }
        _ = await NotificationService.requestAuthorization()
    }

    func updateKnownConditions(_ conditions: [String]) {
        guard var user else { return }
        user.knownConditions = conditions
        try? database.save(user)
        self.user = user
        if let firebase { Task { try? await firebase.saveUser(user) } }
        Task { await refreshPublishedDineCode() }
    }

    func signOut() {
        try? firebase?.signOut()
        UserDefaults.standard.removeObject(forKey: Self.localUserKey)
        try? database.wipeAll()
        user = nil
        meals = []
        symptoms = []
        profile = nil
        dineCode = nil
        phase = .signedOut
    }

    // MARK: - Meals

    func analyze(photo: UIImage) async throws -> MealAnalysis {
        try await vision.analyzeMeal(photo: photo)
    }

    @discardableResult
    func logMeal(photo: UIImage?, dishName: String?, ingredients: [Ingredient], mealType: MealType,
                 notes: String, timestamp: Date = .now) -> MealEntry? {
        guard let user else { return nil }
        let id = UUID().uuidString
        let photoName = photo.flatMap { try? PhotoStore.save($0, id: id) }
        let meal = MealEntry(id: id, userId: user.id, localPhotoName: photoName, timestamp: timestamp,
                             ingredients: ingredients.map(AllergenDatabase.annotate), mealType: mealType,
                             dishName: dishName, userNotes: notes)
        do {
            try database.save(meal)
        } catch {
            lastError = error.localizedDescription
            return nil
        }
        NotificationService.scheduleCheckIn(for: meal)
        reload()
        syncInBackground()
        return meal
    }

    func deleteMeal(_ meal: MealEntry) {
        try? database.deleteMeal(id: meal.id)
        if let name = meal.localPhotoName { PhotoStore.delete(named: name) }
        NotificationService.cancelCheckIn(forMealId: meal.id)
        if let firebase, let uid = user?.id { Task { await firebase.deleteMeal(id: meal.id, uid: uid) } }
        reload()
        syncInBackground()   // linked symptoms were detached and need re-uploading
    }

    // MARK: - Symptoms

    func logSymptom(types: [SymptomType], severity: Int, mealEntryId: String?, notes: String, timestamp: Date = .now) {
        guard let user else { return }
        let log = SymptomLog(userId: user.id, mealEntryId: mealEntryId, timestamp: timestamp,
                             symptomTypes: types, severity: severity, notes: notes)
        do {
            try database.save(log)
        } catch {
            lastError = error.localizedDescription
            return
        }
        if let mealEntryId { NotificationService.cancelCheckIn(forMealId: mealEntryId) }
        reload()
        syncInBackground()
    }

    func deleteSymptom(_ log: SymptomLog) {
        try? database.deleteSymptom(id: log.id)
        if let firebase, let uid = user?.id { Task { await firebase.deleteSymptom(id: log.id, uid: uid) } }
        reload()
    }

    /// Meals eaten in the last `hours` hours — candidates for linking a new symptom log.
    func recentMeals(within hours: Double = 12, now: Date = .now) -> [MealEntry] {
        meals.filter { now.timeIntervalSince($0.timestamp) <= hours * 3600 && $0.timestamp <= now }
    }

    // MARK: - Profile

    /// Reloads from SQLite and re-runs pattern detection. Cheap at MVP data sizes (hundreds of rows).
    func reload() {
        guard let user else { return }
        meals = (try? database.meals(userId: user.id)) ?? []
        symptoms = (try? database.symptoms(userId: user.id)) ?? []
        dineCode = try? database.activeDineCode(userId: user.id)

        let previous = profile ?? (try? database.allergyProfile(userId: user.id))
        let updated = detector.analyze(meals: meals, symptoms: symptoms, userId: user.id)
        profile = updated
        try? database.save(updated)

        let triggersChanged = previous.map { Set($0.triggerIngredients.filter { $0.status != .unlikely }.map(\.id)) }
            != Set(updated.triggerIngredients.filter { $0.status != .unlikely }.map(\.id))
        if triggersChanged {
            if let firebase { Task { try? await firebase.saveProfile(updated) } }
            Task { await refreshPublishedDineCode() }
        }
    }

    // MARK: - Dine Code

    func generateDineCode() async {
        guard let user else { return }
        if let existing = dineCode {
            var old = existing
            old.isActive = false
            try? database.save(old)
            if let firebase { try? await firebase.deactivateDineCode(existing) }
        }
        let token = DineCodeService.makeToken()
        let snapshot = DineCodeService.snapshot(user: user, profile: profile)
        let payload = firebase == nil
            ? DineCodeService.offlinePayloadURL(snapshot: snapshot)
            : DineCodeService.payloadURL(token: token)
        let code = DineCode(id: UUID().uuidString, userId: user.id, token: token, qrPayload: payload,
                            lastGenerated: .now, isActive: true)
        do {
            if let firebase { try await firebase.publishDineCode(code, snapshot: snapshot) }
            try database.save(code)
            dineCode = code
        } catch {
            lastError = "Couldn't publish your Dine Code: \(error.localizedDescription)"
        }
    }

    func deactivateDineCode() async {
        guard var code = dineCode else { return }
        code.isActive = false
        try? database.save(code)
        if let firebase { try? await firebase.deactivateDineCode(code) }
        dineCode = nil
    }

    /// Keeps the public snapshot behind an existing QR in step with the latest profile.
    private func refreshPublishedDineCode() async {
        guard let user, var code = dineCode, code.isActive else { return }
        let snapshot = DineCodeService.snapshot(user: user, profile: profile)
        if let firebase {
            try? await firebase.publishDineCode(code, snapshot: snapshot)
        } else {
            // Offline codes embed the profile, so they must be re-rendered.
            code.qrPayload = DineCodeService.offlinePayloadURL(snapshot: snapshot)
            code.lastGenerated = .now
            try? database.save(code)
            dineCode = code
        }
    }

    // MARK: - Sync

    func syncInBackground() {
        guard let firebase, let uid = user?.id else { return }
        let database = database
        Task.detached(priority: .utility) {
            await firebase.sync(database: database, uid: uid)
        }
    }

    // MARK: - Demo data

    /// Seeds ~3 weeks of realistic history (dairy-sensitive user) so the profile has something to show.
    func loadSampleData() {
        guard let user else { return }
        let (meals, symptoms) = SampleData.history(userId: user.id)
        for meal in meals { try? database.save(meal) }
        for log in symptoms { try? database.save(log) }
        reload()
        syncInBackground()
    }
}
