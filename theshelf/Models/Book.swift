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
    var type: BookType
    var description: String?
    var isbn: String?
    var isbn13: String?
    var seriesPos: String?
    var review: String?
    var notes: String?
    var olCoverId: String?
    var coverUrl: String?
    var series: String?
    var yearRead: Int?
    var startDate: String?
    var endDate: String?
    var currentPage: Int?
    var pageCount: Int?
    var seriesPosition: Double?
    var publisher: String?
    var publishedDate: String?
    var language: String?
    var updatedAt: String

    enum CodingKeys: String, CodingKey {
        case id, title, author, status, rating, genre, description
        case type = "format"
        case isbn
        case isbn13 = "isbn13"
        case seriesPos = "series_pos"
        case review, notes
        case olCoverId = "ol_cover_id"
        case coverUrl = "cover_url"
        case series
        case yearRead = "year_read"
        case startDate = "start_date"
        case endDate = "end_date"
        case currentPage = "current_page"
        case pageCount = "page_count"
        case seriesPosition = "series_position"
        case publisher
        case publishedDate = "published_date"
        case language
        case updatedAt = "updated_at"
    }

    var progress: Double? {
        guard let cp = currentPage, let pc = pageCount, pc > 0 else { return nil }
        return Double(cp) / Double(pc)
    }

    func thumbnailURL(base: String) -> URL? {
        URL(string: "\(base)/cover/\(id).jpg?thumb=1")
    }

    func coverURL(base: String) -> URL? {
        URL(string: "\(base)/cover/\(id).jpg")
    }

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

    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = BookType(rawValue: raw) ?? .book
    }
}
