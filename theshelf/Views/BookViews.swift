import SwiftUI
import PhotosUI

// MARK: - Book Detail View
// Full parity: status, dates, rating, review, progress, metadata editing, cover upload.

struct BookDetailView: View {
    @Environment(ShelfTheme.self) var theme
    let book: Book
    @Environment(BookStore.self) var store
    @Environment(SyncEngine.self) var sync
    @State private var showEditSheet = false
    @State private var showStatusPicker = false
    @State private var showRatingPicker = false
    @State private var showProgressEditor = false
    @State private var showDeleteConfirm = false

    private var current: Book { store.book(id: book.id) ?? book }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {

                // Cover + title block
                HStack(alignment: .top, spacing: 16) {
                    CoverView(bookId: book.id, loadFull: true)
                        .frame(width: 100, height: 150)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .shadow(radius: 4)

                    VStack(alignment: .leading, spacing: 8) {
                        Text(current.title).font(.title3.bold()).fixedSize(horizontal: false, vertical: true)
                        Text(current.author).foregroundStyle(theme.muted)
                        if let series = current.series {
                            Text(series).font(.caption).foregroundStyle(theme.accent)
                        }
                        StatusBadge(status: current.status)
                    }
                }
                .padding(.horizontal)

                // Quick actions row
                HStack(spacing: 12) {
                    QuickActionButton(label: current.status.label, icon: "bookmark") {
                        showStatusPicker = true
                    }
                    QuickActionButton(label: current.rating.map { "\($0)★" } ?? "Rate",
                                      icon: "star") {
                        showRatingPicker = true
                    }
                    if current.status == .reading {
                        QuickActionButton(label: current.currentPage.map { "p.\($0)" } ?? "Progress",
                                          icon: "list.number") {
                            showProgressEditor = true
                        }
                    }
                    QuickActionButton(label: "Edit", icon: "pencil") {
                        showEditSheet = true
                    }
                    QuickActionButton(label: "Delete", icon: "trash") {
                        showDeleteConfirm = true
                    }
                }
                .padding(.horizontal)

                // Progress bar
                if current.status == .reading, let progress = current.progress {
                    VStack(alignment: .leading, spacing: 4) {
                        ProgressView(value: progress)
                            .tint(theme.accent)
                        Text("\(current.currentPage ?? 0) of \(current.pageCount ?? 0) pages · \(Int(progress * 100))%")
                            .font(.caption)
                            .foregroundStyle(theme.muted)
                    }
                    .padding(.horizontal)
                }

                // Dates
                if current.startDate != nil || current.endDate != nil {
                    HStack(spacing: 24) {
                        if let d = current.startDate {
                            LabelValue(label: "Started", value: d)
                        }
                        if let d = current.endDate {
                            LabelValue(label: "Finished", value: d)
                        }
                    }
                    .padding(.horizontal)
                }

                // Reading history
                ReadingHistorySection(bookId: book.id)
                    .padding(.horizontal)

                // Review
                if let review = current.review, !review.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("My Review").font(.headline)
                        Text(review).foregroundStyle(theme.muted)
                    }
                    .padding(.horizontal)
                }

                // Description
                if let desc = current.description, !desc.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Description").font(.headline)
                        Text(desc).foregroundStyle(theme.muted).font(.callout)
                    }
                    .padding(.horizontal)
                }

                // Metadata grid
                MetadataGrid(book: current)
                    .padding(.horizontal)

                Spacer(minLength: 40)
            }
            .padding(.top)
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showEditSheet) {
            BookEditView(book: current)
        }
        .sheet(isPresented: $showStatusPicker) {
            StatusPickerSheet(book: current)
        }
        .sheet(isPresented: $showRatingPicker) {
            RatingPickerSheet(book: current)
        }
        .sheet(isPresented: $showProgressEditor) {
            ProgressEditorSheet(book: current)
        }
        .confirmationDialog("Delete this book?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                store.removeBook(id: book.id)
                Task { _ = try? await ShelfAPIService.shared.deleteBook(id: book.id) }
            }
        }
    }
}

