import Foundation
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage

/// Auth, Firestore sync and Cloud Storage uploads.
///
/// Firestore layout (see `firebase/firestore.rules`):
///   users/{uid}                       – User
///   users/{uid}/meals/{mealId}        – MealEntry
///   users/{uid}/symptoms/{logId}      – SymptomLog
///   users/{uid}/profile/current       – AllergyProfile
///   users/{uid}/dineCodes/{id}        – DineCode (private bookkeeping)
///   dineCodes/{token}                 – DineCodeSnapshot (public, get-only)
/// Storage: users/{uid}/meals/{mealId}.jpg
final class FirebaseService {
    private let auth = Auth.auth()
    private let db = Firestore.firestore()
    private let storage = Storage.storage()

    var currentUserId: String? { auth.currentUser?.uid }
    var currentEmail: String? { auth.currentUser?.email }

    // MARK: Auth

    func signUp(email: String, password: String) async throws -> String {
        try await auth.createUser(withEmail: email, password: password).user.uid
    }

    func signIn(email: String, password: String) async throws -> String {
        try await auth.signIn(withEmail: email, password: password).user.uid
    }

    func signOut() throws {
        try auth.signOut()
    }

    // MARK: Documents

    private func userDoc(_ uid: String) -> DocumentReference { db.collection("users").document(uid) }

    private func encode<T: Encodable>(_ value: T) throws -> [String: Any] {
        var data = try Firestore.Encoder().encode(value)
        data.removeValue(forKey: "needsSync")          // local bookkeeping only
        data.removeValue(forKey: "localPhotoName")
        return data
    }

    func saveUser(_ user: User) async throws {
        try await userDoc(user.id).setData(try encode(user), merge: true)
    }

    func fetchUser(uid: String) async throws -> User? {
        let snapshot = try await userDoc(uid).getDocument()
        guard snapshot.exists else { return nil }
        return try snapshot.data(as: User.self)
    }

    func saveProfile(_ profile: AllergyProfile) async throws {
        try await userDoc(profile.userId).collection("profile").document(profile.id).setData(try encode(profile))
    }

    /// Pushes every dirty local row, uploading meal photos first. Failures leave rows dirty for the next attempt.
    func sync(database: LocalDatabase, uid: String) async {
        for meal in (try? database.unsyncedMeals()) ?? [] where meal.userId == uid {
            do {
                var remote = meal
                if remote.photoURL == nil, let name = meal.localPhotoName, let data = PhotoStore.data(named: name) {
                    remote.photoURL = try await uploadMealPhoto(data, uid: uid, mealId: meal.id)
                }
                try await userDoc(uid).collection("meals").document(meal.id).setData(try encode(remote))
                try database.markSynced(mealId: meal.id, photoURL: remote.photoURL)
            } catch {
                print("[Sync] meal \(meal.id) failed: \(error)")
            }
        }
        for log in (try? database.unsyncedSymptoms()) ?? [] where log.userId == uid {
            do {
                try await userDoc(uid).collection("symptoms").document(log.id).setData(try encode(log))
                try database.markSynced(symptomId: log.id)
            } catch {
                print("[Sync] symptom \(log.id) failed: \(error)")
            }
        }
    }

    func deleteMeal(id: String, uid: String) async {
        try? await userDoc(uid).collection("meals").document(id).delete()
        try? await storage.reference(withPath: "users/\(uid)/meals/\(id).jpg").delete()
    }

    func deleteSymptom(id: String, uid: String) async {
        try? await userDoc(uid).collection("symptoms").document(id).delete()
    }

    /// Pulls history on sign-in so a new device starts with the user's data.
    func fetchHistory(uid: String) async throws -> (meals: [MealEntry], symptoms: [SymptomLog]) {
        let meals = try await userDoc(uid).collection("meals").getDocuments().documents.compactMap { doc -> MealEntry? in
            var data = doc.data()
            data["needsSync"] = false
            return try? Firestore.Decoder().decode(MealEntry.self, from: data)
        }
        let symptoms = try await userDoc(uid).collection("symptoms").getDocuments().documents.compactMap { doc -> SymptomLog? in
            var data = doc.data()
            data["needsSync"] = false
            return try? Firestore.Decoder().decode(SymptomLog.self, from: data)
        }
        return (meals, symptoms)
    }

    // MARK: Storage

    func uploadMealPhoto(_ jpeg: Data, uid: String, mealId: String) async throws -> String {
        let ref = storage.reference(withPath: "users/\(uid)/meals/\(mealId).jpg")
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        _ = try await ref.putDataAsync(jpeg, metadata: metadata)
        return try await ref.downloadURL().absoluteString
    }

    // MARK: Dine Code

    /// Writes/refreshes the public snapshot a Dine Code points to.
    func publishDineCode(_ code: DineCode, snapshot: DineCodeSnapshot) async throws {
        let batch = db.batch()
        batch.setData(try encode(snapshot), forDocument: db.collection("dineCodes").document(code.token))
        batch.setData(try encode(code), forDocument: userDoc(code.userId).collection("dineCodes").document(code.id))
        try await batch.commit()
    }

    /// Revokes a code: the scan page then shows "no longer active".
    func deactivateDineCode(_ code: DineCode) async throws {
        let batch = db.batch()
        batch.updateData(["isActive": false, "avoid": [String]()], forDocument: db.collection("dineCodes").document(code.token))
        batch.updateData(["isActive": false], forDocument: userDoc(code.userId).collection("dineCodes").document(code.id))
        try await batch.commit()
    }
}
