import Foundation

// MARK: - Stats Response Models
// Kept separate from StatsView.swift so they are NOT @MainActor-isolated,
// allowing ShelfAPIService (an actor) to decode them without Swift 6 warnings.

struct StatsResponse: Decodable {
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
}

struct YearCount: Decodable, Identifiable {
    let year: Int
    let count: Int
    var id: Int { year }
}

struct AuthorCount: Decodable, Identifiable {
    let author: String
    let count: Int
    var id: String { author }
}

struct StatsExtendedResponse: Decodable {
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
}

struct GenreCount: Decodable, Identifiable {
    let genre: String
    let count: Int
    var id: String { genre }
}

struct MonthCount: Decodable, Identifiable {
    let month: String
    let count: Int
    var id: String { month }
}

struct FormatCount: Decodable, Identifiable {
    let format: String
    let count: Int
    var id: String { format }
}
