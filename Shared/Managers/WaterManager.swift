import Foundation
import SwiftData
import SwiftUI
import WidgetKit

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
        
        // Sync to Supabase and save cloudId
        Task {
            do {
                let cloudId = try await SupabaseService.shared.logWater(amount: amount)
                await MainActor.run {
                    entry.cloudId = cloudId
                }
            } catch {
                print("⚠️ Failed to sync to Supabase: \(error)")
            }
        }
        
        // Reload widgets
        reloadWidgets()
        
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
    
    /// Sync from Supabase: pull cloud entries, reconcile with local
    @MainActor
    func syncFromCloud(context: ModelContext) async {
        do {
            let cloudEntries = try await SupabaseService.shared.fetchTodayEntries()
            
            // Fetch all local today entries
            let descriptor = FetchDescriptor<WaterEntry>(
                predicate: WaterEntry.today,
                sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
            )
            let localEntries = try context.fetch(descriptor)
            
            // Build set of local cloudIds
            let localCloudIds = Set(localEntries.compactMap { $0.cloudId })
            
            // Delete local entries whose cloudId no longer exists on server
            let cloudIds = Set(cloudEntries.map { $0.id })
            for local in localEntries {
                if let cid = local.cloudId, !cloudIds.contains(cid) {
                    context.delete(local)
                }
            }
            
            // Add cloud entries that don't exist locally
            for cloud in cloudEntries {
                if !localCloudIds.contains(cloud.id) {
                    let entry = WaterEntry(
                        amount: cloud.amount,
                        timestamp: cloud.createdAt,
                        cloudId: cloud.id
                    )
                    context.insert(entry)
                }
            }
            
            try context.save()
            refreshTodayTotal(context: context)
            
            // Reload widgets
            reloadWidgets()
            
            print("✅ Cloud sync complete: \(cloudEntries.count) cloud, \(localEntries.count) local")
        } catch {
            print("⚠️ Cloud sync failed: \(error)")
        }
    }
    
    /// Reload widget timelines
    func reloadWidgets() {
        WidgetCenter.shared.reloadAllTimelines()
    }
    
    @MainActor
    func deleteEntry(_ entry: WaterEntry, context: ModelContext) {
        todayTotal -= entry.amount
        
        // Sync deletion to Supabase if we have cloudId
        if let cloudId = entry.cloudId {
            Task {
                do {
                    try await SupabaseService.shared.deleteEntry(id: cloudId)
                } catch {
                    print("⚠️ Failed to delete from Supabase: \(error)")
                }
            }
        }
        
        // Update shared container for widgets
        saveTodayTotalToSharedContainer(total: todayTotal, goal: goal.dailyTarget)
        
        // Reload widgets
        reloadWidgets()
        
        context.delete(entry)
    }
}
