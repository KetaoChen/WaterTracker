import SwiftUI
import SwiftData

@main
struct WaterTrackerApp: App {
    let container: ModelContainer
    @State private var authManager = AuthManager.shared
    
    init() {
        container = createSharedModelContainer()
    }
    
    var body: some Scene {
        WindowGroup {
            Group {
                if authManager.isAuthenticated {
                    ContentView()
                } else {
                    AuthView()
                }
            }
            .onOpenURL { url in
                // Handle OAuth callback
                if url.scheme == "watertracker" {
                    Task {
                        try? await authManager.handleURLCallback(url)
                    }
                }
            }
        }
        .modelContainer(container)
    }
}
