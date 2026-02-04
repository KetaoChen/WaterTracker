import Foundation
import SwiftData
import SwiftUI

@Observable
final class WaterManager {
    static let shared = WaterManager()
    
    private(set) var todayTotal: Int = 0
    var goal: WaterGoal = .default
    
    var progress: Double {
        goal.progress(current: todayTotal)
    }
    
    var progressText: String {
        "\(todayTotal)ml / \(goal.dailyTarget)ml"
    }
    
    var isGoalReached: Bool {
        todayTotal >= goal.dailyTarget
    }
    
    // MARK: - Actions
    
    @MainActor
    func logWater(amount: Int, context: ModelContext) {
        let entry = WaterEntry(amount: amount)
        context.insert(entry)
        todayTotal += amount
        
        // Sync to shared container for widgets
        saveTodayTotalToSharedContainer(total: todayTotal, goal: goal.dailyTarget)
        
        // Haptic feedback
        #if os(iOS)
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        #endif
    }
    
    @MainActor
    func refreshTodayTotal(context: ModelContext) {
        let descriptor = FetchDescriptor<WaterEntry>(
            predicate: WaterEntry.today,
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        
        do {
            let entries = try context.fetch(descriptor)
            todayTotal = entries.reduce(0) { $0 + $1.amount }
            // Sync to shared container for widgets
            saveTodayTotalToSharedContainer(total: todayTotal, goal: goal.dailyTarget)
        } catch {
            print("Failed to fetch entries: \(error)")
            todayTotal = 0
        }
    }
    
    @MainActor
    func deleteEntry(_ entry: WaterEntry, context: ModelContext) {
        todayTotal -= entry.amount
        context.delete(entry)
    }
}
