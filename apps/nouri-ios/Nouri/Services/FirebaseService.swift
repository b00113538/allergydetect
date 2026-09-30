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
///   users/{uid}/skinLogs/{logId}      – SkinLog
///   users/{uid}/bloodwork/{recordId}  – BloodworkRecord
///   users/{uid}/devices/{fcmToken}    – push registration + reminder preferences
///   users/{uid}/profile/current       – AllergyProfile
///   users/{uid}/dineCodes/{id}        – DineCode (private bookkeeping)
///   dineCodes/{token}                 – DineCodeSnapshot (public, get-only)
/// Storage: users/{uid}/meals/{mealId}.jpg, users/{uid}/skin/{logId}.jpg,
///          users/{uid}/bloodwork/{recordId}.pdf|jpg
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
        data.removeValue(forKey: "localDocName")
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
                    remote.photoURL = try await upload(data, path: "users/\(uid)/meals/\(meal.id).jpg", contentType: "image/jpeg")
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
        for log in (try? database.unsyncedSkinLogs()) ?? [] where log.userId == uid {
            do {
                var remote = log
                if remote.photoURL == nil, let name = log.localPhotoName, let data = PhotoStore.data(named: name) {
                    remote.photoURL = try await upload(data, path: "users/\(uid)/skin/\(log.id).jpg", contentType: "image/jpeg")
                }
                try await userDoc(uid).collection("skinLogs").document(log.id).setData(try encode(remote))
                try database.markSynced(skinLogId: log.id, photoURL: remote.photoURL)
            } catch {
                print("[Sync] skin log \(log.id) failed: \(error)")
            }
        }
        for record in (try? database.unsyncedBloodwork()) ?? [] where record.userId == uid {
            do {
                var remote = record
                if remote.sourceDocURL == nil, let name = record.localDocName, let type = record.sourceDocType,
                   let data = DocumentStore.data(named: name) {
                    remote.sourceDocURL = try await upload(data, path: Self.bloodworkPath(uid: uid, record: record, type: type),
                                                           contentType: type.mimeType)
                }
                try await userDoc(uid).collection("bloodwork").document(record.id).setData(try encode(remote))
                try database.markSynced(bloodworkId: record.id, sourceDocURL: remote.sourceDocURL)
            } catch {
                print("[Sync] blood work \(record.id) failed: \(error)")
            }
        }
    }

    private static func bloodworkPath(uid: String, record: BloodworkRecord, type: BloodworkRecord.DocumentType) -> String {
        "users/\(uid)/bloodwork/\(record.id).\(type.fileExtension)"
    }

    func deleteMeal(id: String, uid: String) async {
        try? await userDoc(uid).collection("meals").document(id).delete()
        try? await storage.reference(withPath: "users/\(uid)/meals/\(id).jpg").delete()
    }

    func deleteSymptom(id: String, uid: String) async {
        try? await userDoc(uid).collection("symptoms").document(id).delete()
    }

    func deleteSkinLog(id: String, uid: String) async {
        try? await userDoc(uid).collection("skinLogs").document(id).delete()
        try? await storage.reference(withPath: "users/\(uid)/skin/\(id).jpg").delete()
    }

    func deleteBloodwork(_ record: BloodworkRecord, uid: String) async {
        try? await userDoc(uid).collection("bloodwork").document(record.id).delete()
        if let type = record.sourceDocType {
            try? await storage.reference(withPath: Self.bloodworkPath(uid: uid, record: record, type: type)).delete()
        }
    }

    /// Pulls history on sign-in so a new device starts with the user's data.
    func fetchHistory(uid: String) async throws -> RemoteHistory {
        RemoteHistory(
            meals: try await fetchAll(MealEntry.self, collection: "meals", uid: uid),
            symptoms: try await fetchAll(SymptomLog.self, collection: "symptoms", uid: uid),
            skinLogs: try await fetchAll(SkinLog.self, collection: "skinLogs", uid: uid),
            bloodwork: try await fetchAll(BloodworkRecord.self, collection: "bloodwork", uid: uid)
        )
    }

    private func fetchAll<T: Decodable>(_ type: T.Type, collection: String, uid: String) async throws -> [T] {
        try await userDoc(uid).collection(collection).getDocuments().documents.compactMap { doc -> T? in
            var data = doc.data()
            data["needsSync"] = false
            return try? Firestore.Decoder().decode(T.self, from: data)
        }
    }

    // MARK: Push devices

    func saveDevice(uid: String, token: String, fields: [String: Any]) async throws {
        try await userDoc(uid).collection("devices").document(token).setData(fields, merge: true)
    }

    func deleteDevice(uid: String, token: String) async {
        try? await userDoc(uid).collection("devices").document(token).delete()
    }

    // MARK: Storage

    func upload(_ data: Data, path: String, contentType: String) async throws -> String {
        let ref = storage.reference(withPath: path)
        let metadata = StorageMetadata()
        metadata.contentType = contentType
        _ = try await ref.putDataAsync(data, metadata: metadata)
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
