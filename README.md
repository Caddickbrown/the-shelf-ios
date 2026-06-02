# The Shelf — iOS

Native SwiftUI iOS client for [The Shelf](https://github.com/Caddickbrown/the-shelf) — a personal reading library served from a Raspberry Pi.

## What it does

- **Full two-way sync** with the Pi server — changes on phone or web app stay in sync
- **Offline first** — all books cached locally, changes queued when off-network
- **Hybrid cover cache** — thumbnails cached freely, full covers LRU-capped at 50
- **Tier 3 parity** — browse, search, edit, add by ISBN scan, rate, review
- ISBN barcode lookup via Google Books API
- Status tracking, reading dates, ratings, reviews, series, notes

## Architecture

```
Models/
  Book.swift          — Data model matching server schema
  SyncModels.swift    — PendingMutation, SyncResponse, MetadataResult

Services/
  ShelfAPIService.swift — All API calls, TLS delegate (self-signed Pi cert)
  SyncEngine.swift      — Offline mutation queue + two-way sync logic
  BookStore.swift       — In-memory + on-disk book store, local mutations
  CoverCache.swift      — LRU cover cache (50 full, unlimited thumbnails)

Views/
  ContentView.swift   — Tab bar root
  MainViews.swift     — Home, Library, Search, Settings, Onboarding
  BookViews.swift     — BookDetail, BookEdit, AddBook, status/rating/progress sheets

Components/
  UIComponents.swift  — CoverView, BookRow, StatusBadge, FilterBar, etc.
```

## Sync design

**Last-write-wins per book, using `updated_at` timestamps.**

1. On any local edit: change applied immediately to local store, mutation queued
2. On sync (foreground resume, manual, or background): push queue → pull server changes since `lastSync`
3. Server applies mutations only if the mutation timestamp is newer than the server's `updated_at`
4. Offline changes accumulate in the queue and flush next time the Pi is reachable

No data is ever lost — the mutation queue persists to `UserDefaults` across app launches.

## Server requirements

The app requires The Shelf server running on the Pi with these endpoints:

| Endpoint | Purpose |
|---|---|
| `GET /api/books?updated_since=<ISO>` | Incremental sync pull |
| `GET /api/books?limit=99999` | Full initial load |
| `POST /api/sync/mutations` | Push local changes |
| `GET /cover/<id>.jpg?thumb=1` | Thumbnail (resized server-side) |
| `GET /cover/<id>.jpg` | Full cover |
| `POST /api/books` | Create new book |

## Getting started

1. Open Xcode, create a new iOS App project (SwiftUI, iOS 17+)
2. Add all `.swift` files from `Models/`, `Services/`, `Views/`, `Components/`
3. Set the app entry point to `TheShelfApp.swift`
4. Add `Info.plist` ATS exception for your Pi's hostname/IP (see below)
5. Build and run on a device on the same network as the Pi

### ATS exception for self-signed cert

```xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsArbitraryLoads</key>
    <true/>
</dict>
```

Or scope it to your Pi's IP for tighter security.

## Cover cache

- **Thumbnails** (`?thumb=1`): server resizes to 150×225px on the fly using Pillow. Cached on device indefinitely.
- **Full covers**: LRU cache, max 50 entries. Oldest evicted when cap reached.
- **Offline**: detail view falls back to thumbnail if full cover not cached locally.

## Requirements

- iOS 17.0+
- Xcode 16+
- No external Swift dependencies — pure SwiftUI + Foundation
- The Shelf server (Pi) running with sync endpoints (added June 2026)
