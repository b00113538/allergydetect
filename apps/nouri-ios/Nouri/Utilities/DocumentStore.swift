import Foundation

/// On-device copies of uploaded blood work reports (PDF or JPEG), kept so the record works
/// offline; `FirebaseService` uploads them to Cloud Storage on the next sync.
enum DocumentStore {
    static var directory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = base.appendingPathComponent("documents", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    /// Saves the document and returns its file name.
    static func save(_ data: Data, id: String, type: BloodworkRecord.DocumentType) throws -> String {
        let name = "\(id).\(type.fileExtension)"
        try data.write(to: url(named: name), options: [.atomic, .completeFileProtection])
        return name
    }

    static func url(named name: String) -> URL { directory.appendingPathComponent(name) }

    static func data(named name: String) -> Data? { try? Data(contentsOf: url(named: name)) }

    static func delete(named name: String) {
        try? FileManager.default.removeItem(at: url(named: name))
    }
}
