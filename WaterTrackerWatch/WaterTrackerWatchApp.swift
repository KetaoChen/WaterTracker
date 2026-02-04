import SwiftUI
import SwiftData

@main
struct WaterTrackerWatchApp: App {
    var body: some Scene {
        WindowGroup {
            WatchContentView()
        }
        .modelContainer(for: WaterEntry.self)
    }
}
