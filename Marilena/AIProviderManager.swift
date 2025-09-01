import Foundation

// MARK: - AI Provider Manager

public class AIProviderManager {
    public static let shared = AIProviderManager()
    
    private init() {}
    
    // MARK: - Provider Types
    
    enum ChatProvider {
        case openai, anthropic, groq
    }
    
    enum SearchProvider {
        case perplexity
    }
    
    enum TranscriptionProvider {
        case openai, groq, speechFramework, speechAnalyzer
    }
    
    // MARK: - Chat Provider Selection
    
    func getBestChatProvider() -> (provider: ChatProvider, model: String)? {
        // Verifica quali provider hanno API keys configurate
        let hasOpenAI = hasValidAPIKey(for: "openai")
        let hasAnthropic = hasValidAPIKey(for: "anthropic")
        let hasGroq = hasValidAPIKey(for: "groq")

        // Scegli il modello preferito: UserDefaults -> ModelCatalog live -> fallback sicuro
        func preferredModel(for provider: ChatProvider) -> String? {
            switch provider {
            case .openai:
                if let ud = UserDefaults.standard.string(forKey: "selectedChatModel"), !ud.isEmpty { return ud }
                if let live = ModelCatalog.shared.models(for: .openai).first?.name { return live }
                return "gpt-4o"
            case .anthropic:
                if let ud = UserDefaults.standard.string(forKey: "selectedAnthropicModel"), !ud.isEmpty { return normalize(model: ud, provider: .anthropic) }
                if let live = ModelCatalog.shared.models(for: .anthropic).first?.name { return live }
                return "claude-3-5-sonnet-20241022"
            case .groq:
                if let ud = UserDefaults.standard.string(forKey: "selectedGroqChatModel"), !ud.isEmpty { return normalize(model: ud, provider: .groq) }
                if let live = ModelCatalog.shared.models(for: .groq).first?.name { return live }
                return "llama-3.1-8b-instant"
            }
        }

        // Logica di priorità semplice: OpenAI > Anthropic > Groq (quando disponibili)
        if hasOpenAI, let model = preferredModel(for: .openai) { return (.openai, model) }
        if hasAnthropic, let model = preferredModel(for: .anthropic) { return (.anthropic, model) }
        if hasGroq, let model = preferredModel(for: .groq) { return (.groq, model) }

        return nil // Nessun provider configurato
    }

    // Normalizza selezioni legacy che salvavano display name invece di ID
    private func normalize(model: String, provider: AIModelProvider) -> String {
        let trimmed = model.trimmingCharacters(in: .whitespacesAndNewlines)
        // Se sembra già un ID (niente spazi o slash), mantienilo
        if !trimmed.contains(" ") && !trimmed.contains("/") { return trimmed }
        // Prova a mappare usando la description (spesso contiene il display name)
        let candidates = ModelCatalog.shared.models(for: provider)
        if let match = candidates.first(where: { $0.description.caseInsensitiveCompare(trimmed) == .orderedSame }) {
            return match.name // name ora è l'ID
        }
        // Fallback: primo modello live o un default sicuro
        if let first = candidates.first?.name { return first }
        switch provider {
        case .anthropic: return "claude-3-5-sonnet-20241022"
        case .groq: return "llama-3.1-8b-instant"
        case .openai: return "gpt-4o"
        default: return trimmed
        }
    }
    
    // MARK: - Search Provider Selection
    
    func getBestSearchProvider() -> (provider: SearchProvider, model: String)? {
        let selectedSearchModel = UserDefaults.standard.string(forKey: "selectedSearchModel") ?? "sonar-pro"
        
        if hasValidAPIKey(for: "perplexity") {
            return (.perplexity, selectedSearchModel)
        }
        
        return nil
    }
    
    // MARK: - Transcription Provider Selection
    
    func getBestTranscriptionProvider() -> (provider: TranscriptionProvider, model: String) {
        let selectedTranscriptionModel = UserDefaults.standard.string(forKey: "selectedTranscriptionModel") ?? "whisper-1"
        
        // Determina il provider basato sul modello selezionato
        if selectedTranscriptionModel.contains("whisper-large-v3-turbo") || selectedTranscriptionModel.contains("distil-whisper") {
            if hasValidAPIKey(for: "groq") {
                return (.groq, selectedTranscriptionModel)
            }
        }
        
        if selectedTranscriptionModel.contains("whisper") {
            if hasValidAPIKey(for: "openai") {
                return (.openai, selectedTranscriptionModel)
            }
        }
        
        // Fallback a framework locali
        #if canImport(SpeechAnalyzer)
        if #available(iOS 26.0, *) {
            return (.speechAnalyzer, "local")
        }
        #endif
        
        return (.speechFramework, "local")
    }
    
    // MARK: - Configuration Validation
    
    func validateConfiguration() -> [String] {
        var issues: [String] = []
        
        // Verifica Chat AI
        if getBestChatProvider() == nil {
            issues.append("Nessun provider per Chat AI configurato")
        }
        
        // Verifica Search
        if getBestSearchProvider() == nil {
            issues.append("Nessun provider per Ricerca configurato")
        }
        
        // La trascrizione ha sempre un fallback locale, quindi non aggiungiamo warning
        
        return issues
    }
    
    func hasBasicConfiguration() -> Bool {
        return getBestChatProvider() != nil
    }
    
    // MARK: - Helper Methods
    
    private func hasValidAPIKey(for key: String) -> Bool {
        guard let apiKey = KeychainManager.shared.getAPIKey(for: key),
              !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return false
        }
        return true
    }
    
    // MARK: - Provider Information
    
    func getProviderInfo() -> String {
        var info = "🤖 Configurazione Provider AI:\n\n"
        
        // Chat
        if let chatProvider = getBestChatProvider() {
            info += "💬 Chat: \(chatProvider.provider) (\(chatProvider.model))\n"
        } else {
            info += "💬 Chat: ❌ Non configurato\n"
        }
        
        // Search
        if let searchProvider = getBestSearchProvider() {
            info += "🔍 Ricerca: \(searchProvider.provider) (\(searchProvider.model))\n"
        } else {
            info += "🔍 Ricerca: ❌ Non configurato\n"
        }
        
        // Transcription
        let transcriptionProvider = getBestTranscriptionProvider()
        info += "🎤 Trascrizione: \(transcriptionProvider.provider) (\(transcriptionProvider.model))\n"
        
        return info
    }
} 
