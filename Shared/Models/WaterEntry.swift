import Foundation
import SwiftData

@Model
final class WaterEntry {
    var id: UUID
    var amount: Int // milliliters
    var timestamp: Date
    
    init(amount: Int, timestamp: Date = .now) {
        self.id = UUID()
        self.amount = amount
        self.timestamp = timestamp
    }
}

// MARK: - Helpers
extension WaterEntry {
    static var today: Predicate<WaterEntry> {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        return #Predicate { entry in
            entry.timestamp >= startOfDay && entry.timestamp < endOfDay
        }
    }
}
