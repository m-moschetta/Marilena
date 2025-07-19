import SwiftUI
import CoreData
import Speech
import AppIntents

@main
struct MarilenaApp: App {
    let persistenceController = PersistenceController.shared
    @StateObject private var transcriptionService: SpeechTranscriptionService
    @StateObject private var recordingService: RecordingService
    
    @State private var shouldStartRecording = false
    @State private var shouldStopRecording = false

    init() {
        // Inizializza i servizi
        self._transcriptionService = StateObject(wrappedValue: SpeechTranscriptionService(context: PersistenceController.shared.container.viewContext))
        self._recordingService = StateObject(wrappedValue: RecordingService(context: PersistenceController.shared.container.viewContext))
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .environmentObject(recordingService)
                .onAppear {
                    // Richiedi i permessi per il riconoscimento vocale all'avvio
                    requestSpeechPermissions()
                    
                    // Controlla se ci sono intents pendenti
                    checkPendingIntents()
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
                    // Salva i dati quando l'app va in background
                    saveContext()
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.willTerminateNotification)) { _ in
                    // Salva i dati quando l'app viene terminata
                    saveContext()
                }
                .onOpenURL { url in
                    // Gestisce gli URL schemes dal widget
                    handleURL(url)
                }
                .onChange(of: shouldStartRecording) { newValue in
                    if newValue {
                        startRecordingFromIntent()
                    }
                }
                .onChange(of: shouldStopRecording) { newValue in
                    if newValue {
                        stopRecordingFromIntent()
                    }
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
    
    private func saveContext() {
        let context = persistenceController.container.viewContext
        if context.hasChanges {
            do {
                try context.save()
                print("✅ Core Data context salvato con successo")
            } catch {
                print("❌ Errore salvataggio Core Data: \(error)")
            }
        }
    }
    
    private func handleURL(_ url: URL) {
        print("🔗 URL ricevuto: \(url)")
        
        if url.scheme == "marilena" {
            switch url.host {
            case "start-recording":
                print("🎙️ Avvio registrazione da widget")
                shouldStartRecording = true
            case "stop-recording":
                print("🛑 Stop registrazione da widget")
                shouldStopRecording = true
            default:
                print("❌ URL scheme non riconosciuto: \(url.host ?? "nil")")
            }
        }
    }
    
    private func checkPendingIntents() {
        // Controlla se ci sono intents di avvio registrazione
        if UserDefaults.standard.bool(forKey: "start_recording_on_launch") {
            print("🎙️ Intent di avvio registrazione rilevato")
            UserDefaults.standard.removeObject(forKey: "start_recording_on_launch")
            shouldStartRecording = true
        }
        
        // Controlla se ci sono intents di stop registrazione
        if UserDefaults.standard.bool(forKey: "stop_recording_on_launch") {
            print("🛑 Intent di stop registrazione rilevato")
            UserDefaults.standard.removeObject(forKey: "stop_recording_on_launch")
            shouldStopRecording = true
        }
    }
    
    private func startRecordingFromIntent() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if recordingService.recordingState == .idle || recordingService.recordingState == .completed {
                recordingService.startRecording()
                print("✅ Registrazione avviata da intent")
            }
            shouldStartRecording = false
        }
    }
    
    private func stopRecordingFromIntent() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if recordingService.recordingState == .recording {
                recordingService.stopRecording()
                print("✅ Registrazione fermata da intent")
            }
            shouldStopRecording = false
        }
    }
}
