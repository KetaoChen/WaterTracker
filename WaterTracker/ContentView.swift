import SwiftUI
import SwiftData

struct ContentView: View {
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
                VStack(spacing: 32) {
                    // Progress Ring
                    ProgressRingView(
                        progress: waterManager.goal.progress(current: todayTotal),
                        lineWidth: 24,
                        size: 220
                    )
                    .padding(.top, 20)
                    
                    // Stats
                    Text("\(todayTotal) / \(waterManager.goal.dailyTarget) ml")
                        .font(.title2.bold())
                        .foregroundStyle(.primary)
                    
                    // Quick Add Buttons
                    QuickAddButtonRow { amount in
                        addWater(amount)
                    }
                    .padding(.horizontal)
                    
                    // Today's entries
                    if !todayEntries.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("今日记录")
                                .font(.headline)
                                .padding(.horizontal)
                            
                            ForEach(todayEntries) { entry in
                                EntryRow(entry: entry) {
                                    deleteEntry(entry)
                                }
                            }
                        }
                        .padding(.top)
                    }
                }
            }
            .navigationTitle("💧 喝水记录")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        SettingsView()
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
        }
        .onAppear {
            waterManager.refreshTodayTotal(context: modelContext)
            Task {
                await waterManager.syncFromCloud(context: modelContext)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            waterManager.refreshTodayTotal(context: modelContext)
            Task {
                await waterManager.syncFromCloud(context: modelContext)
            }
        }
    }
    
    private func addWater(_ amount: Int) {
        waterManager.logWater(amount: amount, context: modelContext)
    }
    
    private func deleteEntry(_ entry: WaterEntry) {
        waterManager.deleteEntry(entry, context: modelContext)
    }
}

struct EntryRow: View {
    let entry: WaterEntry
    let onDelete: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text("\(entry.amount) ml")
                    .font(.headline)
                Text(entry.timestamp, style: .time)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Button(role: .destructive, action: onDelete) {
                Image(systemName: "trash")
                    .foregroundStyle(.red.opacity(0.7))
            }
            .buttonStyle(.plain)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }
}

struct SettingsView: View {
    @AppStorage("dailyGoal") private var dailyGoal = 2000
    @State private var authManager = AuthManager.shared
    
    var body: some View {
        Form {
            Section("每日目标") {
                Stepper("\(dailyGoal) ml", value: $dailyGoal, in: 500...5000, step: 250)
            }
            
            Section("账户") {
                if let email = authManager.currentUser?.email {
                    HStack {
                        Text("登录账号")
                        Spacer()
                        Text(email)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Button("退出登录", role: .destructive) {
                    authManager.signOut()
                }
            }
            
            Section("关于") {
                HStack {
                    Text("版本")
                    Spacer()
                    Text("1.0.0")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("设置")
    }
}

#Preview {
    ContentView()
        .modelContainer(for: WaterEntry.self, inMemory: true)
}
