import Foundation

/// The user's shareable restaurant card. The QR encodes only `qrPayload` (a URL containing an
/// unguessable token); the readable profile lives in the public `dineCodes/{token}` Firestore doc,
/// so it can be updated without regenerating the code.
struct DineCode: Codable, Identifiable, Equatable {
    var id: String
    var userId: String
    /// Random 128-bit+ capability token (base62). Acts as the document id of the public snapshot.
    var token: String
    var qrPayload: String
    var lastGenerated: Date
    var isActive: Bool
}

/// The public, restaurant-facing snapshot. Deliberately minimal: first name + what to avoid.
struct DineCodeSnapshot: Codable, Equatable {
    struct Item: Codable, Equatable {
        var name: String
        /// "Confirmed allergy" | "Positive blood test" | "Likely trigger" | "Watching"
        var level: String
    }

    var ownerUid: String
    var displayName: String
    var isActive: Bool
    var avoid: [Item]
    var note: String
    var updatedAt: Date
}
