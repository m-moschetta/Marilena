import SwiftUI
import CoreData

struct RecorderMainView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var calendarManager: CalendarManager
    @EnvironmentObject private var recordingService: RecordingService

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
            .environmentObject(RecordingService(context: PersistenceController.preview.container.viewContext))
    }
}
