import SwiftUI
import CoreData

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @State private var selectedTab = 0
    
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
        .accentColor(.blue)
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