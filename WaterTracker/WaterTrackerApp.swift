import SwiftUI
import SwiftData

@main
struct WaterTrackerApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: WaterEntry.self)
    }
}
