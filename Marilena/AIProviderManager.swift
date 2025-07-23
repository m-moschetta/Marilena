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
        // Ottieni le impostazioni salvate
        let selectedChatModel = UserDefaults.standard.string(forKey: "selectedChatModel") ?? "gpt-4.1"
        let selectedGroqModel = UserDefaults.standard.string(forKey: "selectedGroqChatModel") ?? "llama-3.3-70b-versatile"
        let selectedAnthropicModel = UserDefaults.standard.string(forKey: "selectedAnthropicModel") ?? "claude-sonnet-4-20250514"
        
        // Verifica quali provider hanno API keys configurate
        let hasOpenAI = hasValidAPIKey(for: "openaiApiKey")
        let hasAnthropic = hasValidAPIKey(for: "anthropicApiKey")
        let hasGroq = hasValidAPIKey(for: "groqApiKey")
        
        // Logica di priorità: usa il provider che ha sia API key che modello non-default
        if hasOpenAI && selectedChatModel != "gpt-4.1" {
            return (.openai, selectedChatModel)
        } else if hasAnthropic && selectedAnthropicModel != "claude-sonnet-4-20250514" {
            return (.anthropic, selectedAnthropicModel)
        } else if hasGroq && selectedGroqModel != "llama-3.3-70b-versatile" {
            return (.groq, selectedGroqModel)
        } else if hasOpenAI {
            return (.openai, selectedChatModel)
        } else if hasAnthropic {
            return (.anthropic, selectedAnthropicModel)
        } else if hasGroq {
            return (.groq, selectedGroqModel)
        }
        
        return nil // Nessun provider configurato
    }
    
    // MARK: - Search Provider Selection
    
    func getBestSearchProvider() -> (provider: SearchProvider, model: String)? {
        let selectedSearchModel = UserDefaults.standard.string(forKey: "selectedSearchModel") ?? "sonar-pro"
        
        if hasValidAPIKey(for: "perplexityApiKey") {
            return (.perplexity, selectedSearchModel)
        }
        
        return nil
    }
    
    // MARK: - Transcription Provider Selection
    
    func getBestTranscriptionProvider() -> (provider: TranscriptionProvider, model: String) {
        let selectedTranscriptionModel = UserDefaults.standard.string(forKey: "selectedTranscriptionModel") ?? "whisper-1"
        
        // Determina il provider basato sul modello selezionato
        if selectedTranscriptionModel.contains("whisper-large-v3-turbo") || selectedTranscriptionModel.contains("distil-whisper") {
            if hasValidAPIKey(for: "groqApiKey") {
                return (.groq, selectedTranscriptionModel)
            }
        }
        
        if selectedTranscriptionModel.contains("whisper") {
            if hasValidAPIKey(for: "openaiApiKey") {
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
        guard let apiKey = UserDefaults.standard.string(forKey: key), !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
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