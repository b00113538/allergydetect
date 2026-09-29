import Foundation
import GRDB

// Records are stored as-is via Codable; nested arrays/structs (ingredients, symptom types, …)
// are encoded by GRDB as JSON text columns.
extension User: FetchableRecord, PersistableRecord { static let databaseTableName = "user" }
extension MealEntry: FetchableRecord, PersistableRecord { static let databaseTableName = "mealEntry" }
extension SymptomLog: FetchableRecord, PersistableRecord { static let databaseTableName = "symptomLog" }
extension AllergyProfile: FetchableRecord, PersistableRecord { static let databaseTableName = "allergyProfile" }
extension SkinLog: FetchableRecord, PersistableRecord { static let databaseTableName = "skinLog" }
extension BloodworkRecord: FetchableRecord, PersistableRecord { static let databaseTableName = "bloodworkRecord" }
extension DineCode: FetchableRecord, PersistableRecord { static let databaseTableName = "dineCode" }

/// Offline-first local store (SQLite via GRDB). This is the app's source of truth;
/// `SyncService` mirrors dirty rows (`needsSync = 1`) to Firestore when online.
final class LocalDatabase {
    let dbQueue: DatabaseQueue

    init(path: String) throws {
        dbQueue = try DatabaseQueue(path: path)
        try Self.migrator.migrate(dbQueue)
    }

    /// In-memory database for previews and tests.
    init() throws {
        dbQueue = try DatabaseQueue()
        try Self.migrator.migrate(dbQueue)
    }

    static func makeDefault() throws -> LocalDatabase {
        let folder = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        return try LocalDatabase(path: folder.appendingPathComponent("nouri.sqlite").path)
    }

    private static var migrator: DatabaseMigrator {
        var migrator = DatabaseMigrator()
        migrator.registerMigration("v1") { db in
            try db.create(table: "user") { t in
                t.column("id", .text).primaryKey()
                t.column("name", .text).notNull()
                t.column("email", .text).notNull()
                t.column("dateOfBirth", .datetime)
                t.column("knownConditions", .text).notNull()
                t.column("symptomHistory", .text)
                t.column("createdAt", .datetime).notNull()
            }
            try db.create(table: "mealEntry") { t in
                t.column("id", .text).primaryKey()
                t.column("userId", .text).notNull().indexed()
                t.column("photoURL", .text)
                t.column("localPhotoName", .text)
                t.column("timestamp", .datetime).notNull().indexed()
                t.column("ingredients", .text).notNull()
                t.column("mealType", .text).notNull()
                t.column("dishName", .text)
                t.column("userNotes", .text).notNull()
                t.column("needsSync", .boolean).notNull().defaults(to: true)
            }
            try db.create(table: "symptomLog") { t in
                t.column("id", .text).primaryKey()
                t.column("userId", .text).notNull().indexed()
                t.column("mealEntryId", .text).indexed()
                t.column("timestamp", .datetime).notNull().indexed()
                t.column("symptomTypes", .text).notNull()
                t.column("severity", .integer).notNull()
                t.column("notes", .text).notNull()
                t.column("needsSync", .boolean).notNull().defaults(to: true)
            }
            try db.create(table: "allergyProfile") { t in
                t.column("id", .text).notNull()
                t.column("userId", .text).notNull()
                t.column("triggerIngredients", .text).notNull()
                t.column("triggerGroups", .text).notNull()
                t.column("triggerCategories", .text).notNull()
                t.column("mealsAnalyzed", .integer).notNull()
                t.column("symptomLogsAnalyzed", .integer).notNull()
                t.column("lastUpdated", .datetime).notNull()
                t.primaryKey(["userId", "id"])
            }
            try db.create(table: "skinLog") { t in
                t.column("id", .text).primaryKey()
                t.column("userId", .text).notNull().indexed()
                t.column("photoURL", .text)
                t.column("localPhotoName", .text)
                t.column("timestamp", .datetime).notNull()
                t.column("suspectedTriggerKind", .text).notNull()
                t.column("suspectedTrigger", .text).notNull()
                t.column("reactionType", .text).notNull()
                t.column("severity", .integer).notNull()
                t.column("needsSync", .boolean).notNull().defaults(to: true)
            }
            try db.create(table: "bloodworkRecord") { t in
                t.column("id", .text).primaryKey()
                t.column("userId", .text).notNull().indexed()
                t.column("testDate", .datetime).notNull()
                t.column("panelResults", .text).notNull()
                t.column("sourceDocURL", .text)
                t.column("needsSync", .boolean).notNull().defaults(to: true)
            }
            try db.create(table: "dineCode") { t in
                t.column("id", .text).primaryKey()
                t.column("userId", .text).notNull().indexed()
                t.column("token", .text).notNull().unique()
                t.column("qrPayload", .text).notNull()
                t.column("lastGenerated", .datetime).notNull()
                t.column("isActive", .boolean).notNull()
            }
        }
        return migrator
    }

