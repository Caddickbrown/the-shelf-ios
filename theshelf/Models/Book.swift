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
    var type: BookType?
    var description: String?
    var isbn: String?
    var isbn13: String?
    var seriesPos: String?
    var review: String?
    var notes: String?
    var olCoverId: Int?
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
    var readingOrder: Int?

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
        case readingOrder = "reading_order"
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

extension Book {
    nonisolated init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id              = try c.decode(String.self, forKey: .id)
        title           = try c.decode(String.self, forKey: .title)
        author          = try c.decode(String.self, forKey: .author)
        status          = try c.decode(ReadStatus.self, forKey: .status)
        rating          = try c.decodeIfPresent(Int.self, forKey: .rating)
        genre           = try c.decodeIfPresent(String.self, forKey: .genre)
        type            = try c.decodeIfPresent(BookType.self, forKey: .type)
        description     = try c.decodeIfPresent(String.self, forKey: .description)
        isbn            = try c.decodeIfPresent(String.self, forKey: .isbn)
        isbn13          = try c.decodeIfPresent(String.self, forKey: .isbn13)
        review          = try c.decodeIfPresent(String.self, forKey: .review)
        notes           = try c.decodeIfPresent(String.self, forKey: .notes)
        olCoverId       = try c.decodeIfPresent(Int.self, forKey: .olCoverId)
        coverUrl        = try c.decodeIfPresent(String.self, forKey: .coverUrl)
        series          = try c.decodeIfPresent(String.self, forKey: .series)
        yearRead        = try c.decodeIfPresent(Int.self, forKey: .yearRead)
        startDate       = try c.decodeIfPresent(String.self, forKey: .startDate)
        endDate         = try c.decodeIfPresent(String.self, forKey: .endDate)
        currentPage     = try c.decodeIfPresent(Int.self, forKey: .currentPage)
        pageCount       = try c.decodeIfPresent(Int.self, forKey: .pageCount)
        seriesPosition  = try c.decodeIfPresent(Double.self, forKey: .seriesPosition)
        publisher       = try c.decodeIfPresent(String.self, forKey: .publisher)
        publishedDate   = try c.decodeIfPresent(String.self, forKey: .publishedDate)
        language        = try c.decodeIfPresent(String.self, forKey: .language)
        updatedAt       = (try? c.decodeIfPresent(String.self, forKey: .updatedAt)) ?? ""
        readingOrder    = try c.decodeIfPresent(Int.self, forKey: .readingOrder)

        // series_pos: server may send string "1", float 1.0, or null.
        // Try Double first (most common from server), format cleanly, preserve .5 etc.
        if let d = try? c.decodeIfPresent(Double.self, forKey: .seriesPos) {
            seriesPos = d.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(d))" : "\(d)"
        } else if let s = try? c.decodeIfPresent(String.self, forKey: .seriesPos),
                  let s, !s.isEmpty, s != "-" {
            seriesPos = s
        } else {
            seriesPos = nil
        }
    }
}

// MARK: - ReadStatus

enum ReadStatus: String, Codable, CaseIterable {
    case toRead = "to-read"
    case reading = "reading"
    case read = "read"
    case dnf = "dnf"

    nonisolated init(from decoder: any Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        guard let value = ReadStatus(rawValue: raw) else {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Invalid ReadStatus: \(raw)"))
        }
        self = value
    }

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

    nonisolated init(from decoder: any Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = BookType(rawValue: raw) ?? .book
    }
}

// MARK: - ReadingLogEntry

struct ReadingLogEntry: Identifiable, Decodable {
    let id: Int
    let bookId: String
    let dateStarted: String?
    let dateFinished: String?
    let yearRead: Int?
    let rating: Int?
    let review: String?

    enum CodingKeys: String, CodingKey {
        case id
        case bookId = "book_id"
        case dateStarted = "date_started"
        case dateFinished = "date_finished"
        case yearRead = "year_read"
        case rating
        case review
    }
}
