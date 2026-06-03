import Foundation

// MARK: - ServerConfig

struct ServerConfig: Codable {
    var baseURL: String          // e.g. "https://192.168.4.185:8773"
    var ignoreTLSErrors: Bool    // true for self-signed cert on Pi
    var fallbackURL: String?     // tried if baseURL fails

    static let `default` = ServerConfig(
        baseURL: "https://192.168.4.185:8773",
        ignoreTLSErrors: true,
        fallbackURL: nil
    )
}

// MARK: - ShelfAPIService

/// All network calls to the Shelf Pi server.
/// Handles self-signed TLS, encodes/decodes JSON, and surfaces errors cleanly.
actor ShelfAPIService: NSObject {

    static let shared = ShelfAPIService()
    private override init() {}

    private var config = ServerConfig(baseURL: "https://192.168.4.185:8773", ignoreTLSErrors: true)
    private lazy var session: URLSession = {
        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest = 15
        return URLSession(configuration: cfg, delegate: self, delegateQueue: nil)
    }()

    func configure(_ config: ServerConfig) {
        self.config = config
    }

    // MARK: - Paged response envelope

    private struct BooksEnvelope: Decodable {
        let books: [Book]
        let total: Int?
        let hasMore: Bool?
        enum CodingKeys: String, CodingKey {
            case books, total
            case hasMore = "has_more"
        }
    }

    // MARK: - Books

    /// Fetch all books (initial load or full refresh). Paginates until server reports no more.
    func fetchAllBooks() async throws -> [Book] {
        var all: [Book] = []
        var offset = 0
        let limit = 500
        while true {
            let envelope: BooksEnvelope = try await get("/api/books?limit=\(limit)&offset=\(offset)")
            all.append(contentsOf: envelope.books)
            guard envelope.hasMore == true else { break }
            offset += limit
        }
        return all
    }

    /// Fetch books updated since a given ISO 8601 timestamp.
    func fetchBooksSince(_ timestamp: String) async throws -> [Book] {
        let encoded = timestamp.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? timestamp
        let envelope: BooksEnvelope = try await get("/api/books?updated_since=\(encoded)&limit=500")
        return envelope.books
    }

    /// Apply a batch of mutations to the server.
    func pushMutations(_ mutations: [MutationPayload]) async throws -> [String] {
        struct Response: Codable { let applied: [String] }
        let resp: Response = try await post("/api/sync/mutations", body: mutations)
        return resp.applied
    }

    /// Create a new book.
    func createBook(_ book: BookCreateRequest) async throws -> Book {
        try await post("/api/books", body: book)
    }

    /// Full book update.
    func updateBook(id: String, changes: [String: Any]) async throws -> Book {
        let data = try JSONSerialization.data(withJSONObject: changes)
        return try await put("/api/books/\(id)", body: data)
    }

    /// Delete a book.
    func deleteBook(id: String) async throws {
        try await delete("/api/books/\(id)")
    }

    /// Fetch reading history for a book from /api/books/:id/reads
    func fetchReadingLog(bookId: String) async throws -> [ReadingLogEntry] {
        struct Envelope: Decodable { let reads: [ReadingLogEntry] }
        let env: Envelope = try await get("/api/books/\(bookId)/reads")
        return env.reads
    }

    /// Add a new reading log entry for a book.
    func addReadingLogEntry(bookId: String, dateStarted: String?, dateFinished: String?, rating: Int?, review: String?) async throws {
        struct Payload: Encodable {
            let date_started: String?
            let date_finished: String?
            let rating: Int?
            let review: String?
        }
        struct Resp: Decodable { let id: Int }
        let _: Resp = try await post("/api/books/\(bookId)/reads",
            body: Payload(date_started: dateStarted, date_finished: dateFinished, rating: rating, review: review))
    }

    /// Update an existing reading log entry.
    func updateReadingLogEntry(id: Int, dateStarted: String?, dateFinished: String?, rating: Int?, review: String?) async throws {
        struct Payload: Encodable {
            let date_started: String?
            let date_finished: String?
            let rating: Int?
            let review: String?
        }
        struct Resp: Decodable { let ok: Bool }
        let _: Resp = try await put("/api/reading-log/\(id)",
            body: try JSONEncoder().encode(Payload(date_started: dateStarted, date_finished: dateFinished, rating: rating, review: review)))
    }

    /// Delete a reading log entry.
    func deleteReadingLogEntry(id: Int) async throws {
        try await delete("/api/reading-log/\(id)")
    }

    // MARK: - Manga

    /// Fetch all manga from /api/manga. Items are mapped to the shared Book model.
    func fetchManga() async throws -> [Book] {
        struct MangaEnvelope: Decodable {
            let manga: [MangaItem]
        }
        struct MangaItem: Decodable {
            let id: String
            let title: String
            let author: String
            let status: ReadStatus
            let notes: String?
            let series: String?
            let seriesPos: Double?   // volume number (series_pos in JSON)
            let olCoverId: Int?
            let readingOrder: Int?

            enum CodingKeys: String, CodingKey {
                case id, title, author, status, notes, series
                case seriesPos    = "series_pos"
                case olCoverId    = "ol_cover_id"
                case readingOrder = "reading_order"
            }
        }

        let envelope: MangaEnvelope = try await get("/api/manga")
        let now = ISO8601DateFormatter().string(from: Date())

        return envelope.manga.map { item in
            // Convert Double volume number to a clean string ("1" not "1.0")
            let posStr: String? = item.seriesPos.map { d in
                d.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(d))" : "\(d)"
            }
            return Book(
                id: item.id,
                title: item.title,
                author: item.author,
                status: item.status,
                rating: nil,
                genre: nil,
                type: .manga,
                description: nil,
                isbn: nil,
                isbn13: nil,
                seriesPos: posStr,
                review: nil,
                notes: item.notes,
                olCoverId: item.olCoverId,
                coverUrl: nil,
                series: item.series,
                yearRead: nil,
                startDate: nil,
                endDate: nil,
                currentPage: nil,
                pageCount: nil,
                seriesPosition: item.seriesPos,
                publisher: nil,
                publishedDate: nil,
                language: nil,
                updatedAt: now,
                readingOrder: item.readingOrder
            )
        }
    }

    // MARK: - Covers

    /// Fetch raw data from a URL using the trusted session (handles self-signed certs).
    func fetchData(from url: URL) async throws -> Data {
        try await session.data(from: url).0
    }

    /// Thumbnail — small, used in list views.
    func thumbnailURL(bookId: String) -> URL? {
        URL(string: "\(config.baseURL)/cover/\(bookId).jpg?thumb=1")
    }

    /// Full cover URL.
    func coverURL(bookId: String) -> URL? {
        URL(string: "\(config.baseURL)/cover/\(bookId).jpg")
    }

    /// Upload a cover image (JPEG data).
    func uploadCover(bookId: String, jpegData: Data) async throws {
        struct Payload: Codable { let image: String; let filename: String }
        let b64 = jpegData.base64EncodedString()
        let _: EmptyResponse = try await post("/api/books/\(bookId)/cover",
                                               body: Payload(image: b64, filename: "\(bookId).jpg"))
    }

    // MARK: - Metadata lookup (Google Books / Open Library)

    func lookupISBN(_ isbn: String) async throws -> [MetadataResult] {
        struct GBResponse: Codable {
            struct Item: Codable {
                struct Info: Codable {
                    let title: String?
                    let authors: [String]?
                    let description: String?
                    let pageCount: Int?
                    let publishedDate: String?
                    let publisher: String?
                    let imageLinks: ImageLinks?
                    let industryIdentifiers: [Identifier]?
                    struct ImageLinks: Codable { let thumbnail: String? }
                    struct Identifier: Codable { let type: String; let identifier: String }
                }
                let id: String
                let volumeInfo: Info
            }
            let items: [Item]?
        }

        let url = "https://www.googleapis.com/books/v1/volumes?q=isbn:\(isbn)"
        guard let u = URL(string: url) else { return [] }
        let (data, _) = try await URLSession.shared.data(from: u)
        let resp = try JSONDecoder().decode(GBResponse.self, from: data)
        return resp.items?.map { item in
            let info = item.volumeInfo
            let isbn13 = info.industryIdentifiers?.first(where: { $0.type == "ISBN_13" })?.identifier
            let isbn10 = info.industryIdentifiers?.first(where: { $0.type == "ISBN_10" })?.identifier
            return MetadataResult(
                id: item.id,
                title: info.title ?? "Unknown",
                author: info.authors?.joined(separator: ", ") ?? "Unknown",
                isbn: isbn10,
                isbn13: isbn13,
                coverUrl: info.imageLinks?.thumbnail?.replacingOccurrences(of: "http:", with: "https:"),
                description: info.description,
                pageCount: info.pageCount,
                publishedDate: info.publishedDate,
                publisher: info.publisher,
                source: "google"
            )
        } ?? []
    }

    // MARK: - Shelves

    func fetchShelves() async throws -> [Shelf] {
        try await get("/api/shelves")
    }

    func addBookToShelf(bookId: String, shelfId: String) async throws {
        struct Payload: Codable { let book_id: String }
        let _: EmptyResponse = try await post("/api/shelves/\(shelfId)/books", body: Payload(book_id: bookId))
    }

    // MARK: - Private helpers

    private func get<T: Decodable>(_ path: String) async throws -> T {
        do {
            return try await getFromBase(config.baseURL, path: path)
        } catch {
            // Try fallback if primary fails and a fallback is configured
            if let fallback = config.fallbackURL, !fallback.isEmpty {
                return try await getFromBase(fallback, path: path)
            }
            throw error
        }
    }

    private func getFromBase<T: Decodable>(_ base: String, path: String) async throws -> T {
        guard let url = URL(string: base + path) else { throw URLError(.badURL) }
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        let (data, response) = try await session.data(for: req)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            let body = String(data: data, encoding: .utf8) ?? "<binary>"
            throw ShelfError.httpError(http.statusCode, body)
        }
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            let preview = String(data: data.prefix(800), encoding: .utf8) ?? "<unreadable>"
            throw ShelfError.decodingError("\(type(of: error)): \(error)", preview)
        }
    }

    private func post<T: Decodable, B: Encodable>(_ path: String, body: B) async throws -> T {
        var req = try makeRequest(path: path, method: "POST")
        req.httpBody = try encoder.encode(body)
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let (data, _) = try await session.data(for: req)
        return try decoder.decode(T.self, from: data)
    }

    private func put<T: Decodable>(_ path: String, body: Data) async throws -> T {
        var req = try makeRequest(path: path, method: "PUT")
        req.httpBody = body
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let (data, _) = try await session.data(for: req)
        return try decoder.decode(T.self, from: data)
    }

    private func delete(_ path: String) async throws {
        let req = try makeRequest(path: path, method: "DELETE")
        _ = try await session.data(for: req)
    }

    private func makeRequest(path: String, method: String) throws -> URLRequest {
        guard let url = URL(string: config.baseURL + path) else {
            throw URLError(.badURL)
        }
        var req = URLRequest(url: url)
        req.httpMethod = method
        return req
    }

    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        return d
    }()

    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.keyEncodingStrategy = .convertToSnakeCase
        return e
    }()

    private struct EmptyResponse: Codable {}

    // MARK: - Stats

    func fetchStats() async throws -> StatsResponse {
        try await get("/api/stats")
    }

    func fetchStatsExtended() async throws -> StatsExtendedResponse {
        try await get("/api/stats/extended")
    }
}

