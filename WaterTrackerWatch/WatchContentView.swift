import SwiftUI
import SwiftData

struct WatchContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(filter: WaterEntry.today, sort: \WaterEntry.timestamp, order: .reverse)
    private var todayEntries: [WaterEntry]
    
    @State private var waterManager = WaterManager.shared
    
    var todayTotal: Int {
        todayEntries.reduce(0) { $0 + $1.amount }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Compact progress ring
                    ProgressRingView(
                        progress: waterManager.goal.progress(current: todayTotal),
                        lineWidth: 12,
                        size: 100
                    )
                    
                    Text("\(todayTotal)ml")
                        .font(.headline)
                    
                    // Quick add buttons
                    HStack(spacing: 8) {
                        WatchQuickButton(amount: 250) {
                            addWater(250)
                        }
                        WatchQuickButton(amount: 500) {
                            addWater(500)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("💧")
        }
    }
    
    private func addWater(_ amount: Int) {
        waterManager.logWater(amount: amount, context: modelContext)
        WKInterfaceDevice.current().play(.success)
    }
}

struct WatchQuickButton: View {
    let amount: Int
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack {
                Image(systemName: amount == 250 ? "drop" : "drop.fill")
                Text("\(amount)")
                    .font(.caption2)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .tint(.blue)
    }
}

#Preview {
    WatchContentView()
        .modelContainer(for: WaterEntry.self, inMemory: true)
}
