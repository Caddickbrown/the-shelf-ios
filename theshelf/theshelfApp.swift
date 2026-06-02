import SwiftUI

// MARK: - Root app entry point

@main
struct TheShelfApp: App {
    @State private var store = BookStore.shared
    @State private var syncEngine = SyncEngine.shared
    @State private var coverCache = CoverCache.shared
    @AppStorage("shelf.serverURL") private var serverURL = "https://192.168.4.185:8773"
    @AppStorage("shelf.fallbackURL") private var fallbackURL = ""
    @AppStorage("shelf.hasLaunched") private var hasLaunched = false
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            Group {
                if !hasLaunched {
                    OnboardingView(serverURL: $serverURL) {
                        hasLaunched = true
                        ShelfAPIService.shared.configure(ServerConfig(
                            baseURL: serverURL,
                            ignoreTLSErrors: true,
                            fallbackURL: fallbackURL.isEmpty ? nil : fallbackURL
                        ))
                        Task { await store.loadFromServer() }
                    }
                } else {
                    ContentView()
                        .onAppear {
                            // Restore saved config on every launch
                            ShelfAPIService.shared.configure(ServerConfig(
                                baseURL: serverURL,
                                ignoreTLSErrors: true,
                                fallbackURL: fallbackURL.isEmpty ? nil : fallbackURL
                            ))
                        }
                }
            }
            .environment(store)
            .environment(syncEngine)
            .environment(coverCache)
            .tint(ShelfTheme.accent)
        }
        // Sync on foreground — using scenePhase avoids re-triggering on every
        // @Observable state change (which caused the request flood).
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active, hasLaunched else { return }
            Task { await SyncEngine.shared.sync(store: store) }
        }
    }
}