// MARK: - TLS delegate (accept self-signed Pi cert)

extension ShelfAPIService: URLSessionDelegate {
    nonisolated func urlSession(_ session: URLSession,
                     didReceive challenge: URLAuthenticationChallenge,
                     completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
           let trust = challenge.protectionSpace.serverTrust {
            completionHandler(.useCredential, URLCredential(trust: trust))
        } else {
            completionHandler(.performDefaultHandling, nil)
        }
    }
}

// MARK: - ShelfError

enum ShelfError: LocalizedError {
    case httpError(Int, String)
    case decodingError(String, String)   // swift error description, raw response preview
    case networkError(String, String)    // error type, message

    var errorDescription: String? {
        switch self {
        case .httpError(let code, let body):
            return "HTTP \(code):\n\(body.prefix(400))"
        case .decodingError(let msg, let preview):
            return "Decode error:\n\(msg)\n\nRaw server response:\n\(preview)"
        case .networkError(let kind, let msg):
            return "Network error (\(kind)):\n\(msg)"
        }
    }
}

// MARK: - BookCreateRequest

struct BookCreateRequest: Codable {
    var title: String
    var author: String
    var status: ReadStatus
    var isbn: String?
    var isbn13: String?
    var pageCount: Int?
    var genre: String?
    var description: String?
    var coverUrl: String?
    var type: BookType
    var publishedDate: String?
    var publisher: String?
}

// MARK: - Shelf (lightweight)

struct Shelf: Identifiable, Codable {
    let id: String
    var name: String
    var description: String?
    var bookCount: Int?

    enum CodingKeys: String, CodingKey {
        case id, name, description
        case bookCount = "book_count"
    }
}
