import SwiftUI

struct ContentView: View {
    @Environment(BookStore.self) var store
    @Environment(SyncEngine.self) var syncEngine
    @State private var selectedTab: Tab = .home

    enum Tab: String, CaseIterable {
        case home, library, search, addBook, settings
        var label: String {
            switch self {
            case .home:    return "Home"
            case .library: return "Library"
            case .search:  return "Search"
            case .addBook: return "Add"
            case .settings: return "Settings"
            }
        }
        var icon: String {
            switch self {
            case .home:     return "house"
            case .library:  return "books.vertical"
            case .search:   return "magnifyingglass"
            case .addBook:  return "plus.circle"
            case .settings: return "gearshape"
            }
        }
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem { Label("Home", systemImage: "house") }
                .tag(Tab.home)

            LibraryView()
                .tabItem { Label("Library", systemImage: "books.vertical") }
                .tag(Tab.library)

            SearchView()
                .tabItem { Label("Search", systemImage: "magnifyingglass") }
                .tag(Tab.search)

            AddBookView()
                .tabItem { Label("Add", systemImage: "plus.circle") }
                .tag(Tab.addBook)

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
                .tag(Tab.settings)
        }
        .overlay(alignment: .top) {
            if syncEngine.isSyncing {
                SyncStatusBanner()
            }
        }
    }
}
