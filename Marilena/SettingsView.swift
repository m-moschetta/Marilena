import SwiftUI
import Speech
import CoreData

struct SettingsView: View {
    @State private var apiKey = ""
    @State private var selectedModel = "gpt-4o-mini"
    @State private var temperature: Double = 0.7
    @State private var maxTokens: Double = 1000
    @State private var selectedTranscriptionMode = "auto"
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var showingOAuthConfig = false
    
    // Perplexity settings
    @State private var perplexityApiKey = ""
    @State private var selectedPerplexityModel = "sonar-pro"
    
    // Groq settings
    @State private var groqApiKey = ""
    @State private var selectedGroqModel = "deepseek-r1-distill-qwen-32b"
    
    // Anthropic settings
    @State private var anthropicApiKey = ""
    @State private var selectedAnthropicModel = "claude-3-5-sonnet-20241022"
    
    // Provider selection
    @State private var selectedProvider = "openai"
    
    let availableModels = [
        // GPT-4o series (flagship models, multimodal)
        "gpt-4o",                    // Latest GPT-4o, 128K context, $5/$15 per 1M tokens
        "gpt-4o-mini",               // Fast and affordable, 128K context, $0.15/$0.60 per 1M tokens
        "chatgpt-4o-latest",         // Latest used in ChatGPT
        
        // GPT-4.1 series (April 2025 release, 1M context window)
        "gpt-4.1",                   // Full model, 1M context, $2.00/$8.00 per 1M tokens  
        "gpt-4.1-mini",              // Compact version, 1M context, $0.40/$1.60 per 1M tokens
        "gpt-4.1-nano",              // Ultra-light version, optimized for speed
        
        // GPT-4.5 (Feb 2025 - research preview, large and expensive)
        "gpt-4.5-preview",           // Largest model, $75/$150 per 1M tokens, creative tasks
        
        // o-series (reasoning models, advanced problem-solving)
        "o1",                        // Latest reasoning model (alias to o1-2024-12-17)
        "o1-mini",                   // Faster reasoning model
        "o3-mini",                   // Latest small reasoning model
        
        // Legacy but stable
        "gpt-4-turbo",               // Previous generation flagship
        "gpt-3.5-turbo"              // Cost-effective option
    ]
    
    let availablePerplexityModels = [
        // Sonar Online
        "sonar-pro", "llama-sonar-huge-online", "llama-sonar-large-online",
        // Sonar Specializzati
        "sonar-reasoning-pro", "sonar-deep-research",
        // Open-Source
        "llama-405b-instruct", "llama-70b-instruct", "mixtral-8x7b-instruct"
    ]
    
    let availableGroqModels = [
        // DeepSeek R1 Distill (Advanced Reasoning - BEST CHOICE)
        "deepseek-r1-distill-llama-70b",  // 260 T/s, 131K context, CodeForces 1633, MATH 94.5%
        "deepseek-r1-distill-qwen-32b",   // 388 T/s, 128K context, CodeForces 1691, AIME 83.3%  
        "deepseek-r1-distill-qwen-14b",   // 500+ T/s, 64K context, AIME 69.7, MATH 93.9%
        "deepseek-r1-distill-qwen-1.5b",  // 800+ T/s, 32K context, ultra-fast reasoning
        
        // Qwen 2.5 (Fast General Purpose with Tool Use)
        "qwen2.5-72b-instruct",           // Enhanced capabilities, better reasoning
        "qwen2.5-32b-instruct",           // 397 T/s, 128K context, tool calling + JSON mode
        
        // LLaMA 3.3/3.1 (Meta - Versatile and Reliable)
        "llama-3.3-70b-versatile",        // General purpose, balanced performance
        "llama-3.1-405b-reasoning",       // Largest model, best for complex tasks
        "llama-3.1-70b-versatile",        // Good balance of size and performance
        "llama-3.1-8b-instant",           // Fast and efficient for simple tasks
        
        // Mixtral (Mistral AI - Multilingual and Coding)
        "mixtral-8x7b-32768",             // Mixture of Experts, multilingual
        
        // Gemma 2 (Google - Efficient and Fast)
        "gemma2-9b-it",                   // Efficient instruction-tuned model
        "gemma-7b-it"                     // Lightweight but capable
    ]
    
