import SwiftUI
import CoreData

struct RecorderMainView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var calendarManager: CalendarManager
    @StateObject private var recordingService: RecordingService

    init() {
        self._recordingService = StateObject(wrappedValue: RecordingService(context: PersistenceController.shared.container.viewContext))
    }

    var body: some View {
        RecordingsListView(context: viewContext, recordingService: recordingService)
            .onAppear {
                // Collega CalendarManager al RecordingService
                recordingService.setCalendarManager(calendarManager)
            }
    }
}

#Preview {
    NavigationView {
        RecorderMainView()
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
            .environmentObject(CalendarManager())
    }
} 