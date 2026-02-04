import WidgetKit
import SwiftUI
import SwiftData

struct WaterEntry: TimelineEntry {
    let date: Date
    let todayTotal: Int
    let goal: Int
    
    var progress: Double {
        guard goal > 0 else { return 0 }
        return min(Double(todayTotal) / Double(goal), 1.0)
    }
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> WaterEntry {
        WaterEntry(date: .now, todayTotal: 1500, goal: 2000)
    }
    
    func getSnapshot(in context: Context, completion: @escaping (WaterEntry) -> Void) {
        completion(WaterEntry(date: .now, todayTotal: 1500, goal: 2000))
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<WaterEntry>) -> Void) {
        // TODO: Fetch actual data from shared container
        let entry = WaterEntry(date: .now, todayTotal: 1500, goal: 2000)
        let timeline = Timeline(entries: [entry], policy: .after(.now.addingTimeInterval(60 * 15)))
        completion(timeline)
    }
}

struct WaterWidgetEntryView: View {
    var entry: Provider.Entry
    @Environment(\.widgetFamily) var family
    
    var body: some View {
        switch family {
        case .systemSmall:
            SmallWidgetView(entry: entry)
        case .systemMedium:
            MediumWidgetView(entry: entry)
        case .accessoryCircular:
            CircularWidgetView(entry: entry)
        case .accessoryRectangular:
            RectangularWidgetView(entry: entry)
        default:
            SmallWidgetView(entry: entry)
        }
    }
}

struct SmallWidgetView: View {
    let entry: WaterEntry
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.blue.opacity(0.2), lineWidth: 8)
            Circle()
                .trim(from: 0, to: entry.progress)
                .stroke(Color.blue, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                .rotationEffect(.degrees(-90))
            
            VStack(spacing: 2) {
                Text("💧")
                Text("\(entry.todayTotal)")
                    .font(.headline.bold())
                Text("/ \(entry.goal)ml")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
    }
}

struct MediumWidgetView: View {
    let entry: WaterEntry
    
    var body: some View {
        HStack {
            SmallWidgetView(entry: entry)
            
            VStack(alignment: .leading) {
                Text("今日饮水")
                    .font(.headline)
                Text("\(Int(entry.progress * 100))% 完成")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text("目标 \(entry.goal)ml")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding()
    }
}

struct CircularWidgetView: View {
    let entry: WaterEntry
    
    var body: some View {
        Gauge(value: entry.progress) {
            Text("💧")
        } currentValueLabel: {
            Text("\(Int(entry.progress * 100))")
        }
        .gaugeStyle(.accessoryCircular)
    }
}

struct RectangularWidgetView: View {
    let entry: WaterEntry
    
    var body: some View {
        HStack {
            Text("💧")
            VStack(alignment: .leading) {
                Text("\(entry.todayTotal)ml")
                    .font(.headline)
                ProgressView(value: entry.progress)
            }
        }
    }
}

@main
struct WaterTrackerWidgets: WidgetBundle {
    var body: some Widget {
        WaterWidget()
    }
}

struct WaterWidget: Widget {
    let kind: String = "WaterWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            WaterWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("喝水进度")
        .description("显示今日饮水进度")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular])
    }
}

#Preview(as: .systemSmall) {
    WaterWidget()
} timeline: {
    WaterEntry(date: .now, todayTotal: 500, goal: 2000)
    WaterEntry(date: .now, todayTotal: 1500, goal: 2000)
}
