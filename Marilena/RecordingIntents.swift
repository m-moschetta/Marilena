import AppIntents
import Foundation

struct StartRecordingIntent: AppIntent {
    static var title: LocalizedStringResource = "Avvia Registrazione"
    static var description: IntentDescription = IntentDescription(
        "Avvia immediatamente una registrazione audio",
        categoryName: "Registrazione"
    )
    
    func perform() async throws -> some IntentResult {
        // Salva l'intent per essere gestito dall'app
        UserDefaults.standard.set(true, forKey: "start_recording_on_launch")
        UserDefaults.standard.set(Date(), forKey: "recording_intent_timestamp")
        
        return .result()
    }
}

struct StopRecordingIntent: AppIntent {
    static var title: LocalizedStringResource = "Ferma Registrazione"
    static var description: IntentDescription = IntentDescription(
        "Ferma la registrazione audio in corso",
        categoryName: "Registrazione"
    )
    
    func perform() async throws -> some IntentResult {
        // Salva l'intent per essere gestito dall'app
        UserDefaults.standard.set(true, forKey: "stop_recording_on_launch")
        UserDefaults.standard.set(Date(), forKey: "stop_recording_intent_timestamp")
        
        return .result()
    }
}

struct MarilenaShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartRecordingIntent(),
            phrases: [
                "Avvia registrazione con \(.applicationName)",
                "Inizia a registrare con \(.applicationName)",
                "Registra audio con \(.applicationName)"
            ],
            shortTitle: "Registra",
            systemImageName: "mic.circle.fill"
        )
        
        AppShortcut(
            intent: StopRecordingIntent(),
            phrases: [
                "Ferma registrazione con \(.applicationName)",
                "Stop registrazione con \(.applicationName)",
                "Termina registrazione con \(.applicationName)"
            ],
            shortTitle: "Stop Registrazione",
            systemImageName: "stop.circle.fill"
        )
    }
} 