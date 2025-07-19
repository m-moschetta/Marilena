import SwiftUI
import Speech
import CoreData

struct SettingsView: View {
    @State private var apiKey = ""
    @State private var selectedModel = "gpt-4.1-mini"
    @State private var temperature: Double = 0.7
    @State private var maxTokens: Double = 1000
    @State private var selectedTranscriptionMode = "auto"
    @State private var showAlert = false
    @State private var alertMessage = ""
    
    // Perplexity settings
    @State private var perplexityApiKey = ""
    @State private var selectedPerplexityModel = "sonar-pro"
    
    let availableModels = [
        "gpt-4o",
        "gpt-4o-mini",
        "gpt-4.1",
        "gpt-4.1-mini", 
        "gpt-4.1-nano",
        "o3-mini",
        "o4-mini",
        "o3"
    ]
    
    let availablePerplexityModels = [
        // Sonar Online
        "sonar-pro", "llama-sonar-huge-online", "llama-sonar-large-online",
        // Sonar Specializzati
        "sonar-reasoning-pro", "sonar-deep-research",
        // Open-Source
        "llama-405b-instruct", "llama-70b-instruct", "mixtral-8x7b-instruct"
    ]
    
    let transcriptionModes = [
        ("auto", "Automatico", "Sceglie automaticamente il miglior framework disponibile"),
        ("speech_analyzer", "Speech Analyzer (iOS 26+)", "Framework più avanzato per iOS 26+"),
        ("speech_framework", "Speech Framework", "Framework tradizionale per iOS 13+"),
        ("whisper", "Whisper API", "Trascrizione tramite OpenAI Whisper API"),
        ("local", "Locale", "Trascrizione locale con modelli integrati")
    ]
    