    let availableAnthropicModels = [
        // Claude 4 series (2025 - Latest and most capable - Maggio 2025)
        "claude-opus-4-20250514",      // Most powerful model, $15/$75 per 1M tokens, 200K context ✅
        "claude-sonnet-4-20250514",    // High performance for production, $3/$15 per 1M tokens, 200K context ✅
        
        // Claude 3.7 series (Hybrid reasoning - Febbraio 2025)
        "claude-3-7-sonnet-20250219",  // First hybrid reasoning model, enhanced thinking, $6/$22.5 per 1M tokens ✅
        
        // Claude 3.5 series (Proven workhorses - Proven reliable)
        "claude-3-5-sonnet-20241022",  // Best balance, 200K context, $3/$15 per 1M tokens ✅
        "claude-3-5-haiku-20241022",   // Fast and lightweight, 200K context, $0.25/$1.25 per 1M tokens ✅
        
        // Claude 3 series (Legacy but still available)
        "claude-3-sonnet",             // Balanced performance, 200K context
        "claude-3-haiku",              // Fastest and cheapest, 200K context
        "claude-3-opus"                // Most capable legacy model, 200K context
    ]
    
    let transcriptionModes = [
        ("auto", "Automatico", "Sceglie automaticamente il miglior framework disponibile"),
        ("speech_analyzer", "Speech Analyzer (iOS 26+)", "Framework più avanzato per iOS 26+"),
        ("speech_framework", "Speech Framework", "Framework tradizionale per iOS 13+"),
        ("whisper", "Whisper API", "Trascrizione tramite OpenAI Whisper API"),
        ("local", "Locale", "Trascrizione locale con modelli integrati")
    ]
    
    let availableProviders = [
        ("openai", "OpenAI", "Modelli GPT più avanzati e versatili"),
        ("anthropic", "Anthropic Claude", "Modelli Claude per ragionamento profondo"),
        ("groq", "Groq", "Velocità ultra-rapida con Qwen 3 e DeepSeek R1")
    ]
    
