import SwiftUI
import CoreData
import Speech

@main
struct MarilenaApp: App {
    let persistenceController = PersistenceController.shared
    @StateObject private var transcriptionService: SpeechTranscriptionService

    init() {
        // Inizializza il servizio di trascrizione
        self._transcriptionService = StateObject(wrappedValue: SpeechTranscriptionService(context: PersistenceController.shared.container.viewContext))
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .onAppear {
                    // Richiedi i permessi per il riconoscimento vocale all'avvio
                    requestSpeechPermissions()
                }
        }
    }
    
    private func requestSpeechPermissions() {
        print("🎤 MarilenaApp: Richiesta permessi Speech Recognition all'avvio...")
        
        // Verifica lo stato attuale dei permessi
        let status = SFSpeechRecognizer.authorizationStatus()
        print("🎤 MarilenaApp: Stato permessi attuale: \(status.rawValue)")
        
        switch status {
        case .notDetermined:
            // Richiedi i permessi
            SFSpeechRecognizer.requestAuthorization { authStatus in
                DispatchQueue.main.async {
                    print("🎤 MarilenaApp: Risposta permessi: \(authStatus.rawValue)")
                    switch authStatus {
                    case .authorized:
                        print("✅ MarilenaApp: Permessi Speech Recognition concessi")
                    case .denied:
                        print("❌ MarilenaApp: Permessi Speech Recognition negati")
                    case .restricted:
                        print("❌ MarilenaApp: Permessi Speech Recognition limitati")
                    case .notDetermined:
                        print("❌ MarilenaApp: Permessi Speech Recognition non determinati")
                    @unknown default:
                        print("❌ MarilenaApp: Stato permessi sconosciuto")
                    }
                }
            }
        case .authorized:
            print("✅ MarilenaApp: Permessi Speech Recognition già concessi")
        case .denied, .restricted:
            print("❌ MarilenaApp: Permessi Speech Recognition negati/limitati")
        @unknown default:
            print("❌ MarilenaApp: Stato permessi sconosciuto")
        }
    }
}
