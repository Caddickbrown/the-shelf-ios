import SwiftUI

// MARK: - CoverView
// Shows thumbnail by default; loads full cover when loadFull=true (detail page).

struct CoverView: View {
    @Environment(ShelfTheme.self) var theme
    let bookId: String
    var loadFull: Bool = false
    @Environment(CoverCache.self) var cache
    @State private var imageData: Data?

    var body: some View {
        Group {
            if let data = imageData, let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
            } else {
                RoundedRectangle(cornerRadius: 4)
                    .fill(theme.surface2)
                    .overlay(
                        Image(systemName: "book.closed")
                            .foregroundStyle(theme.muted)
                    )
            }
        }
        .task(id: bookId) {
            imageData = loadFull
                ? await cache.fullCover(bookId: bookId)
                : await cache.thumbnail(bookId: bookId)
        }
    }
}

// MARK: - BookRow

struct BookRow: View {
    @Environment(ShelfTheme.self) var theme
    let book: Book
    var body: some View {
        HStack(spacing: 12) {
            CoverView(bookId: book.id)
                .frame(width: 44, height: 64)
                .clipShape(RoundedRectangle(cornerRadius: 4))

            VStack(alignment: .leading, spacing: 4) {
                Text(book.title)
                    .font(.body)
                    .foregroundStyle(theme.text)
                    .lineLimit(2)
                Text(book.author)
                    .font(.caption)
                    .foregroundStyle(theme.muted)
                    .lineLimit(1)
                if let rating = book.rating {
                    Text(String(repeating: "★", count: rating))
                        .font(.caption2)
                        .foregroundStyle(theme.accent)
                }
            }
            Spacer()
            StatusBadge(status: book.status)
        }
        .padding(.vertical, 6)
    }
}

// MARK: - ReadingCard (horizontal scroll card)

struct ReadingCard: View {
    @Environment(ShelfTheme.self) var theme
    let book: Book
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            CoverView(bookId: book.id)
                .frame(width: 100, height: 150)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .shadow(color: .black.opacity(0.4), radius: 6, x: 0, y: 3)

            Text(book.title)
                .font(.caption.bold())
                .foregroundStyle(theme.text)
                .lineLimit(2)
                .frame(width: 100, alignment: .leading)

            if let progress = book.progress {
                ProgressView(value: progress)
                    .frame(width: 100)
                    .tint(theme.accent)
                Text("\(Int(progress * 100))%")
                    .font(.caption2)
                    .foregroundStyle(theme.muted)
            }
        }
    }
}

// MARK: - StatusBadge

struct StatusBadge: View {
    @Environment(ShelfTheme.self) var theme
    let status: ReadStatus
    var body: some View {
        Text(status.label)
            .font(.caption2.bold())
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(theme.statusBg(status))
            .foregroundStyle(theme.statusFg(status))
            .clipShape(Capsule())
    }
}

// MARK: - QuickActionButton

