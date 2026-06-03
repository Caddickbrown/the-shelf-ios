import SwiftUI

// MARK: - MangaView
// Browses manga from the server, grouped by series with horizontal cover rows.

struct MangaView: View {
    @Environment(ShelfTheme.self) var theme

    @State private var manga: [Book] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var selectedStatus: ReadStatus?
    @State private var searchText = ""
    @State private var showListView: Bool = true

    // MARK: - Derived data

    /// Books visible after status filter + search
    private var filtered: [Book] {
        manga.filter { book in
            let matchesStatus = selectedStatus == nil || book.status == selectedStatus
            let q = searchText.trimmingCharacters(in: .whitespaces).lowercased()
            let matchesSearch = q.isEmpty
                || book.title.lowercased().contains(q)
                || book.author.lowercased().contains(q)
                || (book.series?.lowercased().contains(q) ?? false)
            return matchesStatus && matchesSearch
        }
    }

    /// Manga grouped by series name. Solo books (series == nil) use their title as the group key.
    private var groups: [(key: String, books: [Book])] {
        var map: [String: [Book]] = [:]
        var insertionOrder: [String] = []
        for book in filtered {
            let key = book.series ?? book.title
            if map[key] == nil { insertionOrder.append(key) }
            map[key, default: []].append(book)
        }
        // Sort by reading_order first (web app order), then alphabetically
        let sortedKeys = insertionOrder.sorted { a, b in
            let aOrder = map[a]?.compactMap { $0.readingOrder }.min() ?? Int.max
            let bOrder = map[b]?.compactMap { $0.readingOrder }.min() ?? Int.max
            if aOrder != bOrder { return aOrder < bOrder }
            return a.localizedCaseInsensitiveCompare(b) == .orderedAscending
        }
        return sortedKeys.map { key in
            let books = (map[key] ?? []).sorted { a, b in
                let aPos = a.seriesPosition ?? Double(a.seriesPos ?? "") ?? 9999
                let bPos = b.seriesPosition ?? Double(b.seriesPos ?? "") ?? 9999
                return aPos < bPos
            }
            return (key: key, books: books)
        }
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                theme.bg.ignoresSafeArea()

                VStack(spacing: 0) {
                    searchBar
                    filterBar
                    Divider().overlay(theme.border)
                    content
                }
            }
            .navigationTitle("Manga (\(manga.count))")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showListView.toggle() } label: {
                        Image(systemName: showListView ? "rectangle.grid.1x2" : "list.bullet")
                    }
                }
            }
            .task { await load() }
        }
    }

    // MARK: - Search bar

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(theme.muted)
                .font(.subheadline)

            TextField("Search title, series, or author…", text: $searchText)
                .foregroundStyle(theme.text)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(theme.muted)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(10)
        .background(theme.surface2)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(theme.border, lineWidth: 1)
        )
        .padding(.horizontal)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }

    // MARK: - Filter chips

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FilterChip(label: "All", isSelected: selectedStatus == nil) {
                    selectedStatus = nil
                }
                FilterChip(
                    label: ReadStatus.reading.label,
                    isSelected: selectedStatus == .reading,
                    activeColor: theme.bg,
                    activeBg: theme.statusFg(.reading)
                ) {
                    selectedStatus = selectedStatus == .reading ? nil : .reading
                }
                FilterChip(
                    label: ReadStatus.read.label,
                    isSelected: selectedStatus == .read,
                    activeColor: theme.bg,
                    activeBg: theme.statusFg(.read)
                ) {
                    selectedStatus = selectedStatus == .read ? nil : .read
                }
                FilterChip(
                    label: ReadStatus.toRead.label,
                    isSelected: selectedStatus == .toRead,
                    activeColor: theme.bg,
                    activeBg: theme.statusFg(.toRead)
                ) {
                    selectedStatus = selectedStatus == .toRead ? nil : .toRead
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .background(theme.bg)
    }

    // MARK: - Main content

    @ViewBuilder
    private var content: some View {
        if isLoading && manga.isEmpty {
            Spacer()
            ProgressView()
                .tint(theme.accent)
                .scaleEffect(1.2)
            Spacer()
        } else if let err = errorMessage {
            Spacer()
            VStack(spacing: 16) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.largeTitle)
                    .foregroundStyle(theme.orange)
                Text(err)
                    .font(.callout)
                    .foregroundStyle(theme.muted)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                Button("Try Again") {
                    Task { await load() }
                }
                .font(.callout.bold())
                .foregroundStyle(theme.accent)
            }
            Spacer()
        } else {
            if showListView { flatList } else { groupList }
        }
    }

    // MARK: - Flat ordered list

    private var flatList: some View {
        let sorted = filtered.sorted {
            let aO = $0.readingOrder ?? Int.max
            let bO = $1.readingOrder ?? Int.max
            if aO != bO { return aO < bO }
            return $0.title < $1.title
        }
        return ScrollView {
            LazyVStack(spacing: 0) {
                if sorted.isEmpty {
                    HStack {
                        Spacer()
                        Text(searchText.isEmpty ? "No manga found" : "No results for '\(searchText)'")
                            .font(.callout).foregroundStyle(theme.muted).padding(.top, 60)
                        Spacer()
                    }
                } else {
                    ForEach(sorted) { book in
                        NavigationLink(destination: BookDetailView(book: book)) {
                            BookRow(book: book).padding(.horizontal)
                        }
                        .buttonStyle(.plain)
                        Divider().padding(.leading, 72)
                    }
                }
            }
            .padding(.vertical, 12)
        }
        .refreshable { await load() }
    }

    // MARK: - Series group list

    private var groupList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                if groups.isEmpty {
                    HStack {
                        Spacer()
                        Text(searchText.isEmpty ? "No manga found" : "No results for '\(searchText)'")
                        .font(.callout)
                        .foregroundStyle(theme.muted)
                        .padding(.top, 60)
                        Spacer()
                    }
                } else {
                    ForEach(groups, id: \.key) { group in
                        SeriesGroupRow(seriesName: group.key, books: group.books)
                    }
                }
            }
            .padding(.vertical, 12)
        }
        .refreshable { await load() }
    }

    // MARK: - Data loading

    private func load() async {
        isLoading = true
        errorMessage = nil
        do {
            let result = try await ShelfAPIService.shared.fetchManga()
            manga = result
        } catch is CancellationError {
            // swallow — fired when refreshable re-triggers during an in-flight load
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

// MARK: - SeriesGroupRow

private struct SeriesGroupRow: View {
    @Environment(ShelfTheme.self) var theme
    let seriesName: String
    let books: [Book]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {

            // Header row: series name + volume count
            HStack(alignment: .firstTextBaseline) {
                Text(seriesName)
                    .font(.headline.bold())
                    .foregroundStyle(theme.accent)
                    .lineLimit(2)

                Spacer()

                Text("\(books.count) vol\(books.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(theme.muted)
            }
            .padding(.horizontal, 14)
            .padding(.top, 12)

            // Horizontal cover strip
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 10) {
                    ForEach(books) { book in
                        NavigationLink(destination: BookDetailView(book: book)) {
                            MangaCoverCell(book: book)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 12)
            }
        }
        .background(theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(theme.border, lineWidth: 1)
        )
        .padding(.horizontal)
    }
}

// MARK: - MangaCoverCell

private struct MangaCoverCell: View {
    @Environment(ShelfTheme.self) var theme
    let book: Book

    private var volumeLabel: String? {
        guard let pos = book.seriesPos, !pos.isEmpty else { return nil }
        return "Vol. \(pos)"
    }

    var body: some View {
        VStack(spacing: 5) {
            CoverView(bookId: book.id, loadFull: false)
                .frame(width: 80, height: 120)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .shadow(color: .black.opacity(0.35), radius: 4, x: 0, y: 2)

            if let label = volumeLabel {
                Text(label)
                    .font(.caption2.bold())
                    .foregroundStyle(theme.muted)
                    .lineLimit(1)
                    .frame(width: 80)
            }

            StatusBadge(status: book.status)
        }
        .frame(width: 80)
    }
}
