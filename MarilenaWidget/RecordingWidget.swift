import WidgetKit
import SwiftUI
import Intents

struct RecordingWidgetEntryView: View {
    var entry: RecordingWidgetEntry
    
    var body: some View {
        VStack {
            Image(systemName: "mic.circle.fill")
                .font(.system(size: 40))
                .foregroundColor(.blue)
            
            Text("Registra")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.primary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
        .widgetURL(URL(string: "marilena://start-recording"))
    }
}

struct RecordingWidgetEntry: TimelineEntry {
    let date: Date
}

struct RecordingWidgetTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> RecordingWidgetEntry {
        RecordingWidgetEntry(date: Date())
    }
    
    func getSnapshot(in context: Context, completion: @escaping (RecordingWidgetEntry) -> Void) {
        let entry = RecordingWidgetEntry(date: Date())
        completion(entry)
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<RecordingWidgetEntry>) -> Void) {
        let entry = RecordingWidgetEntry(date: Date())
        let timeline = Timeline(entries: [entry], policy: .never)
        completion(timeline)
    }
}

struct RecordingWidget: Widget {
    let kind: String = "RecordingWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: RecordingWidgetTimelineProvider()) { entry in
            RecordingWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Registrazione Rapida")
        .description("Avvia rapidamente una registrazione audio")
        .supportedFamilies([.systemSmall])
    }
}

@main
struct MarilenaWidgets: WidgetBundle {
    var body: some Widget {
        RecordingWidget()
    }
} 