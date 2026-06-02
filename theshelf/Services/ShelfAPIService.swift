import Foundation
import Combine

// MARK: - ServerConfig

struct ServerConfig: Codable {
    var baseURL: String          // e.g. "https://192.168.4.185:8773"
    var ignoreTLSErrors: Bool    // true for self-signed cert on Pi

    nonisolated(unsafe) static let `default` = ServerConfig(
        baseURL: "https://192.168.4.185:8773",
        ignoreTLSErrors: true
    )
}

// MARK: - ShelfAPIService

/// All network calls to the Shelf Pi server.
/// Handles self-signed TLS, encodes/decodes JSON, and surfaces errors cleanly.
actor ShelfAPIService: NSObject {

    static let shared = ShelfAPIService()
    private override init() {}

    private var config: ServerConfig = .default
    private lazy var session: URLSession = {
        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest = 15
        return URLSession(configuration: cfg, delegate: self, delegateQueue: nil)
    }()

    func configure(_ config: ServerConfig) {
        self.config = config
    }

    // MARK: - Books

    /// Fetch all books (initial load or full refresh).
    func fetchAllBooks() async throws -> [Book] {
        try await get("/api/books?limit=99999&offset=0")
    }

    /// Fetch books updated since a given ISO 8601 timestamp.
    func fetchBooksSince(_ timestamp: String) async throws -> [Book] {
        let encoded = timestamp.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? timestamp
        return try await get("/api/books?updated_since=\(encoded)")
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

    // MARK: - Covers

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
        let req = try makeRequest(path: path, method: "GET")
        let (data, _) = try await session.data(for: req)
        return try decoder.decode(T.self, from: data)
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
        d.keyDecodingStrategy = .convertFromSnakeCase
        return d
    }()

    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.keyEncodingStrategy = .convertToSnakeCase
        return e
    }()

    private struct EmptyResponse: Codable {}
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
