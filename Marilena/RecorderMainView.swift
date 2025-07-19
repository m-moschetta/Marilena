import SwiftUI
import CoreData

struct RecorderMainView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @State private var selectedTab = 0
    @StateObject private var recordingService: RecordingService
    
    init() {
        self._recordingService = StateObject(wrappedValue: RecordingService(context: PersistenceController.shared.container.viewContext))
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Segmented Control
            Picker("Modalità", selection: $selectedTab) {
                Text("Registra").tag(0)
                Text("Registrazioni").tag(1)
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding()
            
            // Contenuto basato sulla selezione
            if selectedTab == 0 {
                AudioRecorderView(recordingService: recordingService)
            } else {
                RecordingsListView(context: viewContext)
            }
        }
    }
}

#Preview {
    NavigationView {
        RecorderMainView()
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
} 