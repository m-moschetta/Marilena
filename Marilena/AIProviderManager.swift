import Foundation

// MARK: - AI Provider Manager

public class AIProviderManager {
    public static let shared = AIProviderManager()
    
    private var settingsObserver: NSObjectProtocol?

    private init() {
        settingsObserver = NotificationCenter.default.addObserver(
            forName: .settingsChanged,
            object: nil,
            queue: nil
        ) { [weak self] _ in
            self?.clearStreamingClientCache()
            self?.providerStateQueue.async(flags: .barrier) {
                self?.temporarilyUnavailableChatProviders.removeAll()
            }
        }
    }

    deinit {
        if let settingsObserver {
            NotificationCenter.default.removeObserver(settingsObserver)
        }
    }

    private let providerStateQueue = DispatchQueue(
        label: "AIProviderManager.providerStateQueue",
        attributes: .concurrent
    )
    private var temporarilyUnavailableChatProviders: Set<ChatProvider> = []
    private var cachedStreamingClients: [ChatProvider: AIStreamingClientProtocol] = [:]
    
    // MARK: - Provider Types
    
    enum ChatProvider: Hashable {
        case apple, openai, openrouter, anthropic, groq, xai, openclaw

        init?(rawValue: String) {
            switch rawValue.lowercased() {
            case "apple", "apple-intelligence": self = .apple
            case "openai": self = .openai
            case "openrouter": self = .openrouter
            case "anthropic": self = .anthropic
            case "groq": self = .groq
            case "xai", "grok": self = .xai
            case "openclaw": self = .openclaw
            default: return nil
            }
        }
    }
    
    enum SearchProvider {
        case perplexity
    }
    
    enum TranscriptionProvider {
        case openai, groq, speechFramework, speechAnalyzer
    }
    
    // MARK: - Chat Provider Selection
    
    func getBestChatProvider() -> (provider: ChatProvider, model: String)? {
        getOrderedChatProviders().first
    }

    func getOrderedChatProviders() -> [(provider: ChatProvider, model: String)] {
        let hasApple = AppleIntelligenceService.shared.isAvailable
        let hasOpenAI = hasValidAPIKey(for: "openai")
        let hasOpenRouter = hasValidAPIKey(for: "openrouter")
        let hasAnthropic = hasValidAPIKey(for: "anthropic")
        let hasGroq = hasValidAPIKey(for: "groq")
        let hasXAI = hasValidAPIKey(for: "xai")
        let hasOpenClaw = hasOpenClawConfigured()

        let storedProviderId = UserDefaults.standard.string(forKey: "selectedProvider")

        var orderedProviders: [ChatProvider] = [.openclaw, .apple, .openai, .openrouter, .anthropic, .groq, .xai]
        if let stored = storedProviderId.flatMap({ ChatProvider(rawValue: $0) }),
           let index = orderedProviders.firstIndex(of: stored) {
            orderedProviders.remove(at: index)
            orderedProviders.insert(stored, at: 0)
        }

        var resolved: [(provider: ChatProvider, model: String)] = []

        for provider in orderedProviders {
            guard !isTemporarilyUnavailable(provider) else { continue }

            switch provider {
            case .apple:
                guard hasApple, let model = preferredModel(for: .apple) else { continue }
                resolved.append((.apple, model))
            case .openai:
                guard hasOpenAI, let model = preferredModel(for: .openai) else { continue }
                resolved.append((.openai, model))
            case .openrouter:
                guard hasOpenRouter, let model = preferredModel(for: .openrouter) else { continue }
                resolved.append((.openrouter, model))
            case .anthropic:
                guard hasAnthropic, let model = preferredModel(for: .anthropic) else { continue }
                resolved.append((.anthropic, model))
            case .groq:
                guard hasGroq, let model = preferredModel(for: .groq) else { continue }
                resolved.append((.groq, model))
            case .xai:
                guard hasXAI, let model = preferredModel(for: .xai) else { continue }
                resolved.append((.xai, model))
            case .openclaw:
                guard hasOpenClaw, let model = preferredModel(for: .openclaw) else { continue }
                resolved.append((.openclaw, model))
            }
        }

        return resolved
    }

