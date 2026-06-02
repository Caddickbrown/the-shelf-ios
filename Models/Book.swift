import Foundation

// MARK: - Book
// Matches the actual library.db schema on the Pi server.

struct Book: Identifiable, Codable, Hashable {
    let id: String
    var title: String
    var author: String
    var status: ReadStatus
    var rating: Int?          // 1–5
    var genre: String?
    var format: String?       // "format" column (e.g. "ebook", "physical")
    var description: String?
    var isbn: String?
    var seriesPos: String?    // "series_pos" — stored as text on server
    var review: String?
    var notes: String?
    var olCoverId: String?
    var coverUrl: String?
    var series: String?
    var yearRead: Int?
    var updatedAt: String     // ISO 8601 — used for sync conflict resolution

    enum CodingKeys: String, CodingKey {
        case id, title, author, status, rating, genre, format, description
        case isbn
        case seriesPos = "series_pos"
        case review, notes
        case olCoverId = "ol_cover_id"
        case coverUrl = "cover_url"
        case series
        case yearRead = "year_read"
        case updatedAt = "updated_at"
    }

    // Thumbnail URL relative to a base URL
    func thumbnailURL(base: String) -> URL? {
        URL(string: "\(base)/cover/\(id).jpg?thumb=1")
    }

    func coverURL(base: String) -> URL? {
        URL(string: "\(base)/cover/\(id).jpg")
    }

    // Whether a local or remote cover is available
    var hasCover: Bool {
        olCoverId != nil || coverUrl != nil
    }
}

// MARK: - ReadStatus

enum ReadStatus: String, Codable, CaseIterable {
    case toRead = "to-read"
    case reading = "reading"
    case read = "read"
    case dnf = "dnf"

    var label: String {
        switch self {
        case .toRead:  return "To Read"
        case .reading: return "Reading"
        case .read:    return "Read"
        case .dnf:     return "Did Not Finish"
        }
    }

    var emoji: String {
        switch self {
        case .toRead:  return "📚"
        case .reading: return "📖"
        case .read:    return "✅"
        case .dnf:     return "🚫"
        }
    }
}

// MARK: - BookType (for new book creation — format field)

enum BookType: String, Codable, CaseIterable {
    case book = "book"
    case manga = "manga"
    case comic = "comic"
    case audiobook = "audiobook"
    case ebook = "ebook"

    var label: String { rawValue.capitalized }
}
