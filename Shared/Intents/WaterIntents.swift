import AppIntents
import SwiftData

// MARK: - Log Water Intent
struct LogWaterIntent: AppIntent {
    static var title: LocalizedStringResource = "记录喝水"
    static var description = IntentDescription("记录喝水量")
    
    @Parameter(title: "毫升", default: 250)
    var amount: Int
    
    static var parameterSummary: some ParameterSummary {
        Summary("记录 \(\.$amount) 毫升")
    }
    
    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let container = try ModelContainer(for: WaterEntry.self)
        let context = container.mainContext
        
        WaterManager.shared.logWater(amount: amount, context: context)
        
        return .result(dialog: "已记录 \(amount) 毫升 💧")
    }
    
    static var openAppWhenRun: Bool = false
}

// MARK: - Get Water Intake Intent
struct GetWaterIntakeIntent: AppIntent {
    static var title: LocalizedStringResource = "查询今日饮水量"
    static var description = IntentDescription("获取今天喝了多少水")
    
    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let container = try ModelContainer(for: WaterEntry.self)
        let context = container.mainContext
        
        WaterManager.shared.refreshTodayTotal(context: context)
        let total = WaterManager.shared.todayTotal
        let goal = WaterManager.shared.goal.dailyTarget
        let progress = Int(WaterManager.shared.progress * 100)
        
        return .result(dialog: "今天喝了 \(total) 毫升，完成 \(progress)%（目标 \(goal) 毫升）")
    }
    
    static var openAppWhenRun: Bool = false
}

// MARK: - Quick Log Shortcuts
struct LogSmallWaterIntent: AppIntent {
    static var title: LocalizedStringResource = "喝了一小杯水"
    
    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let container = try ModelContainer(for: WaterEntry.self)
        let context = container.mainContext
        WaterManager.shared.logWater(amount: 250, context: context)
        return .result(dialog: "已记录 250ml 💧")
    }
    
    static var openAppWhenRun: Bool = false
}

struct LogLargeWaterIntent: AppIntent {
    static var title: LocalizedStringResource = "喝了一大杯水"
    
    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let container = try ModelContainer(for: WaterEntry.self)
        let context = container.mainContext
        WaterManager.shared.logWater(amount: 500, context: context)
        return .result(dialog: "已记录 500ml 💧")
    }
    
    static var openAppWhenRun: Bool = false
}

// MARK: - App Shortcuts Provider
struct WaterShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: LogSmallWaterIntent(),
            phrases: [
                "记录喝水",
                "喝了一杯水",
                "Log water in \(.applicationName)"
            ],
            shortTitle: "记录喝水",
            systemImageName: "drop.fill"
        )
        
        AppShortcut(
            intent: GetWaterIntakeIntent(),
            phrases: [
                "今天喝了多少水",
                "查询饮水量",
                "How much water in \(.applicationName)"
            ],
            shortTitle: "今日饮水",
            systemImageName: "chart.bar.fill"
        )
    }
}