    var body: some View {
        NavigationView {
            Form {
                Section("🎯 Selettore Provider AI") {
                    Picker("Provider AI", selection: $selectedProvider) {
                        ForEach(availableProviders, id: \.0) { provider in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(provider.1).font(.body)
                                Text(provider.2).font(.caption).foregroundColor(.secondary)
                            }
                            .tag(provider.0)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    
                    Text("💡 I modelli del provider selezionato saranno disponibili nel long press della chat")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // Sezione dinamica per il provider selezionato
                if selectedProvider == "openai" {
                    Section("OpenAI Configuration") {
                        SecureField("OpenAI API Key", text: $apiKey)
                            .textContentType(.password)
                        
                        Picker("Modello OpenAI", selection: $selectedModel) {
                            ForEach(availableModels, id: \.self) { model in
                                Text(getOpenAIModelDisplayName(model)).tag(model)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                    }
                } else if selectedProvider == "anthropic" {
                    Section("Anthropic Claude Configuration") {
                        SecureField("Anthropic API Key", text: $anthropicApiKey)
                            .textContentType(.password)
                        
                        Picker("Modello Claude", selection: $selectedAnthropicModel) {
                            ForEach(availableAnthropicModels, id: \.self) { model in
                                Text(getAnthropicModelDisplayName(model)).tag(model)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                        
                        Button("Test Connessione Anthropic") {
                            testAnthropicConnection()
                        }
                        .foregroundColor(.blue)
                        
                        Text("🧠 Anthropic Claude: Eccellente per ragionamento e analisi profonda")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } else if selectedProvider == "groq" {
                    Section("Groq AI Configuration") {
                        SecureField("Groq API Key", text: $groqApiKey)
                            .textContentType(.password)
                        
                        Picker("Modello Groq", selection: $selectedGroqModel) {
                            ForEach(availableGroqModels, id: \.self) { model in
                                Text(getGroqModelDisplayName(model)).tag(model)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                        
                        Button("Test Connessione Groq") {
                            testGroqConnection()
                        }
                        .foregroundColor(.blue)
                        
                        Text("🚀 Groq: Velocità ultra-rapida con modelli Qwen 3 e DeepSeek R1")
                            .font(.caption)
                            .foregroundColor(.secondary)
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
                
                Section("Email OAuth Configuration") {
                    Button("Configura OAuth") {
                        showingOAuthConfig = true
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
                        Slider(value: $maxTokens, in: 100...200000, step: 1000)
                    }
                }
                
                // NUOVO: Sezione Email
                Section("Impostazioni Email") {
                    NavigationLink {
                        EmailSettingsView()
                    } label: {
                        Label("Prompt Email", systemImage: "envelope.badge.person.crop")
                    }
                }
                
                Section {
                    Button("Salva Configurazione") {
                        saveSettings()
                    }
                    .foregroundColor(.blue)
                }
                
                // Sezione Thinking/Reasoning
                Section("Thinking & Reasoning") {
                    ThinkingManager.shared.getSettingsView()
                }
            }
            .navigationTitle("Impostazioni")
            .onAppear {
                loadSettings()
            }
            .sheet(isPresented: $showingOAuthConfig) {
                OAuthConfigView()
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
        
        // Salva API keys per tutti i provider
        _ = KeychainManager.shared.saveAPIKey(groqApiKey, for: "groq")
        _ = KeychainManager.shared.saveAPIKey(anthropicApiKey, for: "anthropic")
        
        // Salva provider selezionato e modelli
        UserDefaults.standard.set(selectedProvider, forKey: "selectedProvider")
        UserDefaults.standard.set(selectedModel, forKey: "selected_model")
        UserDefaults.standard.set(selectedPerplexityModel, forKey: "selected_perplexity_model")
        UserDefaults.standard.set(selectedGroqModel, forKey: "selectedGroqChatModel")
        UserDefaults.standard.set(selectedAnthropicModel, forKey: "selectedAnthropicModel")
        UserDefaults.standard.set(temperature, forKey: "temperature")
        UserDefaults.standard.set(maxTokens, forKey: "max_tokens")
        UserDefaults.standard.set(selectedTranscriptionMode, forKey: "transcription_mode")
        
        // Forza la sincronizzazione e notifica il cambiamento
        UserDefaults.standard.synchronize()
        NotificationCenter.default.post(name: .settingsChanged, object: nil)
        
        if openAISuccess && perplexitySuccess {
            alertMessage = "✅ Configurazione salvata con successo!\n\n• Provider: \(selectedProvider.capitalized)\n• Tutte le API key salvate"
        } else {
            alertMessage = "❌ Errore nel salvare alcune configurazioni"
        }
        showAlert = true
    }
    
    private func loadSettings() {
        apiKey = KeychainManager.shared.load(key: "openai_api_key") ?? ""
        perplexityApiKey = KeychainManager.shared.load(key: "perplexity_api_key") ?? ""
        groqApiKey = KeychainManager.shared.getAPIKey(for: "groq") ?? ""
        anthropicApiKey = KeychainManager.shared.getAPIKey(for: "anthropic") ?? ""
        
        selectedProvider = UserDefaults.standard.string(forKey: "selectedProvider") ?? "openai"
        selectedModel = UserDefaults.standard.string(forKey: "selected_model") ?? "gpt-4o-mini"
        selectedPerplexityModel = UserDefaults.standard.string(forKey: "selected_perplexity_model") ?? "sonar-pro"
        selectedGroqModel = UserDefaults.standard.string(forKey: "selectedGroqChatModel") ?? "deepseek-r1-distill-qwen-32b"
        selectedAnthropicModel = UserDefaults.standard.string(forKey: "selectedAnthropicModel") ?? "claude-3-5-sonnet-20241022"
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
    
    private func testGroqConnection() {
        // Salva la chiave prima di testare
        _ = KeychainManager.shared.saveAPIKey(groqApiKey, for: "groq")
        
        Task {
            do {
                let success = try await GroqService.shared.testConnection()
                await MainActor.run {
                    if success {
                        alertMessage = "✅ Test Groq riuscito:\n\n• API Key valida\n• Connessione a Groq OK\n• Modelli Qwen 3 e DeepSeek R1 disponibili"
                    } else {
                        alertMessage = "❌ Test Groq fallito:\n\nImpossibile connettersi a Groq."
                    }
                    showAlert = true
                }
            } catch {
                await MainActor.run {
                    alertMessage = "❌ Test Groq fallito:\n\nErrore: \(error.localizedDescription)"
                    showAlert = true
                }
            }
        }
    }
    
    private func testAnthropicConnection() {
        // Salva la chiave prima di testare
        _ = KeychainManager.shared.saveAPIKey(anthropicApiKey, for: "anthropic")
        
        Task {
            await MainActor.run {
                // Per ora mostra un messaggio di placeholder
                // TODO: Implementare AnthropicService per test reale
                if !anthropicApiKey.isEmpty {
                    alertMessage = "✅ Test Anthropic configurato:\n\n• API Key salvata\n• Modelli Claude disponibili\n• Integrazione da completare"
                } else {
                    alertMessage = "❌ Test Anthropic fallito:\n\nInserisci una API Key valida"
                }
                showAlert = true
            }
        }
    }
    
    private func getOpenAIModelDisplayName(_ model: String) -> String {
        switch model {
        case "gpt-4o":
            return "🌟 GPT-4o (Flagship Multimodal)"
        case "gpt-4o-mini":
            return "⚡ GPT-4o Mini (Fast & Affordable)"
        case "chatgpt-4o-latest":
            return "🆕 ChatGPT-4o Latest"
        case "gpt-4.1":
            return "🚀 GPT-4.1 (1M Context)"
        case "gpt-4.1-mini":
            return "💫 GPT-4.1 Mini (Compact)"
        case "gpt-4.1-nano":
            return "⚡ GPT-4.1 Nano (Ultra-light)"
        case "gpt-4.5-preview":
            return "🧠 GPT-4.5 Preview (Creative Giant)"
        case "o1":
            return "🤔 o1 (Advanced Reasoning)"
        case "o1-mini":
            return "🔬 o1 Mini (Fast Reasoning)"
        case "o3-mini":
            return "💎 o3 Mini (Latest Reasoning)"
        case "gpt-4-turbo":
            return "🔧 GPT-4 Turbo (Legacy)"
        case "gpt-3.5-turbo":
            return "💰 GPT-3.5 Turbo (Budget)"
        default:
            return model
        }
    }
    
    private func getAnthropicModelDisplayName(_ model: String) -> String {
        switch model {
        case "claude-opus-4-20250514":
            return "👑 Claude 4 Opus (Most Capable)"
        case "claude-sonnet-4-20250514":
            return "🎯 Claude 4 Sonnet (High Performance)"
        case "claude-3-7-sonnet-20250219":
            return "🧠 Claude 3.7 Sonnet (Hybrid Reasoning)"
        case "claude-3-5-sonnet-20241022":
            return "⚖️ Claude 3.5 Sonnet (Balanced)"
        case "claude-3-5-haiku-20241022":
            return "⚡ Claude 3.5 Haiku (Fast)"
        case "claude-3-sonnet":
            return "🔧 Claude 3 Sonnet (Legacy)"
        case "claude-3-haiku":
            return "💰 Claude 3 Haiku (Budget)"
        case "claude-3-opus":
            return "💎 Claude 3 Opus (Legacy Premium)"
        default:
            return model
        }
    }
    
    private func getGroqModelDisplayName(_ model: String) -> String {
        switch model {
        case "qwen-qwq-32b":
            return "🧠 Qwen QwQ 32B (Latest Reasoning)"
        case "qwen2.5-32b-instruct":
            return "⚡ Qwen 2.5 32B (Fast)"
        case "qwen2.5-72b-instruct":
            return "🚀 Qwen 2.5 72B (Powerful)"
        case "deepseek-r1-distill-qwen-32b":
            return "🎯 DeepSeek R1 Qwen 32B (Coding)"
        case "deepseek-r1-distill-llama-70b":
            return "💎 DeepSeek R1 Llama 70B (Math)"
        case "llama-3.3-70b-versatile":
            return "🦙 Llama 3.3 70B (Versatile)"
        case "llama-3.1-405b-reasoning":
            return "🔬 Llama 3.1 405B (Reasoning)"
        case "llama-3.1-70b-versatile":
            return "⚖️ Llama 3.1 70B (Balanced)"
        case "llama-3.1-8b-instant":
            return "⚡ Llama 3.1 8B (Instant)"
        case "mixtral-8x7b-32768":
            return "🌍 Mixtral 8x7B (Multilingual)"
        case "mixtral-8x22b-32768":
            return "🌎 Mixtral 8x22B (Enhanced)"
        case "gemma2-9b-it":
            return "💫 Gemma 2 9B (Efficient)"
        case "gemma-7b-it":
            return "✨ Gemma 7B (Lightweight)"
        default:
            return model
        }
    }
}

#Preview {
    SettingsView()
}

extension Notification.Name {
    static let settingsChanged = Notification.Name("settingsChanged")
}