// MARK: - Book Edit View (full field editing)

struct BookEditView: View {
    @Environment(ShelfTheme.self) var theme
    let book: Book
    @Environment(BookStore.self) var store
    @Environment(\.dismiss) var dismiss

    @State private var title: String
    @State private var author: String
    @State private var status: ReadStatus
    @State private var rating: Int?
    @State private var review: String
    @State private var notes: String
    @State private var genre: String
    @State private var currentPage: String
    @State private var pageCount: String
    @State private var series: String
    @State private var seriesPosition: String
    @State private var publisher: String
    @State private var publishedDate: String
    @State private var bookType: BookType
    @State private var isSaving = false
    @State private var coverURL = ""
    @State private var coverPhotoItem: PhotosPickerItem? = nil
    @State private var coverUploadStatus = ""

    init(book: Book) {
        self.book = book
        _title = State(initialValue: book.title)
        _author = State(initialValue: book.author)
        _status = State(initialValue: book.status)
        _rating = State(initialValue: book.rating)
        _review = State(initialValue: book.review ?? "")
        _notes = State(initialValue: book.notes ?? "")
        _genre = State(initialValue: book.genre ?? "")
        _currentPage = State(initialValue: book.currentPage.map(String.init) ?? "")
        _pageCount = State(initialValue: book.pageCount.map(String.init) ?? "")
        _series = State(initialValue: book.series ?? "")
        _seriesPosition = State(initialValue: book.seriesPos ?? "")
        _publisher = State(initialValue: book.publisher ?? "")
        _publishedDate = State(initialValue: book.publishedDate ?? "")
        _bookType = State(initialValue: book.type ?? .book)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Book Info") {
                    TextField("Title", text: $title)
                    TextField("Author", text: $author)
                    Picker("Type", selection: $bookType) {
                        ForEach(BookType.allCases, id: \.self) { Text($0.label).tag($0) }
                    }
                    TextField("Genre", text: $genre)
                }

                Section("Reading") {
                    Picker("Status", selection: $status) {
                        ForEach(ReadStatus.allCases, id: \.self) { s in
                            Text(s.label).tag(s)
                        }
                    }
                    TextField("Current page", text: $currentPage)
                        .keyboardType(.numberPad)
                    TextField("Total pages", text: $pageCount)
                        .keyboardType(.numberPad)
                }

                Section("Rating & Review") {
                    Picker("Rating", selection: $rating) {
                        Text("No rating").tag(Optional<Int>.none)
                        ForEach(1...5, id: \.self) { n in
                            Text(String(repeating: "★", count: n)).tag(Optional(n))
                        }
                    }
                    ZStack(alignment: .topLeading) {
                        if review.isEmpty {
                            Text("Write a review…").foregroundStyle(theme.muted.opacity(0.6)).padding(.top, 8)
                        }
                        TextEditor(text: $review)
                            .frame(minHeight: 80)
                    }
                }

                Section("Series") {
                    TextField("Series name", text: $series)
                    TextField("Position", text: $seriesPosition)
                        .keyboardType(.decimalPad)
                }

                Section("Publication") {
                    TextField("Publisher", text: $publisher)
                    TextField("Published date", text: $publishedDate)
                }

