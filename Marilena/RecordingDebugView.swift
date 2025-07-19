import SwiftUI
import CoreData

struct RecordingDebugView: View {
    @ObservedObject var recordingService: RecordingService
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \RegistrazioneAudio.dataCreazione, ascending: false)],
        animation: .default
    ) private var recordings: FetchedResults<RegistrazioneAudio>
    
    var body: some View {
        NavigationView {
            List {
                Section("Stato Registrazione Corrente") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Stato: \(String(describing: recordingService.recordingState))")
                        // Rimosso: Durata, Livello, ecc.
                    }
                    .font(.body)
                }

                Section("Statistiche Core Data") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Totale registrazioni: \(recordings.count)")
                        Text("Registrazioni completate: \(completedRecordings)")
                        Text("Registrazioni in elaborazione: \(processingRecordings)")
                        Text("Registrazioni con errori: \(errorRecordings)")
                    }
                    .font(.body)
                }
                
                Section("Registrazioni") {
                    ForEach(recordings, id: \.objectID) { recording in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(recording.titolo ?? "Senza titolo")
                                .font(.headline)
                            
                            Text("ID: \(recording.id?.uuidString ?? "N/A")")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Text("Stato: \(recording.statoElaborazione ?? "N/A")")
                                .font(.caption)
                                .foregroundColor(stateColor(recording.statoElaborazione))
                            
                            Text("Durata: \(formatDuration(recording.durata))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Text("Data: \(formatDate(recording.dataCreazione))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            if let path = recording.pathFile?.path {
                                Text("File: \(fileExists(at: path) ? "✅ Esistente" : "❌ Mancante")")
                                    .font(.caption)
                                    .foregroundColor(fileExists(at: path) ? .green : .red)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
                
                Section("Azioni") {
                    Button("Forza Sync Core Data") {
                        forceSyncCoreData()
                    }
                    
                    Button("Pulisci Registrazioni Orfane") {
                        cleanOrphanedRecordings()
                    }
                    
                    Button("Test Creazione Registrazione") {
                        testCreateRecording()
                    }
                }
            }
            .navigationTitle("Debug Registrazioni")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Chiudi") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var completedRecordings: Int {
        recordings.filter { $0.statoElaborazione == "completata" }.count
    }
    
    private var processingRecordings: Int {
        recordings.filter { $0.statoElaborazione == "registrazione" || $0.statoElaborazione == "in_elaborazione" }.count
    }
    
    private var errorRecordings: Int {
        recordings.filter { $0.statoElaborazione == "errore" }.count
    }
    
    // MARK: - Helper Methods
    
    private func stateColor(_ state: String?) -> Color {
        switch state {
        case "completata": return .green
        case "registrazione", "in_elaborazione": return .orange
        case "errore": return .red
        default: return .gray
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    private func formatDate(_ date: Date?) -> String {
        guard let date = date else { return "N/A" }
        
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func fileExists(at path: String) -> Bool {
        return FileManager.default.fileExists(atPath: path)
    }
    
    // MARK: - Actions
    
    private func forceSyncCoreData() {
        do {
            try viewContext.save()
            print("✅ Core Data sync forzato completato")
        } catch {
            print("❌ Errore sync Core Data: \(error)")
        }
    }
    
    private func cleanOrphanedRecordings() {
        var cleanedCount = 0
        
        for recording in recordings {
            guard let path = recording.pathFile?.path else { continue }
            
            if !FileManager.default.fileExists(atPath: path) {
                viewContext.delete(recording)
                cleanedCount += 1
            }
        }
        
        if cleanedCount > 0 {
            do {
                try viewContext.save()
                print("✅ Pulite \(cleanedCount) registrazioni orfane")
            } catch {
                print("❌ Errore pulizia: \(error)")
            }
        } else {
            print("📝 Nessuna registrazione orfana trovata")
        }
    }
    
    private func testCreateRecording() {
        let testRecording = RegistrazioneAudio(context: viewContext)
        testRecording.id = UUID()
        testRecording.titolo = "Test Recording \(Date())"
        testRecording.dataCreazione = Date()
        testRecording.durata = 30.0
        testRecording.statoElaborazione = "completata"
        testRecording.formatoAudio = "m4a"
        testRecording.qualitaAudio = "alta"
        
        do {
            try viewContext.save()
            print("✅ Registrazione di test creata con successo")
        } catch {
            print("❌ Errore creazione test: \(error)")
        }
    }
}

#Preview {
    RecordingDebugView(recordingService: RecordingService(context: PersistenceController.preview.container.viewContext))
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
} 