struct QuickActionButton: View {
    @Environment(ShelfTheme.self) var theme
    let label: String
    let icon: String
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon).font(.caption)
                Text(label).font(.caption.bold())
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(theme.surface2)
            .foregroundStyle(theme.text)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(theme.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - SyncButton

struct SyncButton: View {
    @Environment(ShelfTheme.self) var theme
    @Environment(SyncEngine.self) var sync
    @Environment(BookStore.self) var store
    var body: some View {
        Button {
            Task { await sync.sync(store: store) }
        } label: {
            if sync.isSyncing {
                ProgressView().scaleEffect(0.8).tint(theme.accent)
            } else {
                Image(systemName: sync.pendingCount > 0
                      ? "arrow.triangle.2.circlepath.circle.fill"
                      : "arrow.triangle.2.circlepath")
                    .foregroundStyle(sync.pendingCount > 0 ? theme.orange : theme.muted)
            }
        }
        .disabled(sync.isSyncing)
    }
}

// MARK: - SyncStatusBanner

struct SyncStatusBanner: View {
    @Environment(ShelfTheme.self) var theme
    @Environment(SyncEngine.self) var sync
    var body: some View {
        HStack(spacing: 8) {
            ProgressView().scaleEffect(0.7).tint(theme.accent)
            Text("Syncing…").font(.caption).foregroundStyle(theme.muted)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(theme.surface2)
        .clipShape(Capsule())
        .overlay(Capsule().strokeBorder(theme.border, lineWidth: 1))
        .padding(.top, 8)
    }
}

// MARK: - SectionHeader

struct SectionHeader: View {
    @Environment(ShelfTheme.self) var theme
    let title: String
    var count: Int? = nil
    var body: some View {
        HStack {
            Text(title)
                .font(.headline)
                .foregroundStyle(theme.text)
            if let n = count {
                Text("(\(n))")
                    .foregroundStyle(theme.muted)
                    .font(.subheadline)
            }
            Spacer()
        }
        .padding(.horizontal)
    }
}

// MARK: - LabelValue

struct LabelValue: View {
    @Environment(ShelfTheme.self) var theme
    let label: String
    let value: String
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.caption).foregroundStyle(theme.muted)
            Text(value).font(.subheadline).foregroundStyle(theme.text)
        }
    }
}

// MARK: - MetadataGrid

struct MetadataGrid: View {
    let book: Book
    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            if let g = book.genre         { LabelValue(label: "Genre",     value: g) }
            if let n = book.pageCount     { LabelValue(label: "Pages",     value: "\(n)") }
            if let p = book.publisher     { LabelValue(label: "Publisher", value: p) }
            if let d = book.publishedDate { LabelValue(label: "Published", value: d) }
            if let i = book.isbn13 ?? book.isbn { LabelValue(label: "ISBN", value: i) }
            LabelValue(label: "Type", value: book.type.label)
        }
    }
}

// MARK: - FilterBar

struct FilterBar: View {
    @Environment(ShelfTheme.self) var theme
    @Binding var selectedStatus: ReadStatus?
    @Binding var selectedType: BookType?
    @Binding var sortBy: LibraryView.SortOption

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FilterChip(label: "All", isSelected: selectedStatus == nil) {
                    selectedStatus = nil
                }
                ForEach(ReadStatus.allCases, id: \.self) { s in
                    FilterChip(
                        label: s.label,
                        isSelected: selectedStatus == s,
                        activeColor: theme.statusFg(s),
                        activeBg: theme.statusBg(s)
                    ) {
                        selectedStatus = selectedStatus == s ? nil : s
                    }
                }
                Divider()
                    .frame(height: 20)
                    .overlay(theme.border)
                Menu {
                    ForEach(LibraryView.SortOption.allCases, id: \.self) { opt in
                        Button(opt.rawValue) { sortBy = opt }
                    }
                } label: {
                    FilterChip(label: "Sort: \(sortBy.rawValue)", isSelected: false, action: {})
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .background(theme.bg)
    }
}

struct FilterChip: View {
    @Environment(ShelfTheme.self) var theme
    let label: String
    let isSelected: Bool
    var activeColor: Color? = nil   // nil = use theme.bg
    var activeBg: Color? = nil      // nil = use theme.accent
    let action: () -> Void

