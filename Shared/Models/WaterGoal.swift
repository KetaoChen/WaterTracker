import Foundation
import SwiftUI

struct WaterGoal {
    var dailyTarget: Int // milliliters
    
    static let `default` = WaterGoal(dailyTarget: 2000) // 2L
    
    func progress(current: Int) -> Double {
        guard dailyTarget > 0 else { return 0 }
        return min(Double(current) / Double(dailyTarget), 1.0)
    }
}

// MARK: - Quick Add Options
enum QuickAddOption: Int, CaseIterable, Identifiable {
    case small = 250
    case medium = 350
    case large = 500
    
    var id: Int { rawValue }
    
    var label: String {
        switch self {
        case .small: return "小杯"
        case .medium: return "中杯"
        case .large: return "大杯"
        }
    }
    
    var icon: String {
        switch self {
        case .small: return "drop"
        case .medium: return "drop.fill"
        case .large: return "waterbottle"
        }
    }
    
    var amount: Int { rawValue }
}