                Section("Cover") {
                    PhotosPicker(selection: $coverPhotoItem, matching: .images) {
                        Label("Choose from Photos", systemImage: "photo")
                    }
                    .onChange(of: coverPhotoItem) { _, item in
                        guard let item else { return }
                        Task {
                            coverUploadStatus = "Uploading…"
                            if let data = try? await item.loadTransferable(type: Data.self) {
                                do {
                                    try await ShelfAPIService.shared.uploadCover(bookId: book.id, jpegData: data)
                                    coverUploadStatus = "✓ Cover uploaded"
                                } catch {
                                    coverUploadStatus = "Upload failed: \(error.localizedDescription)"
                                }
                            }
                        }
                    }
                    HStack {
                        TextField("Or paste image URL…", text: $coverURL)
                            .keyboardType(.URL)
                            .autocorrectionDisabled()
                        if !coverURL.isEmpty {
                            Button("Use") {
                                Task {
                                    coverUploadStatus = "Saving URL…"
                                    do {
                                        try await ShelfAPIService.shared.setCoverURL(bookId: book.id, url: coverURL)
                                        coverUploadStatus = "✓ Cover saved"
                                        coverURL = ""
                                    } catch {
                                        coverUploadStatus = "Failed: \(error.localizedDescription)"
                                    }
                                }
                            }
                            .foregroundStyle(theme.accent)
                        }
                    }
                    if !coverUploadStatus.isEmpty {
                        Text(coverUploadStatus)
                            .font(.caption)
                            .foregroundStyle(coverUploadStatus.hasPrefix("✓") ? theme.green : theme.muted)
                    }
                }

                Section("Notes") {
                    ZStack(alignment: .topLeading) {
                        if notes.isEmpty {
                            Text("Private notes…").foregroundStyle(theme.muted.opacity(0.6)).padding(.top, 8)
                        }
                        TextEditor(text: $notes)
                            .frame(minHeight: 60)
                    }
                }
            }
            .navigationTitle("Edit Book")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(isSaving || title.isEmpty)
                }
            }
        }
    }

    private func save() {
        isSaving = true
        var changes: [String: Any] = [
            "title": title,
            "author": author,
            "status": status.rawValue,
            "type": bookType.rawValue,
            "genre": genre.isEmpty ? NSNull() : genre,
            "review": review.isEmpty ? NSNull() : review,
            "notes": notes.isEmpty ? NSNull() : notes,
            "series": series.isEmpty ? NSNull() : series,
            "publisher": publisher.isEmpty ? NSNull() : publisher,
            "published_date": publishedDate.isEmpty ? NSNull() : publishedDate,
        ]
        if let r = rating { changes["rating"] = r } else { changes["rating"] = NSNull() }
        if let n = Int(currentPage) { changes["current_page"] = n }
        if let n = Int(pageCount) { changes["page_count"] = n }
        changes["series_pos"] = seriesPosition.isEmpty ? NSNull() : seriesPosition

        store.updateFields(book.id, changes: changes)
        Task { await SyncEngine.shared.sync(store: store) }
        dismiss()
    }
}

// MARK: - Add Book View (ISBN scan + manual + metadata lookup)

struct AddBookView: View {
    @Environment(BookStore.self) var store
    @Environment(SyncEngine.self) var sync
    @State private var mode: AddMode = .isbn
    @State private var isbnQuery = ""
    @State private var searchResults: [MetadataResult] = []
    @State private var isSearching = false
    @State private var showManualAdd = false
    @State private var showScanner = false
    @State private var error: String?

