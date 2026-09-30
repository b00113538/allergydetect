import UIKit

/// Stores meal photos on-device so logging works offline; `FirebaseService` uploads them later.
enum PhotoStore {
    static var directory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = base.appendingPathComponent("photos", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    /// Saves a JPEG and returns its file name.
    static func save(_ image: UIImage, id: String) throws -> String {
        let name = "\(id).jpg"
        guard let data = image.nouriJPEGData() else { throw CocoaError(.fileWriteUnknown) }
        try data.write(to: directory.appendingPathComponent(name), options: .atomic)
        return name
    }

    static func data(named name: String) -> Data? {
        try? Data(contentsOf: directory.appendingPathComponent(name))
    }

    static func image(named name: String) -> UIImage? {
        data(named: name).flatMap(UIImage.init(data:))
    }

    static func delete(named name: String) {
        try? FileManager.default.removeItem(at: directory.appendingPathComponent(name))
    }

    /// Removes every stored photo (sign-out / account deletion).
    static func deleteAll() {
        try? FileManager.default.removeItem(at: directory)
    }
}

extension UIImage {
    /// Downscales so the long edge is ≤ `maxDimension` (1568px is the largest size Claude vision
    /// uses without resizing) and encodes as JPEG. Keeps uploads and API payloads small.
    func nouriJPEGData(maxDimension: CGFloat = 1568, quality: CGFloat = 0.7) -> Data? {
        let longEdge = max(size.width, size.height)
        let scale = longEdge > maxDimension ? maxDimension / longEdge : 1
        let target = CGSize(width: (size.width * scale).rounded(), height: (size.height * scale).rounded())
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let resized = UIGraphicsImageRenderer(size: target, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: target))
        }
        return resized.jpegData(compressionQuality: quality)
    }
}
