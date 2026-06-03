import Foundation
import SwiftUI

// MARK: - SyncEngine
// Manages the offline mutation queue, periodic sync, and last-write-wins conflict resolution.

@Observable
@MainActor
final class SyncEngine {

    static let shared = SyncEngine()
    private init() {
        loadQueue()
        loadLastSyncTimestamp()
    }

    // MARK: - State

    private(set) var isSyncing = false
    private(set) var lastSyncDate: Date?
    private(set) var pendingCount: Int = 0
    private(set) var lastError: String?

    // Don't hammer the server — minimum 30s between automatic syncs
    private let minSyncInterval: TimeInterval = 30

    private var mutationQueue: [PendingMutation] = []
    private var deleteQueue: [String] = []   // book IDs pending deletion on server
    private(set) var pendingCreateIds: Set<String> = []  // temp local IDs not yet confirmed by server
    private let queueKey = "shelf.pendingMutations"
    private let deleteQueueKey = "shelf.pendingDeletes"
    private let lastSyncKey = "shelf.lastSync"
    private let api = ShelfAPIService.shared

    // MARK: - Enqueue a local change

    /// Call this every time the user edits a book locally.
    /// The changes dict uses server field names (snake_case).
    func enqueue(bookId: String, changes: [String: Any]) {
        let coded = changes.compactMapValues { AnyCodable($0) }
        let mutation = PendingMutation(bookId: bookId, changes: coded)
        mutationQueue.append(mutation)
        pendingCount = mutationQueue.count + deleteQueue.count
        persistQueue()
    }

    /// Track a locally-added book (temp UUID) so deletion detection doesn't wipe it.
    func enqueueCreate(tempId: String) {
        pendingCreateIds.insert(tempId)
    }

    /// Call once the server has confirmed the create and the local book has been swapped.
    func confirmCreate(tempId: String) {
        pendingCreateIds.remove(tempId)
    }

    /// Queue a book deletion to sync when back online.
    func enqueueDelete(bookId: String) {
        // Drop any pending mutations for this book — no point pushing edits for something deleted
        mutationQueue.removeAll { $0.bookId == bookId }
        if !deleteQueue.contains(bookId) {
            deleteQueue.append(bookId)
        }
        pendingCount = mutationQueue.count + deleteQueue.count
        persistQueue()
    }

    // MARK: - Sync

    /// Full two-way sync:
    /// 1. Push pending mutations to server
    /// 2. Pull all books changed on server since lastSync
    /// 3. Merge with last-write-wins
    @discardableResult
    func sync(store: BookStore) async -> Bool {
        // Rate-limit automatic syncs; manual syncs (from button) always go through
        if let last = lastSyncDate, Date().timeIntervalSince(last) < minSyncInterval, !mutationQueue.isEmpty == false {
            return false
        }
        guard !isSyncing else { return false }
        isSyncing = true
        lastError = nil
        defer { isSyncing = false }

        do {
            // Step 0: push pending deletes
            var failedDeletes: [String] = []
            for bookId in deleteQueue {
                do {
                    try await api.deleteBook(id: bookId)
                } catch {
                    failedDeletes.append(bookId)  // keep for retry if offline
                }
            }
            deleteQueue = failedDeletes
            pendingCount = mutationQueue.count + deleteQueue.count
            persistQueue()

            // Step 1: push local mutations
            if !mutationQueue.isEmpty {
                let payloads = mutationQueue.map { m in
                    MutationPayload(
                        id: m.id.uuidString,
                        bookId: m.bookId,
                        timestamp: ISO8601DateFormatter().string(from: m.timestamp),
                        changes: m.changes
                    )
                }
                let applied = try await api.pushMutations(payloads)
                // Remove successfully applied mutations
                mutationQueue.removeAll { m in applied.contains(m.id.uuidString) }
                pendingCount = mutationQueue.count
                persistQueue()
            }

            // Step 2: pull server changes
            // First launch, empty store, or cleared data: paginated full fetch
            // Subsequent syncs: incremental pull only changed books
            let serverBooks: [Book]
            if lastSyncTimestamp == nil || store.books.isEmpty {
                if store.books.isEmpty { lastSyncTimestamp = nil } // reset stale timestamp
                serverBooks = try await api.fetchAllBooks()
            } else {
                serverBooks = try await api.fetchBooksSince(lastSyncTimestamp!)
            }

            // Step 3: merge — server wins unless we have a newer local mutation for that field
            store.mergeFromServer(serverBooks, pendingMutations: mutationQueue)

            // Step 3b: detect deletions — if we did an incremental sync, check if server
            // has fewer books than local (books were deleted). If so, do a full refresh.
            // Exclude locally-added books not yet confirmed by server from the comparison.
            if lastSyncTimestamp != nil && !serverBooks.isEmpty {
                let serverTotal = try await api.fetchTotalCount()
                let localConfirmedCount = store.books.count - pendingCreateIds.count
                if serverTotal < localConfirmedCount {
                    let allBooks = try await api.fetchAllBooks()
                    // Preserve any locally-added books not yet on server
                    let serverIds = Set(allBooks.map { $0.id })
                    let localOnly = store.books.filter { pendingCreateIds.contains($0.id) && !serverIds.contains($0.id) }
                    store.replaceAll(allBooks + localOnly)
                }
            }

            // Update sync timestamp
            lastSyncDate = Date()
            lastSyncTimestamp = ISO8601DateFormatter().string(from: lastSyncDate!)
            return true
        } catch {
            lastError = error.localizedDescription
            return false
        }
    }

    // MARK: - Persistence

    private var lastSyncTimestamp: String? {
        didSet { UserDefaults.standard.set(lastSyncTimestamp, forKey: lastSyncKey) }
    }

    private func loadLastSyncTimestamp() {
        lastSyncTimestamp = UserDefaults.standard.string(forKey: lastSyncKey)
        if let stored = UserDefaults.standard.object(forKey: lastSyncKey + ".date") as? Date {
            lastSyncDate = stored
        }
    }

    private func persistQueue() {
        if let data = try? JSONEncoder().encode(mutationQueue) {
            UserDefaults.standard.set(data, forKey: queueKey)
        }
        UserDefaults.standard.set(deleteQueue, forKey: deleteQueueKey)
    }

    private func loadQueue() {
        guard let data = UserDefaults.standard.data(forKey: queueKey),
              let queue = try? JSONDecoder().decode([PendingMutation].self, from: data) else { return }
        mutationQueue = queue
        deleteQueue = UserDefaults.standard.stringArray(forKey: deleteQueueKey) ?? []
        pendingCount = mutationQueue.count + deleteQueue.count
    }
}
