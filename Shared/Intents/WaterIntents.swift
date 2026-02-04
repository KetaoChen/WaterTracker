import AppIntents
import SwiftData

// MARK: - Log Water Intent (exposed to Shortcuts)
struct LogWaterIntent: AppIntent {
    static var title: LocalizedStringResource = "记录喝水"
    static var description = IntentDescription("记录喝水量到 WaterTracker")
    
    @Parameter(title: "毫升", default: 250)
    var amount: Int
    
    static var parameterSummary: some ParameterSummary {
        Summary("记录 \(\.$amount) 毫升")
    }
    
    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        // Save to shared container so widget can see it
        let data = fetchTodayTotalFromSharedContainer()
        let newTotal = data.total + amount
        saveTodayTotalToSharedContainer(total: newTotal, goal: data.goal)
        
        return .result(dialog: "已记录 \(amount) 毫升 💧 (今日共 \(newTotal)ml)")
    }
    
    static var openAppWhenRun: Bool = false
}

// MARK: - Get Today's Intake Intent
struct GetWaterIntakeIntent: AppIntent {
    static var title: LocalizedStringResource = "查询今日饮水量"
    static var description = IntentDescription("获取今天喝了多少水")
    
    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let data = fetchTodayTotalFromSharedContainer()
        let progress = data.goal > 0 ? Int(Double(data.total) / Double(data.goal) * 100) : 0
        
        return .result(dialog: "今天喝了 \(data.total) 毫升，完成 \(progress)%（目标 \(data.goal) 毫升）")
    }
    
    static var openAppWhenRun: Bool = false
}

// MARK: - Quick Log (250ml)
struct LogSmallWaterIntent: AppIntent {
    static var title: LocalizedStringResource = "喝了一小杯水"
    static var description = IntentDescription("快速记录 250ml")
    
    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let data = fetchTodayTotalFromSharedContainer()
        let newTotal = data.total + 250
        saveTodayTotalToSharedContainer(total: newTotal, goal: data.goal)
        
        return .result(dialog: "已记录 250ml 💧 (今日共 \(newTotal)ml)")
    }
    
    static var openAppWhenRun: Bool = false
}

// MARK: - Quick Log (500ml)
struct LogLargeWaterIntent: AppIntent {
    static var title: LocalizedStringResource = "喝了一大杯水"
    static var description = IntentDescription("快速记录 500ml")
    
    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let data = fetchTodayTotalFromSharedContainer()
        let newTotal = data.total + 500
        saveTodayTotalToSharedContainer(total: newTotal, goal: data.goal)
        
        return .result(dialog: "已记录 500ml 💧 (今日共 \(newTotal)ml)")
    }
    
    static var openAppWhenRun: Bool = false
}
