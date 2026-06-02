import SwiftUI

struct ContentView: View {
    @Environment(BookStore.self) var store
    @Environment(SyncEngine.self) var syncEngine
    @Environment(ShelfTheme.self) var theme
    @State private var selectedTab: Tab = .home

    enum Tab: String, CaseIterable {
        case home, library, manga, stats, settings
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem { Label("Home", systemImage: "house") }
                .tag(Tab.home)

            LibraryView()
                .tabItem { Label("Library", systemImage: "books.vertical") }
                .tag(Tab.library)

            MangaView()
                .tabItem { Label("Manga", systemImage: "square.stack") }
                .tag(Tab.manga)

            StatsView()
                .tabItem { Label("Stats", systemImage: "chart.bar") }
                .tag(Tab.stats)

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
                .tag(Tab.settings)
        }
        .tint(theme.accent)
        .overlay(alignment: .top) {
            if syncEngine.isSyncing {
                SyncStatusBanner()
            }
        }
    }
}
