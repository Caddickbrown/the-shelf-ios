import Foundation
import SwiftUI

// MARK: - CoverCache
// LRU cache: thumbnails cached freely, full covers capped at 50 entries.
// Falls back to thumbnail when offline or full cover unavailable.

@Observable
@MainActor
final class CoverCache {

    static let shared = CoverCache()
    private init() {
        setupDiskCache()
    }

    private let maxFullCovers = 50
    private var fullCoverLRU: [String] = []   // bookIds, MRU at end
    private let api = ShelfAPIService.shared

    // MARK: - Disk paths

    private var cacheDir: URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ShelfCovers")
    }

    private func thumbPath(bookId: String) -> URL {
        cacheDir.appendingPathComponent("thumb_\(bookId).jpg")
    }

    private func fullPath(bookId: String) -> URL {
        cacheDir.appendingPathComponent("full_\(bookId).jpg")
    }

    private func setupDiskCache() {
        try? FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
        loadLRUIndex()
    }

    // MARK: - Public interface

    /// Returns thumbnail data. Downloads + caches if not present.
    func thumbnail(bookId: String) async -> Data? {
        let path = thumbPath(bookId: bookId)
        if let cached = try? Data(contentsOf: path) { return cached }
        guard let url = await api.thumbnailURL(bookId: bookId) else { return nil }
        guard let data = try? await api.fetchData(from: url) else { return nil }
        try? data.write(to: path)
        return data
    }

    /// Returns full cover data if online (caches with LRU eviction).
    /// Falls back to thumbnail if offline or fetch fails.
    func fullCover(bookId: String) async -> Data? {
        // Check full cache first
        let fullPath = self.fullPath(bookId: bookId)
        if let cached = try? Data(contentsOf: fullPath) {
            touchLRU(bookId: bookId)
            return cached
        }
        // Try to download
        guard let url = await api.coverURL(bookId: bookId),
              let data = try? await api.fetchData(from: url) else {
            // Offline fallback — return thumbnail
            return await thumbnail(bookId: bookId)
        }
        // Evict if at capacity
        evictIfNeeded()
        try? data.write(to: fullPath)
        appendLRU(bookId: bookId)
        return data
    }

    /// Evict all cached covers (useful for low-storage warning).
    func clearFullCovers() {
        for id in fullCoverLRU {
            try? FileManager.default.removeItem(at: fullPath(bookId: id))
        }
        fullCoverLRU = []
        persistLRUIndex()
    }

    func clearAll() {
        try? FileManager.default.removeItem(at: cacheDir)
        setupDiskCache()
        fullCoverLRU = []
    }

    var diskUsageBytes: Int64 {
        (try? FileManager.default.allocatedSizeOfDirectory(at: cacheDir)) ?? 0
    }

    // MARK: - LRU management

    private func touchLRU(bookId: String) {
        fullCoverLRU.removeAll { $0 == bookId }
        fullCoverLRU.append(bookId)
        persistLRUIndex()
    }

    private func appendLRU(bookId: String) {
        fullCoverLRU.removeAll { $0 == bookId }
        fullCoverLRU.append(bookId)
        persistLRUIndex()
    }

    private func evictIfNeeded() {
        while fullCoverLRU.count >= maxFullCovers, let oldest = fullCoverLRU.first {
            try? FileManager.default.removeItem(at: fullPath(bookId: oldest))
            fullCoverLRU.removeFirst()
        }
    }

    private let lruIndexKey = "shelf.coverLRU"

    private func persistLRUIndex() {
        UserDefaults.standard.set(fullCoverLRU, forKey: lruIndexKey)
    }

    private func loadLRUIndex() {
        fullCoverLRU = UserDefaults.standard.stringArray(forKey: lruIndexKey) ?? []
    }
}

// MARK: - FileManager extension

extension FileManager {
    func allocatedSizeOfDirectory(at url: URL) throws -> Int64 {
        let urls = try contentsOfDirectory(at: url, includingPropertiesForKeys: [.fileSizeKey])
        return try urls.reduce(0) { sum, u in
            let size = try u.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
            return sum + Int64(size)
        }
    }
}