    var body: some View {
        let fgColor = activeColor ?? theme.bg
        let bgColor = activeBg ?? theme.accent
        Button(action: action) {
            Text(label)
                .font(.caption.bold())
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? bgColor : theme.surface2)
                .foregroundStyle(isSelected ? fgColor : theme.muted)
                .clipShape(Capsule())
                .overlay(
                    Capsule().strokeBorder(
                        isSelected ? bgColor : theme.border,
                        lineWidth: 1
                    )
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - QuickStatsRow

struct QuickStatsRow: View {
    @Environment(ShelfTheme.self) var theme
    let store: BookStore
    var body: some View {
        HStack(spacing: 0) {
            StatCell(value: "\(store.books(status: .read).count)",    label: "Read",    color: theme.green)
            Divider().frame(height: 40).overlay(theme.border)
            StatCell(value: "\(store.books(status: .reading).count)", label: "Reading", color: theme.blue)
            Divider().frame(height: 40).overlay(theme.border)
            StatCell(value: "\(store.books(status: .toRead).count)",  label: "To Read", color: theme.orange)
            Divider().frame(height: 40).overlay(theme.border)
            StatCell(value: "\(store.books.count)",                   label: "Total",   color: theme.text)
        }
        .shelfCard()
    }
}

struct StatCell: View {
    @Environment(ShelfTheme.self) var theme
    let value: String
    let label: String
    var color: Color = .primary
    var body: some View {
        VStack(spacing: 2) {
            Text(value).font(.title3.bold()).foregroundStyle(color)
            Text(label).font(.caption2).foregroundStyle(theme.muted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
    }
}

// MARK: - StatusPickerSheet

struct StatusPickerSheet: View {
    @Environment(ShelfTheme.self) var theme
    let book: Book
    @Environment(BookStore.self) var store
    @Environment(\.dismiss) var dismiss
    @State private var status: ReadStatus
    @State private var startDate = ""
    @State private var endDate = ""

    init(book: Book) {
        self.book = book
        _status = State(initialValue: book.status)
        _startDate = State(initialValue: book.startDate ?? "")
        _endDate = State(initialValue: book.endDate ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    ForEach(ReadStatus.allCases, id: \.self) { s in
                        HStack {
                            Circle()
                                .fill(theme.statusFg(s))
                                .frame(width: 8, height: 8)
                            Text(s.emoji + " " + s.label)
                                .foregroundStyle(theme.text)
                            Spacer()
                            if status == s {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(theme.accent)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture { status = s }
                    }
                }
                Section("Dates") {
                    TextField("Start date (YYYY-MM-DD)", text: $startDate)
                    TextField("End date (YYYY-MM-DD)", text: $endDate)
                }
            }
            .navigationTitle("Reading Status")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        store.updateStatus(book.id, status: status,
                                           startDate: startDate.isEmpty ? nil : startDate,
                                           endDate: endDate.isEmpty ? nil : endDate)
                        dismiss()
                    }
                    .foregroundStyle(theme.accent)
                }
            }
        }
        .presentationDetents([.medium])
    }
}

// MARK: - RatingPickerSheet

struct RatingPickerSheet: View {
    @Environment(ShelfTheme.self) var theme
    let book: Book
    @Environment(BookStore.self) var store
    @Environment(\.dismiss) var dismiss
    @State private var rating: Int?

    init(book: Book) { self.book = book; _rating = State(initialValue: book.rating) }

    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                Text("Rate this book")
                    .font(.headline)
                    .foregroundStyle(theme.text)
                HStack(spacing: 16) {
                    ForEach(1...5, id: \.self) { n in
                        Image(systemName: n <= (rating ?? 0) ? "star.fill" : "star")
                            .font(.largeTitle)
                            .foregroundStyle(theme.accent)
                            .onTapGesture { rating = rating == n ? nil : n }
                    }
                }
                Button("Clear rating", role: .destructive) { rating = nil }
                    .font(.callout)
                    .foregroundStyle(theme.red)
            }
            .padding()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { store.updateRating(book.id, rating: rating); dismiss() }
                        .foregroundStyle(theme.accent)
                }
            }
        }
        .presentationDetents([.height(220)])
    }
}

// MARK: - ProgressEditorSheet

struct ProgressEditorSheet: View {
    @Environment(ShelfTheme.self) var theme
    let book: Book
    @Environment(BookStore.self) var store
    @Environment(\.dismiss) var dismiss
    @State private var currentPage: String

    init(book: Book) {
        self.book = book
        _currentPage = State(initialValue: book.currentPage.map(String.init) ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Current page") {
                    TextField("Page number", text: $currentPage)
                        .keyboardType(.numberPad)
                }
                if let total = book.pageCount, let n = Int(currentPage) {
                    Section {
                        ProgressView(value: Double(n) / Double(total))
                            .tint(theme.accent)
                        Text("\(n) of \(total) pages · \(Int(Double(n)/Double(total)*100))%")
                            .font(.caption)
                            .foregroundStyle(theme.muted)
                    }
                }
            }
            .navigationTitle("Update Progress")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        store.updateProgress(book.id, currentPage: Int(currentPage))
                        dismiss()
                    }
                    .foregroundStyle(theme.accent)
                }
            }
        }
        .presentationDetents([.medium])
    }
}

