import Foundation
import SwiftUI

// MARK: - BookStore
// Single source of truth for all book data on device.
// Persists to disk for offline use, merges with server on sync.

@Observable
@MainActor
final class BookStore {

    static let shared = BookStore()
    private init() { load() }

    // MARK: - State

    private(set) var books: [Book] = []
    private(set) var isLoading = false
    private(set) var lastError: String?

    var isEmpty: Bool { books.isEmpty }

    // MARK: - Derived views

    func books(status: ReadStatus) -> [Book] {
        books.filter { $0.status == status }
            .sorted { $0.title < $1.title }
    }

    func books(matching query: String) -> [Book] {
        guard !query.isEmpty else { return books }
        let q = query.lowercased()
        return books.filter {
            $0.title.lowercased().contains(q) ||
            $0.author.lowercased().contains(q) ||
            ($0.series?.lowercased().contains(q) ?? false) ||
            ($0.isbn?.contains(q) ?? false) ||
            ($0.isbn13?.contains(q) ?? false)
        }
    }

    func book(id: String) -> Book? {
        books.first { $0.id == id }
    }

    var currentlyReading: [Book] {
        books.filter { $0.status == .reading }
            .sorted { ($0.startDate ?? "") > ($1.startDate ?? "") }
    }

    var recentlyRead: [Book] {
        books.filter { $0.status == .read }
            .sorted { ($0.endDate ?? "") > ($1.endDate ?? "") }
            .prefix(20).map { $0 }
    }

    // MARK: - Local mutations
    // These update the in-memory store immediately and enqueue a sync mutation.

    func updateStatus(_ id: String, status: ReadStatus,
                      startDate: String? = nil, endDate: String? = nil) {
        guard let idx = books.firstIndex(where: { $0.id == id }) else { return }
        books[idx].status = status
        if let d = startDate { books[idx].startDate = d }
        if let d = endDate   { books[idx].endDate = d }
        books[idx].updatedAt = nowISO()

        var changes: [String: Any] = ["status": status.rawValue]
        if let d = startDate { changes["start_date"] = d }
        if let d = endDate   { changes["end_date"] = d }
        SyncEngine.shared.enqueue(bookId: id, changes: changes)
        persist()
    }

    func updateRating(_ id: String, rating: Int?) {
        guard let idx = books.firstIndex(where: { $0.id == id }) else { return }
        books[idx].rating = rating
        books[idx].updatedAt = nowISO()
        SyncEngine.shared.enqueue(bookId: id, changes: ["rating": rating as Any])
        persist()
    }

    func updateReview(_ id: String, review: String?) {
        guard let idx = books.firstIndex(where: { $0.id == id }) else { return }
        books[idx].review = review
        books[idx].updatedAt = nowISO()
        SyncEngine.shared.enqueue(bookId: id, changes: ["review": review as Any])
        persist()
    }

    func updateProgress(_ id: String, currentPage: Int?) {
        guard let idx = books.firstIndex(where: { $0.id == id }) else { return }
        books[idx].currentPage = currentPage
        books[idx].updatedAt = nowISO()
        SyncEngine.shared.enqueue(bookId: id, changes: ["current_page": currentPage as Any])
        persist()
    }

    func updateFields(_ id: String, changes: [String: Any]) {
        guard let idx = books.firstIndex(where: { $0.id == id }) else { return }
        applyChanges(to: &books[idx], changes: changes)
        books[idx].updatedAt = nowISO()
        SyncEngine.shared.enqueue(bookId: id, changes: changes)
        persist()
    }

    func addBook(_ book: Book) {
        books.append(book)
        persist()
    }

    func removeBook(id: String) {
        books.removeAll { $0.id == id }
        persist()
    }

    // MARK: - Server merge (called by SyncEngine)

    /// Merges server-updated books using last-write-wins per book.
    /// A book with a pending local mutation keeps local version if local timestamp is newer.
    func mergeFromServer(_ serverBooks: [Book], pendingMutations: [PendingMutation]) {
        let pendingIds = Set(pendingMutations.map { $0.bookId })
        for serverBook in serverBooks {
            if let idx = books.firstIndex(where: { $0.id == serverBook.id }) {
                let local = books[idx]
                if pendingIds.contains(local.id) {
                    // We have pending mutations — keep local if newer
                    if local.updatedAt >= serverBook.updatedAt { continue }
                }
                books[idx] = serverBook
            } else {
                books.append(serverBook)
            }
        }
        persist()
    }

    // MARK: - Full refresh from server

    func loadFromServer() async {
        isLoading = true
        lastError = nil
        defer { isLoading = false }
        do {
            let fetched = try await ShelfAPIService.shared.fetchAllBooks()
            books = fetched
            persist()
        } catch {
            lastError = error.localizedDescription
        }
    }

    // MARK: - Disk persistence (offline support)

    private let storageKey = "shelf.books"

    private func persist() {
        if let data = try? JSONEncoder().encode(books) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let stored = try? JSONDecoder().decode([Book].self, from: data) else { return }
        books = stored
    }

    // MARK: - Helpers

    private func nowISO() -> String {
        ISO8601DateFormatter().string(from: Date())
    }

    private func applyChanges(to book: inout Book, changes: [String: Any]) {
        for (key, value) in changes {
            switch key {
            case "title":           if let v = value as? String  { book.title = v }
            case "author":          if let v = value as? String  { book.author = v }
            case "status":          if let v = value as? String, let s = ReadStatus(rawValue: v) { book.status = s }
            case "rating":          book.rating = value as? Int
            case "genre":           book.genre = value as? String
            case "description":     book.description = value as? String
            case "review":          book.review = value as? String
            case "notes":           book.notes = value as? String
            case "current_page":    book.currentPage = value as? Int
            case "page_count":      book.pageCount = value as? Int
            case "start_date":      book.startDate = value as? String
            case "end_date":        book.endDate = value as? String
            case "series":          book.series = value as? String
            case "series_position": book.seriesPosition = value as? Double
            case "publisher":       book.publisher = value as? String
            case "published_date":  book.publishedDate = value as? String
            case "language":        book.language = value as? String
            default: break
            }
        }
    }
}