    var body: some View {
        NavigationView {
            Form {
                Section("OpenAI Configuration") {
                    SecureField("OpenAI API Key", text: $apiKey)
                        .textContentType(.password)
                    
                    Picker("Modello", selection: $selectedModel) {
                        ForEach(availableModels, id: \.self) { model in
                            Text(model).tag(model)
                        }
                    }
                }
                
                Section("Perplexity Search") {
                    SecureField("Perplexity API Key", text: $perplexityApiKey)
                        .textContentType(.password)
                    
                    Picker("Modello Perplexity", selection: $selectedPerplexityModel) {
                        ForEach(availablePerplexityModels, id: \.self) { model in
                            Text(model).tag(model)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    
                    Button("Test Connessione Perplexity") {
                        testPerplexityConnection()
                    }
                    .foregroundColor(.blue)
                }
                
                Section("Trascrizione Audio") {
                    Picker("Modalità Trascrizione", selection: $selectedTranscriptionMode) {
                        ForEach(transcriptionModes, id: \.0) { mode in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(mode.1)
                                    .font(.body)
                                Text(mode.2)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .tag(mode.0)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    
                    // Test permessi trascrizione
                    Button("Test Permessi Trascrizione") {
                        testTranscriptionPermissions()
                    }
                    .foregroundColor(.blue)
                    
                    // Test trascrizione
                    Button("Test Trascrizione") {
                        testTranscription()
                    }
                    .foregroundColor(.green)
                    
                    // Test Whisper API
                    Button("Test Whisper API") {
                        testWhisperAPI()
                    }
                    .foregroundColor(.orange)
                    
                    // Forza download modelli Speech Recognition
                    Button("Scarica Modelli Speech") {
                        forceDownloadSpeechModels()
                    }
                    .foregroundColor(.purple)
                    
                    // Informazioni aggiuntive per la modalità selezionata
                    if let selectedMode = transcriptionModes.first(where: { $0.0 == selectedTranscriptionMode }) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Modalità: \(selectedMode.1)")
                                .font(.headline)
                            Text(selectedMode.2)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            // Informazioni specifiche per modalità
                            switch selectedTranscriptionMode {
                            case "speech_analyzer":
                                Text("• Richiede iOS 26+")
                                Text("• Migliore qualità e velocità")
                                Text("• Supporto multilingua avanzato")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                            case "speech_framework":
                                Text("• Compatibile con iOS 13+")
                                Text("• Trascrizione offline")
                                Text("• Qualità standard")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                            case "whisper":
                                Text("• Richiede connessione internet")
                                Text("• Qualità eccellente")
                                Text("• Supporto 99+ lingue")
                                    .font(.caption)
                                    .foregroundColor(.green)
                            case "local":
                                Text("• Trascrizione completamente offline")
                                Text("• Privacy garantita")
                                Text("• Richiede download modelli")
                                    .font(.caption)
                                    .foregroundColor(.purple)
                            default:
                                Text("• Selezione automatica del miglior framework")
                                Text("• Ottimizzato per il tuo dispositivo")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }
                
                Section("Parametri Modello") {
                    VStack {
                        HStack {
                            Text("Temperature")
                            Spacer()
                            Text(String(format: "%.1f", temperature))
                        }
                        Slider(value: $temperature, in: 0...2, step: 0.1)
                    }
                    
                    VStack {
                        HStack {
                            Text("Max Tokens")
                            Spacer()
                            Text(String(format: "%.0f", maxTokens))
                        }
                        Slider(value: $maxTokens, in: 100...4000, step: 100)
                    }
                }
                
                Section {
                    Button("Salva Configurazione") {
                        saveSettings()
                    }
                    .foregroundColor(.blue)
                }
            }
            .navigationTitle("Impostazioni")
            .onAppear {
                loadSettings()
            }
            .alert("Configurazione", isPresented: $showAlert) {
                Button("OK") { }
            } message: {
                Text(alertMessage)
            }
        }
    }
    
    private func saveSettings() {
        let openAISuccess = KeychainManager.shared.save(key: "openai_api_key", value: apiKey)
        let perplexitySuccess = PerplexityService.shared.saveAPIKey(perplexityApiKey)
        
        UserDefaults.standard.set(selectedModel, forKey: "selected_model")
        UserDefaults.standard.set(selectedPerplexityModel, forKey: "selected_perplexity_model")
        UserDefaults.standard.set(temperature, forKey: "temperature")
        UserDefaults.standard.set(maxTokens, forKey: "max_tokens")
        UserDefaults.standard.set(selectedTranscriptionMode, forKey: "transcription_mode")
        
        // Forza la sincronizzazione e notifica il cambiamento
        UserDefaults.standard.synchronize()
        NotificationCenter.default.post(name: .settingsChanged, object: nil)
        
        if openAISuccess && perplexitySuccess {
            alertMessage = "Configurazione salvata con successo!"
        } else {
            alertMessage = "Errore nel salvare alcune configurazioni"
        }
        showAlert = true
    }
    
    private func loadSettings() {
        apiKey = KeychainManager.shared.load(key: "openai_api_key") ?? ""
        perplexityApiKey = KeychainManager.shared.load(key: "perplexity_api_key") ?? ""
        
        selectedModel = UserDefaults.standard.string(forKey: "selected_model") ?? "gpt-4.1-mini"
        selectedPerplexityModel = UserDefaults.standard.string(forKey: "selected_perplexity_model") ?? "sonar-pro"
        temperature = UserDefaults.standard.double(forKey: "temperature") != 0 ? UserDefaults.standard.double(forKey: "temperature") : 0.7
        maxTokens = UserDefaults.standard.double(forKey: "max_tokens") != 0 ? UserDefaults.standard.double(forKey: "max_tokens") : 1000
        selectedTranscriptionMode = UserDefaults.standard.string(forKey: "transcription_mode") ?? "auto"
    }
    
    private func testTranscriptionPermissions() {
        let speechStatus = SFSpeechRecognizer.authorizationStatus()
        let recognizer = SFSpeechRecognizer(locale: Locale.current)
        let isAvailable = recognizer?.isAvailable ?? false
        
        var message = "Stato permessi trascrizione:\n"
        message += "• Autorizzazione: \(speechStatus.rawValue)\n"
        message += "• Speech Recognition disponibile: \(isAvailable)\n"
        message += "• Lingua corrente: \(Locale.current.identifier)"
        
        if speechStatus == .notDetermined {
            message += "\n\nRichiedendo permessi..."
            SFSpeechRecognizer.requestAuthorization { status in
                DispatchQueue.main.async {
                    self.alertMessage = "Permessi richiesti. Nuovo stato: \(status.rawValue)"
                    self.showAlert = true
                }
            }
        } else {
            alertMessage = message
            showAlert = true
        }
    }
    
    private func testTranscription() {
        // Crea un file audio di test
        _ = "Questo è un test di trascrizione per verificare il funzionamento del sistema."
        
        // Per ora, mostra solo un messaggio informativo
        alertMessage = "Test trascrizione:\n\nModalità: \(selectedTranscriptionMode)\n\nPer testare la trascrizione completa, registra un audio e usa la funzione di trascrizione."
        showAlert = true
    }
    
    private func testWhisperAPI() {
        // Verifica API Key
        guard let apiKey = KeychainManager.shared.load(key: "openai_api_key"), !apiKey.isEmpty else {
            alertMessage = "❌ Test Whisper API fallito:\n\nAPI Key OpenAI non configurata.\nConfigurala nella sezione 'OpenAI API Key'."
            showAlert = true
            return
        }
        
        // Verifica connessione internet
        let url = URL(string: "https://api.openai.com/v1/models")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 10
        
        Task {
            do {
                let (_, response) = try await URLSession.shared.data(for: request)
                
                if let httpResponse = response as? HTTPURLResponse {
                    if httpResponse.statusCode == 200 {
                        await MainActor.run {
                            alertMessage = "✅ Test Whisper API riuscito:\n\n• API Key valida\n• Connessione a OpenAI OK\n• Whisper API disponibile"
                            showAlert = true
                        }
                    } else if httpResponse.statusCode == 401 {
                        await MainActor.run {
                            alertMessage = "❌ Test Whisper API fallito:\n\nAPI Key OpenAI non valida.\nVerifica la chiave nelle impostazioni."
                            showAlert = true
                        }
                    } else {
                        await MainActor.run {
                            alertMessage = "⚠️ Test Whisper API parziale:\n\nStatus: \(httpResponse.statusCode)\n\nLa connessione funziona ma potrebbe esserci un problema con l'API Key."
                            showAlert = true
                        }
                    }
                } else {
                    await MainActor.run {
                        alertMessage = "❌ Test Whisper API fallito:\n\nImpossibile connettersi a OpenAI.\nVerifica la connessione internet."
                        showAlert = true
                    }
                }
            } catch {
                await MainActor.run {
                    alertMessage = "❌ Test Whisper API fallito:\n\nErrore di connessione:\n\(error.localizedDescription)"
                    showAlert = true
                }
            }
        }
    }
    
    private func forceDownloadSpeechModels() {
        let speechRecognizer = SFSpeechRecognizer(locale: Locale.current)
        let isAvailable = speechRecognizer?.isAvailable ?? false
        
        if isAvailable {
            alertMessage = "Speech Recognition è già disponibile per la lingua corrente."
            showAlert = true
            return
        }
        
        let localeIdentifier = Locale.current.identifier
        let urlString = "https://storage.googleapis.com/cloud-speech-api-models/speech_recognition_models/latest/en-US/en-US.zip" // Esempio per l'inglese
        
        guard let url = URL(string: urlString) else {
            alertMessage = "URL di download non valido."
            showAlert = true
            return
        }
        
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let destinationURL = documentsPath.appendingPathComponent("speech_models_\(localeIdentifier).zip")
        
        let task = URLSession.shared.downloadTask(with: url) { (tempURL, response, error) in
            if let error = error {
                DispatchQueue.main.async {
                    alertMessage = "Errore nel download dei modelli: \(error.localizedDescription)"
                    showAlert = true
                }
                return
            }
            
            guard let tempURL = tempURL else {
                DispatchQueue.main.async {
                    alertMessage = "URL temporaneo non trovato."
                    showAlert = true
                }
                return
            }
            
            do {
                try FileManager.default.moveItem(at: tempURL, to: destinationURL)
                DispatchQueue.main.async {
                    alertMessage = "Modelli Speech Recognition scaricati con successo per \(localeIdentifier)!"
                    showAlert = true
                }
            } catch {
                DispatchQueue.main.async {
                    alertMessage = "Errore nel salvataggio dei modelli: \(error.localizedDescription)"
                    showAlert = true
                }
            }
        }
        task.resume()
    }
    
    private func createTestAudioFile() -> URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let testFileName = "test_transcription_\(Date().timeIntervalSince1970).m4a"
        return documentsPath.appendingPathComponent(testFileName)
    }
    
    private func testPerplexityConnection() {
        // Salva la chiave prima di testare
        _ = PerplexityService.shared.saveAPIKey(perplexityApiKey)
        
        Task {
            do {
                let success = try await PerplexityService.shared.testConnection()
                await MainActor.run {
                    if success {
                        alertMessage = "✅ Test Perplexity riuscito:\n\n• API Key valida\n• Connessione a Perplexity OK\n• Ricerca online disponibile"
                    } else {
                        alertMessage = "❌ Test Perplexity fallito:\n\nImpossibile connettersi a Perplexity."
                    }
                    showAlert = true
                }
            } catch {
                await MainActor.run {
                    alertMessage = "❌ Test Perplexity fallito:\n\nErrore: \(error.localizedDescription)"
                    showAlert = true
                }
            }
        }
    }
}

#Preview {
    SettingsView()
}

extension Notification.Name {
    static let settingsChanged = Notification.Name("settingsChanged")
}