    /// Verifica se OpenClaw è configurato (endpoint salvato)
    private func hasOpenClawConfigured() -> Bool {
        guard let endpoint = UserDefaults.standard.string(forKey: "openclaw_endpoint"),
              !endpoint.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return false
        }
        return true
    }

    /// Restituisce il client di streaming dedicato per il provider specificato se disponibile.
    func streamingClient(for provider: ChatProvider) -> AIStreamingClientProtocol? {
        if let cached = providerStateQueue.sync(execute: { cachedStreamingClients[provider] }) {
            return cached
        }

        let client: AIStreamingClientProtocol?
        switch provider {
        case .openai:
            guard UserDefaults.standard.bool(forKey: "use_responses_api"),
                  hasValidAPIKey(for: "openai") else {
                client = nil
                break
            }
            client = OpenAIResponsesClient(
                apiKeyProvider: { KeychainManager.shared.getAPIKey(for: "openai") },
                forceGatewayFlag: { UserDefaults.standard.bool(forKey: "force_gateway") }
            )
        case .apple:
            client = nil // FoundationModels non espone ancora streaming token-by-token
        case .openrouter, .anthropic, .groq, .xai:
            client = nil // Verrà implementato nelle fasi successive della roadmap
        case .openclaw:
            client = nil // OpenClaw gestisce lo streaming internamente via WebSocket
        }

        if let client {
            providerStateQueue.async(flags: .barrier) {
                self.cachedStreamingClients[provider] = client
            }
        }

        return client
    }

    private func clearStreamingClientCache() {
        providerStateQueue.async(flags: .barrier) {
            self.cachedStreamingClients.removeAll()
        }
    }

    private func preferredModel(for provider: ChatProvider) -> String? {
        switch provider {
        case .apple:
            if let ud = UserDefaults.standard.string(forKey: "selectedAppleModel"), !ud.isEmpty { return ud }
            if let live = ModelCatalog.shared.models(for: .apple).first?.name { return live }
            return "foundation-medium"
        case .openai:
            if let ud = UserDefaults.standard.string(forKey: "selectedChatModel"), !ud.isEmpty { return ud }
            if let live = ModelCatalog.shared.models(for: .openai).first?.name { return live }
            return "gpt-4o"
        case .openrouter:
            if let ud = UserDefaults.standard.string(forKey: "selectedOpenRouterModel"), !ud.isEmpty {
                return normalize(model: ud, provider: .openrouter)
            }
            if let live = ModelCatalog.shared.models(for: .openrouter).first?.name { return live }
            return "openai/gpt-4o-mini"
        case .anthropic:
            if let ud = UserDefaults.standard.string(forKey: "selectedAnthropicModel"), !ud.isEmpty { return normalize(model: ud, provider: .anthropic) }
            if let live = ModelCatalog.shared.models(for: .anthropic).first?.name { return live }
            return "claude-3-5-sonnet-20241022"
        case .groq:
            if let ud = UserDefaults.standard.string(forKey: "selectedGroqChatModel"), !ud.isEmpty { return normalize(model: ud, provider: .groq) }
            if let live = ModelCatalog.shared.models(for: .groq).first?.name { return live }
            return "llama-3.1-8b-instant"
        case .xai:
            if let ud = UserDefaults.standard.string(forKey: "selectedXAIChatModel"), !ud.isEmpty { return normalize(model: ud, provider: .xai) }
            if let live = ModelCatalog.shared.models(for: .xai).first?.name { return live }
            return "grok-4-latest"
        case .openclaw:
            // OpenClaw usa il modello configurato nel Gateway, qui è solo un placeholder
            return "openclaw-agent"
        }
    }

    // Normalizza selezioni legacy che salvavano display name invece di ID
    private func normalize(model: String, provider: AIModelProvider) -> String {
        let trimmed = model.trimmingCharacters(in: .whitespacesAndNewlines)
        // Se sembra già un ID (niente spazi o slash), mantienilo
        if !trimmed.contains(" ") && !trimmed.contains("/") {
            if provider == .xai {
                let lower = trimmed.lowercased()
                switch lower {
                case "grok-4", "grok-4-latest": return "grok-4-latest"
                case "grok-4-mini": return "grok-4-fast-reasoning"
                case "grok-4-vision", "grok-4-vision-latest": return "grok-4-fast-non-reasoning"
                default: return trimmed
                }
            }
            return trimmed
        }
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
        case .xai: return "grok-4-latest"
        case .openai: return "gpt-4o"
        case .openrouter: return "openai/gpt-4o-mini"
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

    private func isTemporarilyUnavailable(_ provider: ChatProvider) -> Bool {
        providerStateQueue.sync {
            temporarilyUnavailableChatProviders.contains(provider)
        }
    }

    func markChatProviderUnavailable(_ provider: ChatProvider) {
        providerStateQueue.async(flags: .barrier) {
            self.temporarilyUnavailableChatProviders.insert(provider)
        }
    }

    func clearTemporaryUnavailability(for provider: ChatProvider) {
        providerStateQueue.async(flags: .barrier) {
            self.temporarilyUnavailableChatProviders.remove(provider)
        }
    }
    
    // MARK: - Provider Information
    
    func getProviderInfo() -> String {
        var info = "🤖 Configurazione Provider AI:\n\n"

        // Chat
        if let chatProvider = getBestChatProvider() {
            let providerName: String
            switch chatProvider.provider {
            case .openclaw:
                let endpoint = UserDefaults.standard.string(forKey: "openclaw_endpoint") ?? "localhost"
                providerName = "OpenClaw (\(endpoint))"
            default:
                providerName = "\(chatProvider.provider)"
            }
            info += "💬 Chat: \(providerName) (\(chatProvider.model))\n"
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
