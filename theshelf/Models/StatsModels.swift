import Foundation

// MARK: - Stats Response Models
// Kept separate from StatsView.swift so they are NOT @MainActor-isolated,
// allowing ShelfAPIService (an actor) to decode them without Swift 6 warnings.

struct StatsResponse: Decodable, Sendable {
    let total: Int
    let totalRead: Int
    let totalReading: Int
    let totalToRead: Int
    let avgRating: Double?
    let fiveStars: Int
    let byYear: [YearCount]
    let topAuthors: [AuthorCount]
    let ratings: [String: Int]

    enum CodingKeys: String, CodingKey {
        case total
        case totalRead     = "total_read"
        case totalReading  = "total_reading"
        case totalToRead   = "total_to_read"
        case avgRating     = "avg_rating"
        case fiveStars     = "five_stars"
        case byYear        = "by_year"
        case topAuthors    = "top_authors"
        case ratings
    }

    nonisolated init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        total        = try c.decode(Int.self,           forKey: .total)
        totalRead    = try c.decode(Int.self,           forKey: .totalRead)
        totalReading = try c.decode(Int.self,           forKey: .totalReading)
        totalToRead  = try c.decode(Int.self,           forKey: .totalToRead)
        avgRating    = try c.decodeIfPresent(Double.self, forKey: .avgRating)
        fiveStars    = try c.decode(Int.self,           forKey: .fiveStars)
        byYear       = try c.decode([YearCount].self,   forKey: .byYear)
        topAuthors   = try c.decode([AuthorCount].self, forKey: .topAuthors)
        ratings      = try c.decode([String: Int].self, forKey: .ratings)
    }
}

struct YearCount: Decodable, Identifiable, Sendable {
    let year: Int
    let count: Int
    var id: Int { year }
}

struct AuthorCount: Decodable, Identifiable, Sendable {
    let author: String
    let count: Int
    var id: String { author }
}

struct StatsExtendedResponse: Decodable, Sendable {
    let genres: [GenreCount]
    let monthly: [MonthCount]
    let unreadCount: Int
    let avgPerYear: Double?
    let yearsToClear: Double?
    let formats: [FormatCount]

    enum CodingKeys: String, CodingKey {
        case genres, monthly, formats
        case unreadCount  = "unread_count"
        case avgPerYear   = "avg_per_year"
        case yearsToClear = "years_to_clear"
    }

    nonisolated init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        genres       = try c.decode([GenreCount].self,  forKey: .genres)
        monthly      = try c.decode([MonthCount].self,  forKey: .monthly)
        unreadCount  = try c.decode(Int.self,            forKey: .unreadCount)
        avgPerYear   = try c.decodeIfPresent(Double.self, forKey: .avgPerYear)
        yearsToClear = try c.decodeIfPresent(Double.self, forKey: .yearsToClear)
        formats      = try c.decode([FormatCount].self,  forKey: .formats)
    }
}

struct GenreCount: Decodable, Identifiable, Sendable {
    let genre: String
    let count: Int
    var id: String { genre }
}

struct MonthCount: Decodable, Identifiable, Sendable {
    let month: String
    let count: Int
    var id: String { month }
}

struct FormatCount: Decodable, Identifiable, Sendable {
    let format: String
    let count: Int
    var id: String { format }
}