    // MARK: - Users

    func user(id: String) throws -> User? {
        try dbQueue.read { try User.fetchOne($0, key: id) }
    }

    func save(_ user: User) throws {
        try dbQueue.write { try user.save($0) }
    }

    // MARK: - Meals

    func meals(userId: String) throws -> [MealEntry] {
        try dbQueue.read { db in
            try MealEntry.filter(Column("userId") == userId).order(Column("timestamp").desc).fetchAll(db)
        }
    }

    func save(_ meal: MealEntry) throws {
        try dbQueue.write { try meal.save($0) }
    }

    func deleteMeal(id: String) throws {
        _ = try dbQueue.write { db in
            // Detach linked symptom logs so they fall back to time-window matching.
            try db.execute(sql: "UPDATE symptomLog SET mealEntryId = NULL, needsSync = 1 WHERE mealEntryId = ?", arguments: [id])
            return try MealEntry.deleteOne(db, key: id)
        }
    }

    // MARK: - Symptoms

    func symptoms(userId: String) throws -> [SymptomLog] {
        try dbQueue.read { db in
            try SymptomLog.filter(Column("userId") == userId).order(Column("timestamp").desc).fetchAll(db)
        }
    }

    func save(_ log: SymptomLog) throws {
        try dbQueue.write { try log.save($0) }
    }

    func deleteSymptom(id: String) throws {
        _ = try dbQueue.write { try SymptomLog.deleteOne($0, key: id) }
    }

    // MARK: - Profile

    func allergyProfile(userId: String) throws -> AllergyProfile? {
        try dbQueue.read { db in
            try AllergyProfile.filter(Column("userId") == userId && Column("id") == "current").fetchOne(db)
        }
    }

    func save(_ profile: AllergyProfile) throws {
        try dbQueue.write { try profile.save($0) }
    }

    // MARK: - Dine code

    func activeDineCode(userId: String) throws -> DineCode? {
        try dbQueue.read { db in
            try DineCode.filter(Column("userId") == userId && Column("isActive") == true)
                .order(Column("lastGenerated").desc).fetchOne(db)
        }
    }

    func save(_ code: DineCode) throws {
        try dbQueue.write { try code.save($0) }
    }

    // MARK: - Sync bookkeeping

    func unsyncedMeals() throws -> [MealEntry] {
        try dbQueue.read { try MealEntry.filter(Column("needsSync") == true).fetchAll($0) }
    }

    func unsyncedSymptoms() throws -> [SymptomLog] {
        try dbQueue.read { try SymptomLog.filter(Column("needsSync") == true).fetchAll($0) }
    }

    func markSynced(mealId: String, photoURL: String?) throws {
        try dbQueue.write { db in
            try db.execute(sql: "UPDATE mealEntry SET needsSync = 0, photoURL = COALESCE(?, photoURL) WHERE id = ?",
                           arguments: [photoURL, mealId])
        }
    }

    func markSynced(symptomId: String) throws {
        try dbQueue.write { try $0.execute(sql: "UPDATE symptomLog SET needsSync = 0 WHERE id = ?", arguments: [symptomId]) }
    }

    /// Replace local rows with what the server has (used after signing in on a fresh device).
    func importFromRemote(meals: [MealEntry], symptoms: [SymptomLog]) throws {
        try dbQueue.write { db in
            for var meal in meals {
                guard try !MealEntry.exists(db, key: meal.id) else { continue }
                meal.needsSync = false
                try meal.insert(db)
            }
            for var log in symptoms {
                guard try !SymptomLog.exists(db, key: log.id) else { continue }
                log.needsSync = false
                try log.insert(db)
            }
        }
    }

    func wipeAll() throws {
        try dbQueue.write { db in
            for table in ["user", "mealEntry", "symptomLog", "allergyProfile", "skinLog", "bloodworkRecord", "dineCode"] {
                try db.execute(sql: "DELETE FROM \(table)")
            }
        }
    }
}