    enum AddMode: String, CaseIterable {
        case isbn = "ISBN / Barcode"
        case manual = "Manual"
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Mode", selection: $mode) {
                    ForEach(AddMode.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .padding()

                if mode == .isbn {
                    VStack(spacing: 0) {
                        // Camera scan button
                        Button {
                            showScanner = true
                        } label: {
                            Label("Scan Barcode", systemImage: "barcode.viewfinder")
                                .font(.callout.bold())
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(Color.accentColor.opacity(0.12))
                                .foregroundStyle(Color.accentColor)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal)
                        .padding(.bottom, 8)

                        ISBNSearchView(
                            query: $isbnQuery,
                            results: $searchResults,
                            isSearching: $isSearching,
                            error: $error,
                            onSelect: addFromMetadata
                        )
                    }
                } else {
                    ManualAddForm(onAdd: { book in
                        store.addBook(book)
                        Task { await sync.sync(store: store) }
                    })
                }
            }
            .navigationTitle("Add Book")
            .fullScreenCover(isPresented: $showScanner) {
                BarcodeScannerView { scanned in
                    isbnQuery = scanned
                    mode = .isbn
                    // Auto-trigger search
                    Task {
                        isSearching = true
                        error = nil
                        do {
                            searchResults = try await ShelfAPIService.shared.lookupISBN(scanned)
                            if searchResults.isEmpty { error = "No results for barcode \(scanned)" }
                        } catch {
                            self.error = error.localizedDescription
                        }
                        isSearching = false
                    }
                }
                .ignoresSafeArea()
            }
        }
    }

    private func addFromMetadata(_ result: MetadataResult) {
        let book = Book(
            id: UUID().uuidString,
            title: result.title,
            author: result.author,
            status: .toRead,
            rating: nil,
            genre: nil,
            type: .book,
            description: result.description,
            isbn: result.isbn,
            isbn13: result.isbn13,
            seriesPos: nil,
            review: nil,
            notes: nil,
            olCoverId: nil,
            coverUrl: result.coverUrl,
            series: nil,
            yearRead: nil,
            startDate: nil,
            endDate: nil,
            currentPage: nil,
            pageCount: result.pageCount,
            seriesPosition: nil,
            publisher: result.publisher,
            publishedDate: result.publishedDate,
            language: nil,
            updatedAt: ISO8601DateFormatter().string(from: Date()),
            readingOrder: nil
        )
        store.addBook(book)
        Task {
            _ = try? await ShelfAPIService.shared.createBook(BookCreateRequest(
                title: result.title,
                author: result.author,
                status: .toRead,
                isbn: result.isbn,
                isbn13: result.isbn13,
                pageCount: result.pageCount,
                genre: nil,
                description: result.description,
                coverUrl: result.coverUrl,
                type: .book,
                publishedDate: result.publishedDate,
                publisher: result.publisher
            ))
            await sync.sync(store: store)
        }
    }
}

// MARK: - Reading History Section

struct ReadingHistorySection: View {
    @Environment(ShelfTheme.self) var theme
    let bookId: String
    @State private var entries: [ReadingLogEntry] = []
    @State private var isLoading = false
    @State private var showAddSheet = false
    @State private var editingEntry: ReadingLogEntry? = nil
    @State private var deleteTarget: ReadingLogEntry? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Reading History").font(.headline)
                Spacer()
                Button { showAddSheet = true } label: {
                    Image(systemName: "plus.circle").foregroundStyle(theme.accent)
                }
            }
            if isLoading && entries.isEmpty {
                ProgressView().tint(theme.accent)
            } else if entries.isEmpty {
                Text("No reading history yet")
                    .font(.callout).foregroundStyle(theme.muted)
            } else {
                ForEach(entries) { entry in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 12) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(theme.green).font(.caption)
                            VStack(alignment: .leading, spacing: 2) {
                                if let start = entry.dateStarted, let end = entry.dateFinished {
                                    Text("\(start) \u{2192} \(end)").font(.caption.bold()).foregroundStyle(theme.text)
                                } else if let end = entry.dateFinished {
                                    Text("Finished \(end)").font(.caption.bold()).foregroundStyle(theme.text)
                                } else if let start = entry.dateStarted {
                                    Text("Started \(start)").font(.caption).foregroundStyle(theme.muted)
                                } else if let yr = entry.yearRead {
                                    Text("Read in \(yr)").font(.caption).foregroundStyle(theme.muted)
                                }
                                if let r = entry.rating {
                                    Text(String(repeating: "\u{2605}", count: r))
                                        .font(.caption2).foregroundStyle(theme.accent)
                                }
                            }
                            Spacer()
                            Button { editingEntry = entry } label: {
                                Image(systemName: "pencil").font(.caption).foregroundStyle(theme.muted)
                            }.buttonStyle(.plain)
                            Button { deleteTarget = entry } label: {
                                Image(systemName: "trash").font(.caption).foregroundStyle(theme.red)
                            }.buttonStyle(.plain)
                        }
                        if let review = entry.review, !review.isEmpty {
                            Text(review)
                                .font(.caption)
                                .foregroundStyle(theme.muted)
                                .padding(.leading, 24)
                        }
                    }
                    .padding(.vertical, 4)
                    Divider()
                }
            }
        }
        .task { await loadHistory() }
        .sheet(isPresented: $showAddSheet, onDismiss: { Task { await loadHistory() } }) {
            AddReadSheet(bookId: bookId)
        }
        .sheet(item: $editingEntry, onDismiss: { Task { await loadHistory() } }) { entry in
            AddReadSheet(bookId: bookId, existing: entry)
        }
        .confirmationDialog("Delete this read?", isPresented: Binding(
            get: { deleteTarget != nil },
            set: { if !$0 { deleteTarget = nil } }
        ), titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                guard let e = deleteTarget else { return }
                deleteTarget = nil
                Task {
                    _ = try? await ShelfAPIService.shared.deleteReadingLogEntry(id: e.id)
                    await loadHistory()
                }
            }
        }
    }

    private func loadHistory() async {
        isLoading = true
        entries = (try? await ShelfAPIService.shared.fetchReadingLog(bookId: bookId)) ?? []
        isLoading = false
    }
}

