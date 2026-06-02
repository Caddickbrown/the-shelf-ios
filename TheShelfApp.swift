import SwiftUI

// MARK: - Root app entry point

@main
struct TheShelfApp: App {
    @State private var store = BookStore.shared
    @State private var syncEngine = SyncEngine.shared
    @State private var coverCache = CoverCache.shared
    @AppStorage("shelf.serverURL") private var serverURL = "https://192.168.4.185:8773"
    @AppStorage("shelf.hasLaunched") private var hasLaunched = false

    var body: some Scene {
        WindowGroup {
            Group {
                if !hasLaunched {
                    OnboardingView(serverURL: $serverURL) {
                        hasLaunched = true
                        Task { await store.loadFromServer() }
                    }
                } else {
                    ContentView()
                        .task {
                            ShelfAPIService.shared.configure(ServerConfig(baseURL: serverURL, ignoreTLSErrors: true))
                            await SyncEngine.shared.sync(store: store)
                        }
                }
            }
            .environment(store)
            .environment(syncEngine)
            .environment(coverCache)
        }
    }
}
