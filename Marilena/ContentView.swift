import SwiftUI
// PERF: Verificare ricomposizioni frequenti; considerare `EquatableView` o estrarre sotto-viste con `@StateObject` dove opportuno.
// PERF: Evitare calcoli costosi dentro `body`; memoizzare valori derivati da `geometry` se riusabile.
import CoreData

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @State private var selectedTab = 1 // 0=Chat, 1=Email, 2=Registratore, 3=Calendario, 4=Profilo
    
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
            PerformanceSignpost.event("HomeAppear")
        }
    }
}

// MARK: - iPad Layout
struct iPadLayout: View {
    @Binding var selectedTab: Int
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var calendarManager: CalendarManager
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
                .onAppear {
                    // Collega CalendarManager al RecordingService
                    recordingService.setCalendarManager(calendarManager)
                }
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
                    title: "Email",
                    icon: "envelope.fill",
                    isSelected: selectedTab == 1,
                    action: { selectedTab = 1 }
                )
                
                TabButton(
                    title: "Registratore",
                    icon: "mic.fill",
                    isSelected: selectedTab == 2,
                    action: { selectedTab = 2 }
                )
                
                TabButton(
                    title: "Calendario",
                    icon: "calendar",
                    isSelected: selectedTab == 3,
                    action: { selectedTab = 3 }
                )
                
                TabButton(
                    title: "Profilo",
                    icon: "person.fill",
                    isSelected: selectedTab == 4,
                    action: { selectedTab = 4 }
                )
            }
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .padding(.horizontal)
            
            Spacer()
        }
        .padding(.vertical, 12) // Aumentato da 8 a 12 per uniformare altezza
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
        .padding(.horizontal)
        .padding(.vertical, 12) // Uniformato con headerView
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
                EmailListView()
            case 2:
                // Su iPad, mostra solo la lista senza il pulsante di registrazione
                RecordingsListView(context: viewContext, recordingService: recordingService, hideRecordButton: true)
            case 3:
                CalendarView()
            case 4:
                ProfiloWrapperView()
                    .padding(.top, 16) // Aggiunto spazio sopra il profilo
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
            NavigationStack {
                ChatsListView()
            }
            .tabItem {
                Image(systemName: "message.fill")
                Text("Chat AI")
            }
            .tag(0)
            
            // Tab 2: Email
            NavigationStack {
                EmailListView()
            }
            .tabItem {
                Image(systemName: "envelope.fill")
                Text("Email")
            }
            .tag(1)
            
            // Tab 3: Registratore
            NavigationStack {
                RecorderMainView()
            }
            .tabItem {
                Image(systemName: "mic.fill")
                Text("Registratore")
            }
            .tag(2)
            
            // Tab 4: Calendario
            NavigationStack {
                CalendarView()
            }
            .tabItem {
                Image(systemName: "calendar")
                Text("Calendario")
            }
            .tag(3)
            
            // Tab 5: Profilo
            NavigationStack {
                ProfiloWrapperView()
            }
            .tabItem {
                Image(systemName: "person.fill")
                Text("Profilo")
            }
            .tag(4)
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
    @State private var isLoading = true
    
    var body: some View {
        Group {
            if let profilo = profilo {
                ProfiloView(profilo: profilo)
                    .transition(.opacity)
            } else {
                ProgressView("Caricamento profilo...")
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: profilo != nil)
        .onAppear {
            if profilo == nil {
                caricaProfilo()
            }
        }
    }
    
    private func caricaProfilo() {
        DispatchQueue.main.async {
            profilo = ProfiloUtenteService.shared.ottieniProfiloUtente(in: viewContext)
            
            // Se non esiste un profilo, ne crea uno di default
            if profilo == nil {
                profilo = ProfiloUtenteService.shared.creaProfiloDefault(in: viewContext)
                _ = ProfiloUtenteService.shared.salvaProfilo(profilo!, in: viewContext)
            }
        }
    }
}

#Preview {
    ContentView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
} 
