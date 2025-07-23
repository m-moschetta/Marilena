import SwiftUI
import CoreData

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @State private var selectedTab = 1 // Cambiato da 0 a 1 per avviare su registratore
    
    var body: some View {
        GeometryReader { geometry in
            let isIPad = geometry.size.width > 600 // Ridotto da 768 a 600 per essere più permissivo
            Group {
                if isIPad {
                    iPadLayout(selectedTab: $selectedTab)
                } else {
                    iPhoneLayout(selectedTab: $selectedTab)
                }
            }
            .onAppear {
                print("📱 ContentView: width = \(geometry.size.width), isIPad = \(isIPad)")
            }
        }
        .accentColor(.blue)
        .onAppear {
            print("📱 iPadLayout: caricato")
        }
    }
}

// MARK: - iPad Layout
struct iPadLayout: View {
    @Binding var selectedTab: Int
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var recordingService: RecordingService
    
    init(selectedTab: Binding<Int>) {
        self._selectedTab = selectedTab
        self._recordingService = StateObject(wrappedValue: RecordingService(context: PersistenceController.shared.container.viewContext))
    }
    
    var body: some View {
        HStack(spacing: 0) {
            // Parte sinistra: Contenuto principale
            VStack(spacing: 0) {
                // Header con navigazione
                headerView
                
                // Contenuto principale
                mainContentView
            }
            .frame(maxWidth: .infinity)
            .background(Color(.systemGroupedBackground))
            
            // Parte destra: Registrazione sempre visibile
            VStack(spacing: 0) {
                // Header della registrazione
                recordingHeaderView
                
                // Interfaccia di registrazione
                AudioRecorderView(recordingService: recordingService)
                    .padding()
            }
            .frame(width: 320)
            .background(Color(.systemBackground))
            .overlay(
                Rectangle()
                    .frame(width: 1)
                    .foregroundColor(Color(.separator)),
                alignment: .leading
            )
        }
    }
    
    private var headerView: some View {
        HStack {
            // Tab buttons
            HStack(spacing: 0) {
                TabButton(
                    title: "Chat AI",
                    icon: "message.fill",
                    isSelected: selectedTab == 0,
                    action: { selectedTab = 0 }
                )
                
                TabButton(
                    title: "Registratore",
                    icon: "mic.fill",
                    isSelected: selectedTab == 1,
                    action: { selectedTab = 1 }
                )
                
                TabButton(
                    title: "Profilo",
                    icon: "person.fill",
                    isSelected: selectedTab == 2,
                    action: { selectedTab = 2 }
                )
            }
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .padding(.horizontal)
            
            Spacer()
        }
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color(.separator)),
            alignment: .bottom
        )
    }
    
    private var recordingHeaderView: some View {
        HStack {
            Text("Registrazione")
                .font(.headline)
                .fontWeight(.semibold)
            
            Spacer()
            
            // Stato registrazione
            HStack(spacing: 4) {
                Circle()
                    .fill(recordingService.recordingState == .recording ? Color.red : Color.green)
                    .frame(width: 8, height: 8)
                
                Text(recordingService.recordingState == .recording ? "Registrando" : "Pronto")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color(.separator)),
            alignment: .bottom
        )
    }
    
    private var mainContentView: some View {
        Group {
            switch selectedTab {
            case 0:
                ChatsListView()
            case 1:
                RecorderMainView()
            case 2:
                ProfiloWrapperView()
            default:
                RecorderMainView()
            }
        }
    }
}

// MARK: - iPhone Layout
struct iPhoneLayout: View {
    @Binding var selectedTab: Int
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Tab 1: Chat AI
            NavigationView {
                ChatsListView()
            }
            .tabItem {
                Image(systemName: "message.fill")
                Text("Chat AI")
            }
            .tag(0)
            
            // Tab 2: Registratore
            NavigationView {
                RecorderMainView()
            }
            .tabItem {
                Image(systemName: "mic.fill")
                Text("Registratore")
            }
            .tag(1)
            
            // Tab 3: Profilo
            NavigationView {
                ProfiloWrapperView()
            }
            .tabItem {
                Image(systemName: "person.fill")
                Text("Profilo")
            }
            .tag(2)
        }
    }
}

// MARK: - Tab Button
struct TabButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                
                Text(title)
                    .font(.caption)
            }
            .foregroundColor(isSelected ? .blue : .secondary)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .buttonStyle(PlainButtonStyle())
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