import Foundation

// MARK: - Pending Mutation
// Represents a change made on-device that hasn't been synced to the server yet.

struct PendingMutation: Codable, Identifiable {
    let id: UUID
    let bookId: String
    let timestamp: Date
    let changes: [String: AnyCodable]  // field name → new value

    init(bookId: String, changes: [String: AnyCodable]) {
        self.id = UUID()
        self.bookId = bookId
        self.timestamp = Date()
        self.changes = changes
    }
}

// MARK: - AnyCodable
// Lightweight wrapper so we can store mixed types in the mutations dict.

struct AnyCodable: Codable {
    let value: Any

    init(_ value: Any) { self.value = value }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let v = try? container.decode(String.self)  { value = v; return }
        if let v = try? container.decode(Int.self)     { value = v; return }
        if let v = try? container.decode(Double.self)  { value = v; return }
        if let v = try? container.decode(Bool.self)    { value = v; return }
        if container.decodeNil()                       { value = NSNull(); return }
        throw DecodingError.typeMismatch(AnyCodable.self,
            .init(codingPath: decoder.codingPath, debugDescription: "Unsupported type"))
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch value {
        case let v as String:   try container.encode(v)
        case let v as Int:      try container.encode(v)
        case let v as Double:   try container.encode(v)
        case let v as Bool:     try container.encode(v)
        case is NSNull:         try container.encodeNil()
        default:
            throw EncodingError.invalidValue(value,
                .init(codingPath: encoder.codingPath, debugDescription: "Unsupported type"))
        }
    }
}

// MARK: - Sync Payload (sent to server)

struct MutationPayload: Codable {
    let bookId: String
    let timestamp: String   // ISO 8601
    let changes: [String: AnyCodable]

    enum CodingKeys: String, CodingKey {
        case bookId = "book_id"
        case timestamp, changes
    }
}

// MARK: - Sync Response (from server)

struct SyncResponse: Codable {
    let updatedBooks: [Book]    // books changed on server since lastSync
    let serverTime: String      // server's current time (use as next lastSync)
    let applied: [String]       // mutation IDs the server accepted

    enum CodingKeys: String, CodingKey {
        case updatedBooks = "updated_books"
        case serverTime = "server_time"
        case applied
    }
}

// MARK: - Search Result (Google Books / Open Library lookup)

struct MetadataResult: Identifiable {
    let id: String
    let title: String
    let author: String
    let isbn: String?
    let isbn13: String?
    let coverUrl: String?
    let description: String?
    let pageCount: Int?
    let publishedDate: String?
    let publisher: String?
    let source: String   // "google" | "openlibrary"
}