// MARK: - ISBNSearchView

struct ISBNSearchView: View {
    @Environment(ShelfTheme.self) var theme
    @Binding var query: String
    @Binding var results: [MetadataResult]
    @Binding var isSearching: Bool
    @Binding var error: String?
    let onSelect: (MetadataResult) -> Void

    var body: some View {
        VStack {
            HStack {
                TextField("ISBN or book title…", text: $query)
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.numbersAndPunctuation)
                Button("Search") {
                    Task {
                        isSearching = true
                        error = nil
                        do {
                            results = try await ShelfAPIService.shared.lookupISBN(query)
                            if results.isEmpty { error = "No results found" }
                        } catch {
                            self.error = error.localizedDescription
                        }
                        isSearching = false
                    }
                }
                .foregroundStyle(theme.accent)
                .disabled(query.isEmpty || isSearching)
            }
            .padding()

            if let error {
                Text(error)
                    .foregroundStyle(theme.red)
                    .font(.caption)
                    .padding(.horizontal)
            }
            if isSearching { ProgressView("Searching…").tint(theme.accent).padding() }

            List(results) { result in
                Button {
                    onSelect(result)
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(result.title).font(.body.bold()).foregroundStyle(theme.text)
                        Text(result.author).foregroundStyle(theme.muted).font(.caption)
                        if let isbn = result.isbn13 ?? result.isbn {
                            Text(isbn).foregroundStyle(theme.muted.opacity(0.6)).font(.caption2)
                        }
                    }
                }
                .buttonStyle(.plain)
                .listRowBackground(theme.surface)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(theme.bg)
        }
    }
}

// MARK: - ManualAddForm

struct ManualAddForm: View {
    @Environment(ShelfTheme.self) var theme
    let onAdd: (Book) -> Void
    @State private var title = ""
    @State private var author = ""
    @State private var status: ReadStatus = .toRead
    @State private var type: BookType = .book
    @State private var isbn = ""
    @State private var genre = ""

    var body: some View {
        Form {
            Section("Required") {
                TextField("Title", text: $title)
                TextField("Author", text: $author)
            }
            Section("Details") {
                Picker("Status", selection: $status) {
                    ForEach(ReadStatus.allCases, id: \.self) { Text($0.label).tag($0) }
                }
                Picker("Type", selection: $type) {
                    ForEach(BookType.allCases, id: \.self) { Text($0.label).tag($0) }
                }
                TextField("ISBN", text: $isbn).keyboardType(.numbersAndPunctuation)
                TextField("Genre", text: $genre)
            }
            Section {
                Button("Add to Library") {
                    let book = Book(
                        id: UUID().uuidString,
                        title: title,
                        author: author,
                        status: status,
                        rating: nil,
                        genre: genre.isEmpty ? nil : genre,
                        type: type,
                        description: nil,
                        isbn: isbn.isEmpty ? nil : isbn,
                        isbn13: nil,
                        seriesPos: nil,
                        review: nil,
                        notes: nil,
                        olCoverId: nil,
                        coverUrl: nil,
                        series: nil,
                        yearRead: nil,
                        startDate: nil,
                        endDate: nil,
                        currentPage: nil,
                        pageCount: nil,
                        seriesPosition: nil,
                        publisher: nil,
                        publishedDate: nil,
                        language: nil,
                        updatedAt: ISO8601DateFormatter().string(from: Date())
                    )
                    onAdd(book)
                }
                .foregroundStyle(theme.accent)
                .disabled(title.isEmpty || author.isEmpty)
            }
        }
        .scrollContentBackground(.hidden)
        .background(theme.bg)
    }
}
