import Foundation

// MARK: - Book
// Matches the actual library.db schema on the Pi server.

struct Book: Identifiable, Codable, Hashable {
    let id: String
    var title: String
    var author: String
    var status: ReadStatus
    var rating: Int?
    var genre: String?
    var format: String?
    var description: String?
    var isbn: String?
    var seriesPos: String?
    var review: String?
    var notes: String?
    var olCoverId: Int?        // integer from server (Open Library cover ID)
    var coverUrl: String?
    var series: String?
    var yearRead: Int?
    var updatedAt: String

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

    // Custom decoder: handle "-" placeholders for series fields, unknown status values
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id          = try c.decode(String.self, forKey: .id)
        title       = try c.decode(String.self, forKey: .title)
        author      = try c.decode(String.self, forKey: .author)
        rating      = try c.decodeIfPresent(Int.self, forKey: .rating)
        genre       = try c.decodeIfPresent(String.self, forKey: .genre)
        format      = try c.decodeIfPresent(String.self, forKey: .format)
        description = try c.decodeIfPresent(String.self, forKey: .description)
        isbn        = try c.decodeIfPresent(String.self, forKey: .isbn)
        review      = try c.decodeIfPresent(String.self, forKey: .review)
        notes       = try c.decodeIfPresent(String.self, forKey: .notes)
        olCoverId   = try c.decodeIfPresent(Int.self, forKey: .olCoverId)
        coverUrl    = try c.decodeIfPresent(String.self, forKey: .coverUrl)
        yearRead    = try c.decodeIfPresent(Int.self, forKey: .yearRead)
        updatedAt   = (try? c.decodeIfPresent(String.self, forKey: .updatedAt)) ?? "1970-01-01T00:00:00"

        // series/series_pos: treat "-" or empty string as nil
        let rawSeries = try c.decodeIfPresent(String.self, forKey: .series)
        series = (rawSeries == nil || rawSeries == "-" || rawSeries == "") ? nil : rawSeries
        let rawPos = try c.decodeIfPresent(String.self, forKey: .seriesPos)
        seriesPos = (rawPos == nil || rawPos == "-" || rawPos == "") ? nil : rawPos

        // status: fall back to .toRead for unknown values
        let rawStatus = (try? c.decodeIfPresent(String.self, forKey: .status)) ?? "to-read"
        status = ReadStatus(rawValue: rawStatus ?? "to-read") ?? .toRead
    }

    var hasCover: Bool { olCoverId != nil || coverUrl != nil }

    func thumbnailURL(base: String) -> URL? { URL(string: "\(base)/cover/\(id).jpg?thumb=1") }
    func coverURL(base: String) -> URL? { URL(string: "\(base)/cover/\(id).jpg") }
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

// MARK: - BookType (for new book creation)

enum BookType: String, Codable, CaseIterable {
    case book = "book"
    case manga = "manga"
    case comic = "comic"
    case audiobook = "audiobook"
    case ebook = "ebook"

    var label: String { rawValue.capitalized }
}

