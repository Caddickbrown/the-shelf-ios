import SwiftUI

// MARK: - Home View
// Shows currently reading, recently finished, and quick stats.

struct HomeView: View {
    @Environment(BookStore.self) var store
    @Environment(SyncEngine.self) var sync

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {

                    // Currently reading
                    if !store.currentlyReading.isEmpty {
                        SectionHeader(title: "Currently Reading", count: store.currentlyReading.count)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 16) {
                                ForEach(store.currentlyReading) { book in
                                    NavigationLink(destination: BookDetailView(book: book)) {
                                        ReadingCard(book: book)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal)
                        }
                    }

                    // Recently finished
                    if !store.recentlyRead.isEmpty {
                        SectionHeader(title: "Recently Finished")
                        VStack(spacing: 0) {
                            ForEach(store.recentlyRead.prefix(5)) { book in
                                NavigationLink(destination: BookDetailView(book: book)) {
                                    BookRow(book: book)
                                }
                                .buttonStyle(.plain)
                                Divider().padding(.leading, 72)
                            }
                        }
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal)
                    }

                    // Quick stats
                    QuickStatsRow(store: store)
                        .padding(.horizontal)
                }
                .padding(.top)
            }
            .navigationTitle("The Shelf")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    SyncButton()
                }
            }
            .refreshable {
                await SyncEngine.shared.sync(store: store)
            }
        }
    }
}

// MARK: - Library View (filterable by status/type)

struct LibraryView: View {
    @Environment(BookStore.self) var store
    @State private var selectedStatus: ReadStatus? = nil
    @State private var selectedType: BookType? = nil
    @State private var sortBy: SortOption = .title

    enum SortOption: String, CaseIterable {
        case title = "Title"
        case author = "Author"
        case dateAdded = "Date Added"
        case rating = "Rating"
    }

    var filtered: [Book] {
        var result = store.books
        if let s = selectedStatus { result = result.filter { $0.status == s } }
        if let t = selectedType   { result = result.filter { $0.type == t } }
        switch sortBy {
        case .title:     result.sort { $0.title < $1.title }
        case .author:    result.sort { $0.author < $1.author }
        case .dateAdded: result.sort { $0.updatedAt > $1.updatedAt }
        case .rating:    result.sort { ($0.rating ?? 0) > ($1.rating ?? 0) }
        }
        return result
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Filter chips
                FilterBar(selectedStatus: $selectedStatus, selectedType: $selectedType, sortBy: $sortBy)

                List(filtered) { book in
                    NavigationLink(destination: BookDetailView(book: book)) {
                        BookRow(book: book)
                    }
                }
                .listStyle(.plain)
            }
            .navigationTitle("Library (\(filtered.count))")
        }
    }
}

// MARK: - Search View

struct SearchView: View {
    @Environment(BookStore.self) var store
    @State private var query = ""

    var results: [Book] { store.books(matching: query) }

    var body: some View {
        NavigationStack {
            List(results) { book in
                NavigationLink(destination: BookDetailView(book: book)) {
                    BookRow(book: book)
                }
            }
            .listStyle(.plain)
            .navigationTitle("Search")
            .searchable(text: $query, prompt: "Title, author, ISBN…")
            .overlay {
                if query.isEmpty {
                    ContentUnavailableView("Search your library",
                        systemImage: "magnifyingglass",
                        description: Text("Search by title, author, or ISBN"))
                } else if results.isEmpty {
                    ContentUnavailableView.search(text: query)
                }
            }
        }
    }
}

// MARK: - Settings View

struct SettingsView: View {
    @AppStorage("shelf.serverURL") private var serverURL = "https://192.168.4.185:8773"
    @Environment(BookStore.self) var store
    @Environment(SyncEngine.self) var sync
    @Environment(CoverCache.self) var cache
    @State private var showClearConfirm = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Server") {
                    TextField("Server URL", text: $serverURL)
                        .keyboardType(.URL)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                    Button("Test Connection") {
                        Task { await store.loadFromServer() }
                    }
                }

                Section("Sync") {
                    LabeledContent("Status") {
                        Text(sync.isSyncing ? "Syncing…" : "Idle")
                            .foregroundStyle(.secondary)
                    }
                    if let date = sync.lastSyncDate {
                        LabeledContent("Last sync") {
                            Text(date, style: .relative)
                                .foregroundStyle(.secondary)
                        }
                    }
                    if sync.pendingCount > 0 {
                        LabeledContent("Pending changes") {
                            Text("\(sync.pendingCount)")
                                .foregroundStyle(.orange)
                        }
                    }
                    Button("Sync Now") {
                        Task { await sync.sync(store: store) }
                    }
                }

                Section("Storage") {
                    LabeledContent("Cover cache") {
                        Text(ByteCountFormatter.string(fromByteCount: cache.diskUsageBytes, countStyle: .file))
                            .foregroundStyle(.secondary)
                    }
                    LabeledContent("Books stored") {
                        Text("\(store.books.count)")
                            .foregroundStyle(.secondary)
                    }
                    Button("Clear Cover Cache", role: .destructive) {
                        showClearConfirm = true
                    }
                }

                Section("About") {
                    LabeledContent("Version", value: "1.0.0")
                    Link("View on GitHub", destination: URL(string: "https://github.com/Caddickbrown/the-shelf-ios")!)
                }
            }
            .navigationTitle("Settings")
            .confirmationDialog("Clear all cached covers?", isPresented: $showClearConfirm) {
                Button("Clear Covers", role: .destructive) { cache.clearFullCovers() }
            }
        }
    }
}

// MARK: - Onboarding View

struct OnboardingView: View {
    @Binding var serverURL: String
    let onComplete: () -> Void
    @State private var testing = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                Spacer()
                Image(systemName: "books.vertical.fill")
                    .font(.system(size: 72))
                    .foregroundStyle(Color.accentColor)
                Text("The Shelf").font(.largeTitle.bold())
                Text("Enter your Pi server address to get started.")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Server URL").font(.caption).foregroundStyle(.secondary)
                    TextField("https://192.168.x.x:8773", text: $serverURL)
                        .textFieldStyle(.roundedBorder)
                        .keyboardType(.URL)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                }
                .padding(.horizontal)

                if let error {
                    ScrollView {
                        Text(error)
                            .foregroundStyle(.red)
                            .font(.caption)
                            .monospaced()
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxHeight: 200)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .padding(.horizontal)
                }

                Button {
                    Task {
                        testing = true
                        error = nil
                        ShelfAPIService.shared.configure(ServerConfig(
                            baseURL: serverURL.trimmingCharacters(in: .whitespaces),
                            ignoreTLSErrors: true
                        ))
                        do {
                            _ = try await ShelfAPIService.shared.fetchBooksSince("2099-01-01T00:00:00Z")
                            onComplete()
                        } catch let e as ShelfError {
                            self.error = e.errorDescription ?? "Unknown error"
                        } catch {
                            self.error = "\(type(of: error)): \(error.localizedDescription)"
                        }
                        testing = false
                    }
                } label: {
                    Group {
                        if testing { ProgressView() } else { Text("Connect") }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.accentColor)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(testing || serverURL.isEmpty)
                .padding(.horizontal)

                Spacer()
            }
        }
    }
}