// MARK: - Add / Edit Read Sheet

struct AddReadSheet: View {
    @Environment(ShelfTheme.self) var theme
    @Environment(\.dismiss) var dismiss
    let bookId: String
    var existing: ReadingLogEntry? = nil
    @State private var startDate = ""
    @State private var endDate = ""
    @State private var rating: Int? = nil
    @State private var review = ""
    @State private var isSaving = false

    init(bookId: String, existing: ReadingLogEntry? = nil) {
        self.bookId = bookId
        self.existing = existing
        _startDate = State(initialValue: existing?.dateStarted ?? "")
        _endDate = State(initialValue: existing?.dateFinished ?? "")
        _rating = State(initialValue: existing?.rating)
        _review = State(initialValue: existing?.review ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Dates") {
                    OptionalDateRow(label: "Start date", text: $startDate)
                    OptionalDateRow(label: "End date", text: $endDate)
                }
                Section("Rating") {
                    Picker("Rating", selection: $rating) {
                        Text("No rating").tag(Optional<Int>.none)
                        ForEach(1...5, id: \.self) { n in
                            Text(String(repeating: "\u{2605}", count: n)).tag(Optional(n))
                        }
                    }
                }
                Section("Review") {
                    ZStack(alignment: .topLeading) {
                        if review.isEmpty {
                            Text("Write a review for this read\u{2026}")
                                .foregroundStyle(Color.secondary.opacity(0.6))
                                .padding(.top, 8)
                        }
                        TextEditor(text: $review).frame(minHeight: 80)
                    }
                }
            }
            .navigationTitle(existing == nil ? "Log a Read" : "Edit Read")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(isSaving || (startDate.isEmpty && endDate.isEmpty))
                }
            }
        }
        .presentationDetents([.large])
    }

    private func save() {
        isSaving = true
        Task {
            if let e = existing {
                _ = try? await ShelfAPIService.shared.updateReadingLogEntry(
                    id: e.id,
                    dateStarted: startDate.isEmpty ? nil : startDate,
                    dateFinished: endDate.isEmpty ? nil : endDate,
                    rating: rating,
                    review: review.isEmpty ? nil : review
                )
            } else {
                _ = try? await ShelfAPIService.shared.addReadingLogEntry(
                    bookId: bookId,
                    dateStarted: startDate.isEmpty ? nil : startDate,
                    dateFinished: endDate.isEmpty ? nil : endDate,
                    rating: rating,
                    review: review.isEmpty ? nil : review
                )
            }
            dismiss()
        }
    }
}
