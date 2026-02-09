import Foundation
import SwiftData

/// App Group identifier for sharing data between app and widgets
let appGroupIdentifier = "group.com.ketao.WaterTracker"

/// Creates a ModelContainer using the shared App Group container
/// This allows the main app and widgets to share the same database
@MainActor
func createSharedModelContainer() -> ModelContainer {
    let schema = Schema([WaterEntry.self])
    
    // Use App Group container for shared storage
    let modelConfiguration: ModelConfiguration
    
    if let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) {
        let storeURL = containerURL.appendingPathComponent("WaterTracker.store")
        modelConfiguration = ModelConfiguration(
            schema: schema,
            url: storeURL,
            allowsSave: true
        )
    } else {
        // Fallback to default location (shouldn't happen with proper entitlements)
        modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
    }
    
    do {
        return try ModelContainer(for: schema, configurations: [modelConfiguration])
    } catch {
        fatalError("Could not create ModelContainer: \(error)")
    }
}

/// Reads today's water total from the shared container (for widgets)
func fetchTodayTotalFromSharedContainer() -> (total: Int, goal: Int) {
    let defaults = UserDefaults(suiteName: appGroupIdentifier)
    let goal = defaults?.integer(forKey: "dailyGoal") ?? 2000
    
    // Check if lastUpdated is today; if not, data is stale → return 0
    if let lastUpdated = defaults?.object(forKey: "lastUpdated") as? Date,
       Calendar.current.isDateInToday(lastUpdated) {
        let total = defaults?.integer(forKey: "todayTotal") ?? 0
        return (total, goal)
    }
    
    return (0, goal)
}

/// Saves today's total to shared UserDefaults (called by main app)
func saveTodayTotalToSharedContainer(total: Int, goal: Int) {
    guard let defaults = UserDefaults(suiteName: appGroupIdentifier) else { return }
    defaults.set(total, forKey: "todayTotal")
    defaults.set(goal, forKey: "dailyGoal")
    defaults.set(Date(), forKey: "lastUpdated")
}
