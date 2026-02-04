import SwiftUI
import SwiftData

@main
struct WaterTrackerApp: App {
    let container: ModelContainer
    
    init() {
        container = createSharedModelContainer()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(container)
    }
}
