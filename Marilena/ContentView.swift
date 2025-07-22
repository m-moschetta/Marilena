import SwiftUI
import CoreData

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var coordinator: AppCoordinator
    @StateObject private var deviceAdapter = DeviceAdapter.shared
    
    init() {
        let context = PersistenceController.shared.container.viewContext
        self._coordinator = StateObject(wrappedValue: AppCoordinator(context: context))
    }
    
    var body: some View {
        IPadAdaptiveNavigationLayout {
            if deviceAdapter.isLarge {
                // iPad Layout
                IPadSplitView {
                    // Sidebar
                    SidebarView(coordinator: coordinator)
                } detail: {
                    // Detail View
                    DetailView(coordinator: coordinator)
                }
            } else {
                // iPhone Layout
                TabView(selection: $coordinator.selectedTab) {
                    // Tab 1: Chat AI
                    NavigationView {
                        ChatsListView()
                            .environmentObject(coordinator)
                    }
                    .tabItem {
                        Image(systemName: "message.fill")
                        Text("Chat AI")
                    }
                    .tag(0)
                    
                    // Tab 2: Registratore
                    NavigationView {
                        RecorderMainView()
                            .environmentObject(coordinator)
                    }
                    .tabItem {
                        Image(systemName: "mic.fill")
                        Text("Registratore")
                    }
                    .tag(1)
                    
                    // Tab 3: Profilo
                    NavigationView {
                        ProfiloWrapperView()
                            .environmentObject(coordinator)
                    }
                    .tabItem {
                        Image(systemName: "person.fill")
                        Text("Profilo")
                    }
                    .tag(2)
                }
                .accentColor(.blue)
            }
        }
        .environmentObject(coordinator)
        .environmentObject(deviceAdapter)
        .onAppear {
            deviceAdapter.updateScreenSize(UIScreen.main.bounds.size)
        }
    }
}

// MARK: - Sidebar View (iPad)
struct SidebarView: View {
    @ObservedObject var coordinator: AppCoordinator
    @ObservedObject private var deviceAdapter = DeviceAdapter.shared
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Marilena")
                    .font(.title2.weight(.bold))
                Spacer()
                Button(action: { coordinator.showSettings() }) {
                    Image(systemName: "gear")
                        .font(.title3)
                }
            }
            .padding(deviceAdapter.standardSpacing)
            .background(Color(.systemBackground))
            
            Divider()
            
            // Navigation
            List {
                Section("Principale") {
                    NavigationLink(destination: ChatsListView().environmentObject(coordinator)) {
                        Label("Chat AI", systemImage: "message.fill")
                    }
                    
                    NavigationLink(destination: RecorderMainView().environmentObject(coordinator)) {
                        Label("Registratore", systemImage: "mic.fill")
                    }
                    
                    NavigationLink(destination: ProfiloWrapperView().environmentObject(coordinator)) {
                        Label("Profilo", systemImage: "person.fill")
                    }
                }
                
                Section("Impostazioni") {
                    NavigationLink(destination: SettingsView().environmentObject(coordinator)) {
                        Label("Impostazioni", systemImage: "gear")
                    }
                }
            }
            .listStyle(InsetGroupedListStyle())
        }
        .background(Color(.systemGroupedBackground))
    }
}

// MARK: - Detail View (iPad)
struct DetailView: View {
    @ObservedObject var coordinator: AppCoordinator
    @ObservedObject private var deviceAdapter = DeviceAdapter.shared
    
    var body: some View {
        Group {
            switch coordinator.currentRoute {
            case .main:
                // Default view
                VStack {
                    Image(systemName: "message.circle")
                        .font(.system(size: 80))
                        .foregroundColor(.blue.opacity(0.6))
                    
                    Text("Benvenuto in Marilena")
                        .font(.title2.weight(.bold))
                        .padding(.top)
                    
                    Text("Seleziona un'opzione dalla sidebar")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                
            case .chat(let chat):
                ChatView(chat: chat)
                    .environmentObject(coordinator)
                
            case .recordingDetail(let recording):
                RecordingDetailView(recording: recording, context: coordinator.recordingService.context)
                    .environmentObject(coordinator)
                
            case .profile:
                ProfiloWrapperView()
                    .environmentObject(coordinator)
                
            case .settings:
                SettingsView()
                    .environmentObject(coordinator)
                
            case .transcriptionAnalysis(let recording):
                TranscriptionAnalysisView(recording: recording)
                    .environmentObject(coordinator)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}

// MARK: - Profilo Wrapper View
struct ProfiloWrapperView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @State private var profilo: ProfiloUtente?
    
    var body: some View {
        Group {
            if let profilo = profilo {
                ProfiloView(profilo: profilo)
            } else {
                ProgressView("Caricamento profilo...")
                    .onAppear {
                        caricaProfilo()
                    }
            }
        }
    }
    
    private func caricaProfilo() {
        profilo = ProfiloUtenteService.shared.ottieniProfiloUtente(in: viewContext)
        
        // Se non esiste un profilo, ne crea uno di default
        if profilo == nil {
            profilo = ProfiloUtenteService.shared.creaProfiloDefault(in: viewContext)
            _ = ProfiloUtenteService.shared.salvaProfilo(profilo!, in: viewContext)
        }
    }
}

#Preview {
    ContentView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
} 